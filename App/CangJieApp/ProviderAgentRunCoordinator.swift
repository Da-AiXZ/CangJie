import CangJieCore
import CryptoKit
import Foundation

enum ProviderToolCatalogVersion: CaseIterable {
    case v1
    case v2
    case v3

    static let current = ProviderToolCatalogVersion.v3

    var manifestHash: String {
        Self.digest(manifestFields)
    }

    var allowedProviderFunctionNames: Set<String> {
        switch self {
        case .v1:
            return ["project_create", "project_status"]
        case .v2:
            return [
                "project_create",
                "project_list",
                "project_status",
                "project_switch",
                "project_save_discussion"
            ]
        case .v3:
            return ["project_create", "project_list", "project_status"]
        }
    }

    static func resolve(manifestHash: String) -> ProviderToolCatalogVersion? {
        allCases.first { $0.manifestHash == manifestHash }
    }

    private var manifestFields: [String] {
        switch self {
        case .v1:
            return [
                "provider-tool-catalog-v1",
                "project.create@1",
                "project.status@1"
            ]
        case .v2:
            return [
                "provider-tool-catalog-v2",
                "project.create@1",
                "project.list@1",
                "project.status@1",
                "project.switch@1",
                "conversation.save_discussion@1"
            ]
        case .v3:
            return [
                "provider-tool-catalog-v3",
                "project.create@1",
                "project.list@1",
                "project.status@1"
            ]
        }
    }

    private static func digest(_ fields: [String]) -> String {
        var data = Data()
        for field in fields {
            let bytes = Data(field.utf8)
            data.append(Data(String(bytes.count).utf8))
            data.append(0x3A)
            data.append(bytes)
            data.append(0x7C)
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }
            .joined()
    }
}

enum ProviderRequestPolicyVersion: CaseIterable {
    case v1
    case v2

    static let current = ProviderRequestPolicyVersion.v2

    var maximumOutputTokens: Int? {
        switch self {
        case .v1:
            return nil
        case .v2:
            return 4_096
        }
    }

    func manifestHash(
        provider: ModelProvider,
        baseURL: URL,
        modelID: String
    ) -> String {
        let manifestName: String
        switch self {
        case .v1:
            manifestName = "provider-policy-v1"
        case .v2:
            manifestName = "provider-policy-v2"
        }
        var fields = [
            manifestName,
            provider.rawValue,
            baseURL.absoluteString,
            modelID,
            "stream=true",
            "usage=required",
            "max-response-bytes=262144"
        ]
        if let maximumOutputTokens {
            fields.append("max-output-tokens=\(maximumOutputTokens)")
        }
        return Self.digest(fields)
    }

    static func resolve(
        manifestHash: String,
        identity: ProviderRequestIdentity
    ) -> ProviderRequestPolicyVersion? {
        allCases.first {
            $0.manifestHash(
                provider: identity.provider,
                baseURL: identity.baseURL,
                modelID: identity.modelID
            ) == manifestHash
        }
    }

    private static func digest(_ fields: [String]) -> String {
        var data = Data()
        for field in fields {
            let bytes = Data(field.utf8)
            data.append(Data(String(bytes.count).utf8))
            data.append(0x3A)
            data.append(bytes)
            data.append(0x7C)
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }
            .joined()
    }
}

@MainActor
final class ProviderAgentRunCoordinator {
    static let systemPrompt = """
    You are CangJie, the control plane for a local novel-writing application.
    This S2 milestone does not write formal prose. Respond briefly and truthfully.
    Use project_create only when the user explicitly asks to create or preserve a novel project.
    For project_create, copy the title and premise exactly from the user's request. Do not infer, expand, summarize, or rewrite either value.
    Use project_list or project_status only when the user explicitly asks for that exact read.
    Never claim a tool succeeded before its result is returned.
    """

    private let database: AppDatabase
    private let credentials: any ModelCredentialRepository
    private let generation: any ProviderGenerationServing
    private let now: () -> Date

    init(
        database: AppDatabase,
        credentials: any ModelCredentialRepository,
        generation: any ProviderGenerationServing =
            ProviderGenerationNetworkClient(),
        now: @escaping () -> Date = Date.init
    ) {
        self.database = database
        self.credentials = credentials
        self.generation = generation
        self.now = now
    }

    func prepareTask(
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection
    ) throws -> AgentTaskSnapshot {
        if let existing = try database.providerRequest(intentID: intent.id) {
            try Self.validateIntentScope(existing, intent: intent)
            if existing.phase != .failed && existing.phase != .cancelled {
                try Self.validateExisting(
                    existing,
                    intent: intent,
                    verifiedConnection: verifiedConnection,
                    prompt: try generationPrompt(for: existing, intent: intent)
                )
            }
            guard let task = try database.agentTask(intentID: intent.id),
                  task.activeRunID == existing.identity.runID else {
                throw ProviderAgentRunError.persistenceFailed
            }
            return task
        }
        let request = try Self.makePreparedRequest(
            intent: intent,
            verifiedConnection: verifiedConnection,
            now: now()
        )
        let persisted = try database.persistPreparedProviderRequest(
            request,
            intent: intent,
            verifiedConnection: verifiedConnection
        )
        guard let task = try database.agentTask(intentID: intent.id),
              task.activeRunID == persisted.identity.runID else {
            throw ProviderAgentRunError.persistenceFailed
        }
        return task
    }

    func commitDurableResponseIfPossible(
        intent: PendingModelIntent
    ) throws -> ProviderAgentLoopCompletion? {
        guard let request = try database.providerRequest(intentID: intent.id),
              ProviderRequestRecovery.nextAction(for: request)
                == .continueFromDurableResponse else {
            return nil
        }
        try Self.validateIntentScope(request, intent: intent)
        let durableResponse = try response(for: request)
        guard durableResponse.toolCalls.isEmpty else {
            return nil
        }
        let committed = try database.commitProviderContinuation(
            request,
            now: now()
        )
        return ProviderAgentLoopCompletion(
            request: committed.request,
            message: committed.message,
            receipts: committed.receipt.map { [$0] } ?? [],
            projects: try database.listProjects()
        )
    }

    func prepareExplicitRetry(
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection
    ) throws -> AgentTaskSnapshot {
        guard let previous = try database.providerRequest(intentID: intent.id),
              previous.phase == .failed
                || previous.phase == .cancelled
                || previous.phase == .terminated else {
            throw ProviderAgentRunError.terminalRequest
        }
        try Self.validateIntentScope(previous, intent: intent)
        guard let task = try database.agentTask(intentID: intent.id),
              task.status == .failed else {
            throw ProviderAgentRunError.terminalRequest
        }
        let retryAt = now()
        let retry = try Self.makePreparedRequest(
            intent: intent,
            verifiedConnection: verifiedConnection,
            attemptNumber: previous.identity.attemptNumber + 1,
            turnSequence: 1,
            previousRequestID: previous.identity.requestID,
            now: retryAt
        )
        return try database.persistExplicitProviderRetry(
            retry,
            intent: intent,
            verifiedConnection: verifiedConnection,
            failedTaskID: task.id,
            expectedTaskRevision: task.revision,
            commandID: retry.identity.requestID,
            now: retryAt
        )
    }

    func run(
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        onUpdate: (ProviderRunProjection) -> Void = { _ in }
    ) async throws -> ProviderRunCompletion {
        var request: ProviderRequestSnapshot
        if let existing = try database.providerRequest(intentID: intent.id) {
            try requireRunnableTask(
                intentID: intent.id,
                runID: existing.identity.runID
            )
            switch ProviderRequestRecovery.nextAction(for: existing) {
            case .sendPersistedRequest:
                let prompt = try generationPrompt(
                    for: existing,
                    intent: intent
                )
                try Self.validateExisting(
                    existing,
                    intent: intent,
                    verifiedConnection: verifiedConnection,
                    prompt: prompt
                )
                request = existing
            case .continueFromDurableResponse:
                let prompt = try generationPrompt(
                    for: existing,
                    intent: intent
                )
                try Self.validateExisting(
                    existing,
                    intent: intent,
                    verifiedConnection: verifiedConnection,
                    prompt: prompt
                )
                return ProviderRunCompletion(
                    request: existing,
                    response: try response(for: existing)
                )
            case .reconcileUnknownOutcome:
                throw ProviderAgentRunError.requiresReconciliation
            case .terminal:
                guard existing.phase == .failed
                        || existing.phase == .cancelled else {
                    throw ProviderAgentRunError.terminalRequest
                }
                try Self.validateIntentScope(existing, intent: intent)
                request = try Self.makePreparedRequest(
                    intent: intent,
                    verifiedConnection: verifiedConnection,
                    attemptNumber: existing.identity.attemptNumber + 1,
                    turnSequence: 1,
                    previousRequestID: existing.identity.requestID,
                    now: now()
                )
                request = try database.persistPreparedProviderRequest(
                    request,
                    intent: intent,
                    verifiedConnection: verifiedConnection
                )
            }
        } else {
            request = try Self.makePreparedRequest(
                intent: intent,
                verifiedConnection: verifiedConnection,
                now: now()
            )
            request = try database.persistPreparedProviderRequest(
                request,
                intent: intent,
                verifiedConnection: verifiedConnection
            )
        }

        try requireRunnableTask(
            intentID: intent.id,
            runID: request.identity.runID
        )

        let prompt = try generationPrompt(for: request, intent: intent)

        guard Self.supports(request.identity.provider) else {
            let failed = try ProviderRequestLifecycle.failBeforeSend(
                request,
                failure: .unsupportedProvider,
                now: now()
            )
            try database.updateProviderRequest(failed)
            throw ProviderAgentRunError.unsupportedProvider
        }

        let credential: KeychainBoundModelCredential
        do {
            guard let resolved = try credentials.resolve(
                for: verifiedConnection.connection
            ), Self.matches(resolved, request.identity) else {
                throw ProviderAgentRunError.connectionInvalid
            }
            credential = resolved
        } catch {
            let failed = try ProviderRequestLifecycle.failBeforeSend(
                request,
                failure: .authentication,
                now: now()
            )
            try database.updateProviderRequest(failed)
            throw ProviderAgentRunError.connectionInvalid
        }

        do {
            try generation.validate(
                request: request,
                verifiedConnection: verifiedConnection,
                secret: credential.secret,
                prompt: prompt
            )
        } catch let error as ProviderGenerationError {
            let failure: ProviderRequestFailure
            switch error {
            case .unsupportedProvider, .customDestinationPinningUnavailable:
                failure = .unsupportedProvider
            case .invalidPreparedRequest:
                failure = .invalidRequest
            case let .rejected(rejected):
                failure = rejected
            case .outcomeUnknown:
                failure = .invalidRequest
            }
            let failed = try ProviderRequestLifecycle.failBeforeSend(
                request,
                failure: failure,
                now: now()
            )
            try database.updateProviderRequest(failed)
            throw ProviderAgentRunError.invalidStream
        } catch {
            let failed = try ProviderRequestLifecycle.failBeforeSend(
                request,
                failure: .invalidRequest,
                now: now()
            )
            try database.updateProviderRequest(failed)
            throw ProviderAgentRunError.invalidStream
        }

        if Task.isCancelled {
            throw ProviderAgentRunError.cancelled
        }

        request = try ProviderRequestLifecycle.markSending(
            request,
            now: now()
        )
        try database.updateProviderRequest(request)
        onUpdate(Self.projection(request: request, response: .empty, usage: nil))

        var response = ProviderResponsePayload.empty
        var usage: ProviderUsage?
        var eventsSinceCheckpoint = 0
        var lastCheckpointAt = request.updatedAt
        do {
            let stream = generation.stream(
                request: request,
                verifiedConnection: verifiedConnection,
                secret: credential.secret,
                prompt: prompt
            )
            for try await event in stream {
                try Self.apply(event, response: &response, usage: &usage)
                eventsSinceCheckpoint += 1
                let eventTime = now()
                let shouldCheckpoint = request.phase == .sending
                    || eventsSinceCheckpoint >= 16
                    || eventTime.timeIntervalSince(lastCheckpointAt) >= 0.1
                    || Self.requiresImmediateCheckpoint(event)
                if shouldCheckpoint {
                    let responseJSON = try Self.encode(response)
                    request = try ProviderRequestLifecycle.checkpointStream(
                        request,
                        cursor: request.streamCursor + 1,
                        receivedUTF8Bytes: responseJSON.utf8.count,
                        responseHash: AppDatabase.payloadHash(responseJSON),
                        observedUsage: usage,
                        now: eventTime
                    )
                    try database.checkpointProviderResponse(
                        request,
                        responsePayloadJSON: responseJSON
                    )
                    eventsSinceCheckpoint = 0
                    lastCheckpointAt = eventTime
                }
                onUpdate(
                    Self.projection(
                        request: request,
                        response: response,
                        usage: usage
                    )
                )
            }
            try Task.checkCancellation()
            guard response.finishReason != nil, let usage else {
                throw ProviderAgentRunError.invalidStream
            }
            do {
                try response.validate(allowIncompleteToolCalls: false)
                guard prompt.allowsToolCalls || response.toolCalls.isEmpty else {
                    throw ProviderAgentRunError.invalidStream
                }
            } catch {
                throw ProviderAgentRunError.invalidStream
            }
            let responseJSON = try Self.encode(response)
            request = try ProviderRequestLifecycle.complete(
                request,
                responseHash: AppDatabase.payloadHash(responseJSON),
                usage: usage,
                now: now()
            )
            try database.completeProviderResponse(request)
            onUpdate(
                Self.projection(
                    request: request,
                    response: response,
                    usage: usage
                )
            )
            return ProviderRunCompletion(request: request, response: response)
        } catch let error as ProviderGenerationError {
            try flushBufferedResponse(
                response,
                usage: usage,
                request: &request
            )
            try settle(error, request: request)
            switch error {
            case let .outcomeUnknown(reason):
                throw ProviderAgentRunError.outcomeUnknown(reason)
            case .rejected, .invalidPreparedRequest:
                throw ProviderAgentRunError.invalidStream
            case .unsupportedProvider, .customDestinationPinningUnavailable:
                throw ProviderAgentRunError.unsupportedProvider
            }
        } catch let error as ProviderAgentRunError {
            try flushBufferedResponse(
                response,
                usage: usage,
                request: &request
            )
            if error == .invalidStream {
                try persistUnknown(request, reason: .invalidResponse)
            }
            throw error
        } catch is CancellationError {
            try flushBufferedResponse(
                response,
                usage: usage,
                request: &request
            )
            try persistUnknown(request, reason: .cancelled)
            throw ProviderAgentRunError.outcomeUnknown(.cancelled)
        } catch {
            do {
                try flushBufferedResponse(
                    response,
                    usage: usage,
                    request: &request
                )
                try persistUnknown(request, reason: .network)
            } catch {
                throw ProviderAgentRunError.persistenceFailed
            }
            throw ProviderAgentRunError.outcomeUnknown(.network)
        }
    }

    private func requireRunnableTask(
        intentID: UUID,
        runID: UUID
    ) throws {
        guard let task = try database.agentTask(intentID: intentID),
              task.activeRunID == runID else {
            throw ProviderAgentRunError.persistenceFailed
        }
        guard task.status == .running else {
            if task.status == .queued {
                throw ProviderAgentRunError.queued
            }
            throw ProviderAgentRunError.terminalRequest
        }
    }

    func runToCompletion(
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        onUpdate: (ProviderRunProjection) -> Void = { _ in }
    ) async throws -> ProviderAgentLoopCompletion {
        var completion = try await run(
            intent: intent,
            verifiedConnection: verifiedConnection,
            onUpdate: onUpdate
        )
        var receipts: [ToolReceipt] = []

        while !completion.response.toolCalls.isEmpty {
            guard !Task.isCancelled else {
                throw ProviderAgentRunError.cancelled
            }
            guard completion.request.identity.turnSequence
                    < ProviderRequestLifecycle.maximumTurnsPerAttempt else {
                _ = try database.settleAgentTaskAtProviderTurnLimit(
                    intentID: intent.id,
                    now: now()
                )
                throw ProviderAgentRunError.toolTurnLimitReached
            }
            let executions = try executeTools(
                for: completion,
                userRequest: intent.userRequest
            )
            receipts.append(contentsOf: executions.compactMap(\.receipt))
            let prompt = try continuationPrompt(
                response: completion.response,
                executions: executions,
                userRequest: intent.userRequest
            )
            let next = try Self.makePreparedRequest(
                intent: intent,
                verifiedConnection: verifiedConnection,
                requestID: UUID(),
                runID: completion.request.identity.runID,
                responseAssetID: UUID(),
                attemptNumber: completion.request.identity.attemptNumber,
                turnSequence: completion.request.identity.turnSequence + 1,
                previousRequestID: completion.request.identity.requestID,
                prompt: prompt,
                now: now()
            )
            _ = try database.persistPreparedProviderRequest(
                next,
                intent: intent,
                verifiedConnection: verifiedConnection
            )
            completion = try await run(
                intent: intent,
                verifiedConnection: verifiedConnection,
                onUpdate: onUpdate
            )
        }

        guard !Task.isCancelled else {
            throw ProviderAgentRunError.cancelled
        }
        let committed = try database.commitProviderContinuation(
            completion.request,
            now: now()
        )
        return ProviderAgentLoopCompletion(
            request: committed.request,
            message: committed.message,
            receipts: receipts,
            projects: try database.listProjects()
        )
    }

    static func makePreparedRequest(
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        attemptNumber: Int = 1,
        turnSequence: Int = 1,
        previousRequestID: UUID? = nil,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        let prompt = ProviderGenerationPrompt.initial(
            systemPrompt: systemPrompt,
            userPrompt: intent.userRequest
        )
        return try makePreparedRequest(
            intent: intent,
            verifiedConnection: verifiedConnection,
            requestID: UUID(),
            runID: UUID(),
            responseAssetID: UUID(),
            attemptNumber: attemptNumber,
            turnSequence: turnSequence,
            previousRequestID: previousRequestID,
            prompt: prompt,
            now: now
        )
    }

    private static func makePreparedRequest(
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        requestID: UUID,
        runID: UUID,
        responseAssetID: UUID,
        attemptNumber: Int,
        turnSequence: Int,
        previousRequestID: UUID?,
        prompt: ProviderGenerationPrompt,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        let connection = verifiedConnection.connection
        return try ProviderRequestLifecycle.prepare(
            requestID: requestID,
            runID: runID,
            idempotencyKey: "provider.request.\(intent.id.uuidString).\(attemptNumber).\(turnSequence)",
            attemptNumber: attemptNumber,
            turnSequence: turnSequence,
            previousRequestID: previousRequestID,
            intent: intent,
            verifiedConnection: verifiedConnection,
            responseAssetID: responseAssetID,
            promptManifestHash: try promptManifestHash(prompt),
            contextManifestHash: digest([
                "provider-context-v1",
                intent.conversationID.uuidString,
                intent.projectID?.uuidString ?? "",
                intent.branchID?.uuidString ?? "",
                intent.userRequest
            ]),
            toolCatalogManifestHash: ProviderToolCatalogVersion.current.manifestHash,
            disclosureScopeHash: digest([
                "provider-disclosure-v1",
                intent.userRequest
            ]),
            requestPolicyHash: ProviderRequestPolicyVersion.current.manifestHash(
                provider: connection.provider,
                baseURL: connection.baseURL,
                modelID: connection.selectedModel
            ),
            now: now
        )
    }

    private static func validateExisting(
        _ request: ProviderRequestSnapshot,
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        prompt: ProviderGenerationPrompt
    ) throws {
        let expected = try makePreparedRequest(
            intent: intent,
            verifiedConnection: verifiedConnection,
            requestID: request.identity.requestID,
            runID: request.identity.runID,
            responseAssetID: request.responseAssetID,
            attemptNumber: request.identity.attemptNumber,
            turnSequence: request.identity.turnSequence,
            previousRequestID: request.identity.previousRequestID,
            prompt: prompt,
            now: request.createdAt
        )
        guard request.identity == expected.identity,
              request.responseAssetID == expected.responseAssetID,
              request.promptManifestHash == expected.promptManifestHash,
              request.contextManifestHash == expected.contextManifestHash,
              Self.acceptedToolCatalogManifestHash(
                request.toolCatalogManifestHash,
                expected: expected.toolCatalogManifestHash
              ),
              request.disclosureScopeHash == expected.disclosureScopeHash,
              Self.acceptedRequestPolicyManifestHash(
                request.requestPolicyHash,
                expected: expected.requestPolicyHash,
                identity: request.identity
              ),
              request.createdAt == expected.createdAt else {
            throw ProviderAgentRunError.connectionInvalid
        }
    }

    private static func validateIntentScope(
        _ request: ProviderRequestSnapshot,
        intent: PendingModelIntent
    ) throws {
        guard request.identity.intentID == intent.id,
              request.identity.conversationID == intent.conversationID,
              request.identity.projectID == intent.projectID,
              request.identity.branchID == intent.branchID else {
            throw ProviderAgentRunError.connectionInvalid
        }
    }

    private func response(
        for request: ProviderRequestSnapshot
    ) throws -> ProviderResponsePayload {
        guard let json = try database.providerResponsePayload(
            assetID: request.responseAssetID
        ), let data = json.data(using: .utf8) else {
            throw ProviderAgentRunError.persistenceFailed
        }
        do {
            return try JSONDecoder().decode(
                ProviderResponsePayload.self,
                from: data
            )
        } catch {
            throw ProviderAgentRunError.persistenceFailed
        }
    }

    private func generationPrompt(
        for request: ProviderRequestSnapshot,
        intent: PendingModelIntent
    ) throws -> ProviderGenerationPrompt {
        guard request.identity.turnSequence > 1 else {
            return .initial(
                systemPrompt: Self.systemPrompt,
                userPrompt: intent.userRequest
            )
        }
        guard let previousRequestID = request.identity.previousRequestID,
              let previous = try database.providerRequest(
                id: previousRequestID
              ) else {
            throw ProviderAgentRunError.persistenceFailed
        }
        let previousCompletion = ProviderRunCompletion(
            request: previous,
            response: try response(for: previous)
        )
        return try continuationPrompt(
            response: previousCompletion.response,
            executions: executeTools(
                for: previousCompletion,
                userRequest: intent.userRequest
            ),
            userRequest: intent.userRequest
        )
    }

    private func executeTools(
        for completion: ProviderRunCompletion,
        userRequest: String
    ) throws -> [ProviderToolResolution] {
        guard let catalog = ProviderToolCatalogVersion.resolve(
            manifestHash: completion.request.toolCatalogManifestHash
        ) else {
            throw ProviderAgentRunError.invalidStream
        }
        var prepared: [PreparedProviderTool] = []
        for call in completion.response.toolCalls {
            guard let callID = call.id, let name = call.name else {
                throw ProviderAgentRunError.invalidStream
            }
            do {
                let invocation = try ProjectToolInvocation.parse(
                    providerFunctionName: name,
                    argumentsJSON: call.argumentsJSON,
                    providerCallID: callID,
                    providerCallIndex: call.index,
                    providerRequestID: completion.request.identity.requestID,
                    runID: completion.request.identity.runID,
                    conversationID: completion.request.identity.conversationID,
                    projectID: completion.request.identity.projectID
                )
                prepared.append(
                    PreparedProviderTool(call: call, invocation: invocation)
                )
            } catch {
                return try deniedToolResults(
                    for: completion.response.toolCalls,
                    reason: .invalidToolCall
                )
            }
        }

        guard prepared.allSatisfy({ item in
            guard let name = item.call.name else { return false }
            return catalog.allowedProviderFunctionNames.contains(name)
        }) else {
            return try deniedToolResults(
                for: completion.response.toolCalls,
                reason: .toolNotInCatalog
            )
        }

        guard prepared.filter(\.isMutating).count <= 1 else {
            return try deniedToolResults(
                for: completion.response.toolCalls,
                reason: .multipleMutatingTools
            )
        }

        guard prepared.allSatisfy({ $0.isAuthorized(by: userRequest) }) else {
            return try deniedToolResults(
                for: completion.response.toolCalls,
                reason: .missingUserAuthorization
            )
        }

        // Read-only calls run first so a read failure cannot follow a committed
        // business mutation. Results are restored to provider call order.
        let executionOrder = prepared.sorted {
            !$0.isMutating && $1.isMutating
        }
        var resolutionsByIndex: [Int: ProviderToolResolution] = [:]
        for item in executionOrder {
            let result = try database.executeProviderTool(
                item.invocation,
                now: now()
            )
            resolutionsByIndex[item.call.index] = .executed(result)
        }
        return try completion.response.toolCalls.map { call in
            guard let resolution = resolutionsByIndex[call.index] else {
                throw ProviderAgentRunError.persistenceFailed
            }
            return resolution
        }
    }

    private func continuationPrompt(
        response: ProviderResponsePayload,
        executions: [ProviderToolResolution],
        userRequest: String
    ) throws -> ProviderGenerationPrompt {
        try ProviderGenerationPrompt.continuation(
            systemPrompt: Self.systemPrompt,
            userPrompt: userRequest,
            assistantResponse: response,
            toolResults: try executions.map(Self.generationToolResult),
            allowsToolCalls: executions.isEmpty
        )
    }

    private func deniedToolResults(
        for calls: [ProviderToolCallPayload],
        reason: ProviderToolBatchRejectionReason
    ) throws -> [ProviderToolResolution] {
        try calls.map { call in
            guard let callID = call.id else {
                throw ProviderAgentRunError.invalidStream
            }
            let object: [String: Any] = [
                "error": [
                    "code": "tool_batch_rejected",
                    "reason": reason.rawValue
                ],
                "status": "denied"
            ]
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
            guard let json = String(data: data, encoding: .utf8) else {
                throw ProviderAgentRunError.persistenceFailed
            }
            return .denied(
                ProviderGenerationToolResult(
                    callID: callID,
                    callIndex: call.index,
                    contentJSON: json
                )
            )
        }
    }

    private static func generationToolResult(
        _ resolution: ProviderToolResolution
    ) throws -> ProviderGenerationToolResult {
        switch resolution {
        case let .executed(execution):
            return try generationToolResult(execution)
        case let .denied(result):
            return result
        }
    }

    private static func generationToolResult(
        _ execution: ProviderToolExecutionResult
    ) throws -> ProviderGenerationToolResult {
        let receipt = execution.receipt
        var receiptObject: [String: Any] = [
            "id": receipt.id.uuidString.lowercased(),
            "toolID": receipt.toolID,
            "outcome": receipt.outcome
        ]
        if let toolVersion = receipt.toolVersion {
            receiptObject["toolVersion"] = toolVersion
        }
        if let inputHash = receipt.inputHash {
            receiptObject["inputHash"] = inputHash
        }
        if let outputReference = receipt.outputReference {
            receiptObject["outputReference"] = outputReference
        }
        var object: [String: Any] = [
            "receipt": receiptObject,
            "receiptID": receipt.id.uuidString.lowercased(),
            "status": execution.status
        ]
        if let project = execution.project {
            object["project"] = [
                "id": project.id.uuidString.lowercased(),
                "title": project.title,
                "premise": project.premise
            ]
        }
        if !execution.projects.isEmpty {
            object["projects"] = execution.projects.map { project in
                [
                    "id": project.id.uuidString.lowercased(),
                    "title": project.title
                ]
            }
        }
        if let artifact = execution.artifact {
            object["artifact"] = [
                "id": artifact.id.uuidString.lowercased(),
                "kind": artifact.kind,
                "title": artifact.title,
                "status": artifact.status
            ]
        }
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys, .withoutEscapingSlashes]
              ), let json = String(data: data, encoding: .utf8) else {
            throw ProviderAgentRunError.persistenceFailed
        }
        return ProviderGenerationToolResult(
            callID: execution.invocation.providerCallID,
            callIndex: execution.invocation.providerCallIndex,
            contentJSON: json
        )
    }

    private static func promptManifestHash(
        _ prompt: ProviderGenerationPrompt
    ) throws -> String {
        if prompt.isInitial {
            return digest(["provider-prompt-v1", prompt.systemPrompt])
        }
        guard let response = prompt.assistantResponse else {
            throw ProviderAgentRunError.invalidStream
        }
        return digest(
            [
                prompt.allowsToolCalls
                    ? "provider-prompt-v2"
                    : "provider-prompt-v3-tools-disabled",
                prompt.systemPrompt,
                prompt.userPrompt,
                try encode(response)
            ] + prompt.toolResults.flatMap {
                [$0.callID, String($0.callIndex), $0.contentJSON]
            }
        )
    }

    private func settle(
        _ error: ProviderGenerationError,
        request: ProviderRequestSnapshot
    ) throws {
        switch error {
        case let .rejected(failure) where request.phase == .sending:
            let failed = try ProviderRequestLifecycle.reject(
                request,
                failure: failure,
                now: now()
            )
            try database.updateProviderRequest(failed)
        case let .outcomeUnknown(reason):
            try persistUnknown(request, reason: reason)
        case .invalidPreparedRequest where request.phase == .sending:
            let failed = try ProviderRequestLifecycle.reject(
                request,
                failure: .invalidRequest,
                now: now()
            )
            try database.updateProviderRequest(failed)
        case .invalidPreparedRequest:
            throw ProviderAgentRunError.persistenceFailed
        case .unsupportedProvider, .customDestinationPinningUnavailable,
             .rejected:
            try persistUnknown(request, reason: .invalidResponse)
        }
    }

    private func persistUnknown(
        _ request: ProviderRequestSnapshot,
        reason: ProviderRequestInterruption
    ) throws {
        guard request.phase == .sending || request.phase == .streaming else {
            throw ProviderAgentRunError.persistenceFailed
        }
        let unknown = try ProviderRequestLifecycle.markOutcomeUnknown(
            request,
            reason: reason,
            now: now()
        )
        do {
            try database.updateProviderRequest(unknown)
        } catch {
            guard let stored = try? database.providerRequest(
                intentID: request.identity.intentID
            ), stored.identity.requestID == request.identity.requestID,
                  stored.phase == .outcomeUnknown else {
                throw error
            }
        }
    }

    private static func apply(
        _ event: ProviderGenerationEvent,
        response: inout ProviderResponsePayload,
        usage: inout ProviderUsage?
    ) throws {
        switch event {
        case let .textDelta(delta):
            guard !delta.isEmpty else {
                throw ProviderAgentRunError.invalidStream
            }
            let text = response.text + delta
            guard text.utf8.count <= ProviderResponsePayload.maximumUTF8Bytes else {
                throw ProviderGenerationError.outcomeUnknown(.outputLimit)
            }
            response = ProviderResponsePayload(
                text: text,
                toolCalls: response.toolCalls,
                finishReason: response.finishReason
            )
        case let .toolCallDelta(index, id, name, argumentsFragment):
            guard index >= 0,
                  index <= response.toolCalls.count,
                  index < ProviderResponsePayload.maximumToolCalls else {
                throw ProviderAgentRunError.invalidStream
            }
            var calls = response.toolCalls
            if index == calls.count {
                calls.append(
                    ProviderToolCallPayload(
                        index: index,
                        id: id,
                        name: name,
                        argumentsJSON: argumentsFragment
                    )
                )
            } else {
                let existing = calls[index]
                guard id == nil || existing.id == nil || id == existing.id,
                      name == nil || existing.name == nil
                        || name == existing.name else {
                    throw ProviderAgentRunError.invalidStream
                }
                let arguments = existing.argumentsJSON + argumentsFragment
                guard arguments.utf8.count
                        <= ProviderResponsePayload
                            .maximumToolArgumentsUTF8Bytes else {
                    throw ProviderGenerationError.outcomeUnknown(.outputLimit)
                }
                calls[index] = ProviderToolCallPayload(
                    index: index,
                    id: existing.id ?? id,
                    name: existing.name ?? name,
                    argumentsJSON: arguments
                )
            }
            response = ProviderResponsePayload(
                text: response.text,
                toolCalls: calls,
                finishReason: response.finishReason
            )
        case let .finished(reason):
            guard response.finishReason == nil
                    || response.finishReason == reason else {
                throw ProviderAgentRunError.invalidStream
            }
            response = ProviderResponsePayload(
                text: response.text,
                toolCalls: response.toolCalls,
                finishReason: reason
            )
        case let .usage(record):
            guard usage == nil || usage == record else {
                throw ProviderAgentRunError.invalidStream
            }
            usage = record
        }
        try response.validate()
    }

    private static func requiresImmediateCheckpoint(
        _ event: ProviderGenerationEvent
    ) -> Bool {
        switch event {
        case .finished, .usage:
            return true
        case .textDelta, .toolCallDelta:
            return false
        }
    }

    private func flushBufferedResponse(
        _ response: ProviderResponsePayload,
        usage: ProviderUsage?,
        request: inout ProviderRequestSnapshot
    ) throws {
        guard request.phase == .sending || request.phase == .streaming,
              response != .empty || usage != nil else {
            return
        }
        let responseJSON = try Self.encode(response)
        let responseHash = AppDatabase.payloadHash(responseJSON)
        guard responseHash != request.responseHash else { return }
        request = try ProviderRequestLifecycle.checkpointStream(
            request,
            cursor: request.streamCursor + 1,
            receivedUTF8Bytes: responseJSON.utf8.count,
            responseHash: responseHash,
            observedUsage: usage,
            now: now()
        )
        try database.checkpointProviderResponse(
            request,
            responsePayloadJSON: responseJSON
        )
    }

    private static func projection(
        request: ProviderRequestSnapshot,
        response: ProviderResponsePayload,
        usage: ProviderUsage?
    ) -> ProviderRunProjection {
        ProviderRunProjection(
            requestID: request.identity.requestID,
            phase: request.phase,
            text: response.text,
            usage: usage
        )
    }

    private static func encode(
        _ response: ProviderResponsePayload
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(response)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ProviderAgentRunError.invalidStream
        }
        return json
    }

    private static func supports(_ provider: ModelProvider) -> Bool {
        ProviderGenerationCapability.supports(provider)
    }

    private static func acceptedToolCatalogManifestHash(
        _ actual: String,
        expected: String
    ) -> Bool {
        actual == expected
            || ProviderToolCatalogVersion.resolve(manifestHash: actual) != nil
    }

    private static func acceptedRequestPolicyManifestHash(
        _ actual: String,
        expected: String,
        identity: ProviderRequestIdentity
    ) -> Bool {
        actual == expected
            || ProviderRequestPolicyVersion.resolve(
                manifestHash: actual,
                identity: identity
            ) != nil
    }

    private static func matches(
        _ credential: KeychainBoundModelCredential,
        _ identity: ProviderRequestIdentity
    ) -> Bool {
        let reference = credential.reference
        return reference.id == identity.credentialID
            && reference.connectionID == identity.connectionID
            && reference.provider == identity.provider
            && reference.versionID == identity.credentialVersionID
            && credential.credentialVersionProof
                == identity.credentialVersionProof
            && credential.credentialPayloadHash
                == identity.credentialPayloadHash
            && credential.setupAuthorizationHash
                == identity.setupAuthorizationHash
    }

    private static func digest(_ fields: [String]) -> String {
        var data = Data()
        for field in fields {
            let bytes = Data(field.utf8)
            data.append(Data(String(bytes.count).utf8))
            data.append(0x3A)
            data.append(bytes)
            data.append(0x7C)
        }
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private enum ProviderToolBatchRejectionReason: String {
    case invalidToolCall = "invalid_tool_call"
    case toolNotInCatalog = "tool_not_in_catalog"
    case multipleMutatingTools = "multiple_mutating_tools"
    case missingUserAuthorization = "missing_user_authorization"
}

private struct PreparedProviderTool {
    let call: ProviderToolCallPayload
    let invocation: ProjectToolInvocation

    var isMutating: Bool {
        switch invocation.arguments {
        case .create, .switchProject, .saveDiscussion:
            return true
        case .list, .status:
            return false
        }
    }

    func isAuthorized(by userRequest: String) -> Bool {
        let admission = ProviderToolAdmission.resolve(userRequest)
        switch invocation.arguments {
        case let .create(title, premise):
            return admission == .createProject(
                title: ProviderToolAdmission.normalize(title),
                premise: ProviderToolAdmission.normalize(premise)
            )
        case .switchProject:
            // The natural-language intent does not carry an exact target ID.
            // Keep this fail-closed until a UI-bound target capability exists.
            return false
        case .saveDiscussion:
            // Discussion content is model-authored and cannot be parameter-bound
            // to the user's click yet, so it requires a future approval flow.
            return false
        case .list:
            return admission == .listProjects
        case .status:
            return admission == .projectStatus
        }
    }
}

private enum ProviderToolAdmission: Equatable {
    case createProject(title: String, premise: String)
    case listProjects
    case projectStatus

    static func resolve(_ userRequest: String) -> ProviderToolAdmission? {
        let request = userRequest.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
        let blockers = [
            "不要", "先别", "暂不", "别执行", "只讨论", "不要写入",
            "do not", "don't", "never", "discuss only"
        ]
        guard !blockers.contains(where: request.contains) else { return nil }

        if [
            "列出我的小说项目", "查看我的小说项目", "我有哪些小说项目",
            "list my novel projects"
        ].contains(request) {
            return .listProjects
        }
        if [
            "查看当前小说项目状态", "当前小说项目状态", "当前项目状态",
            "show current novel project status"
        ].contains(request) {
            return .projectStatus
        }

        let namedProjectPrefixes = [
            "创建一本叫", "请创建一本叫", "帮我创建一本叫",
            "新建一本叫", "请新建一本叫", "帮我新建一本叫",
            "建立一本叫", "请建立一本叫", "帮我建立一本叫"
        ]
        for prefix in namedProjectPrefixes where request.hasPrefix(prefix) {
            let remainder = request.dropFirst(prefix.count)
            guard let end = remainder.firstIndex(of: "的") else { return nil }
            let title = normalize(String(remainder[..<end]))
            let premiseStart = remainder.index(after: end)
            let premise = normalize(String(remainder[premiseStart...]))
            return title.isEmpty || premise.isEmpty
                ? nil
                : .createProject(title: title, premise: premise)
        }
        return nil
    }

    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private enum ProviderToolResolution {
    case executed(ProviderToolExecutionResult)
    case denied(ProviderGenerationToolResult)

    var receipt: ToolReceipt? {
        guard case let .executed(result) = self else { return nil }
        return result.receipt
    }
}

private extension ProviderResponsePayload {
    static let empty = ProviderResponsePayload(
        text: "",
        toolCalls: [],
        finishReason: nil
    )
}
