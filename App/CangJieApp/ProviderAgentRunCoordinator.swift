import CangJieCore
import CryptoKit
import Foundation

@MainActor
final class ProviderAgentRunCoordinator {
    static let systemPrompt = """
    You are CangJie, the control plane for a local novel-writing application.
    This S2 milestone does not write formal prose. Respond briefly and truthfully.
    Use project_create only when the user explicitly asks to create or preserve a novel project.
    Use project_status to read real project state. Never claim a tool succeeded before its result is returned.
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

    func run(
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        onUpdate: (ProviderRunProjection) -> Void = { _ in }
    ) async throws -> ProviderRunCompletion {
        var request: ProviderRequestSnapshot
        if let existing = try database.providerRequest(intentID: intent.id) {
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
            let cancelled = try ProviderRequestLifecycle.cancel(
                request,
                now: now()
            )
            try database.updateProviderRequest(cancelled)
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
        do {
            let stream = generation.stream(
                request: request,
                verifiedConnection: verifiedConnection,
                secret: credential.secret,
                prompt: prompt
            )
            for try await event in stream {
                try Self.apply(event, response: &response, usage: &usage)
                let responseJSON = try Self.encode(response)
                request = try ProviderRequestLifecycle.checkpointStream(
                    request,
                    cursor: request.streamCursor + 1,
                    receivedUTF8Bytes: responseJSON.utf8.count,
                    responseHash: AppDatabase.payloadHash(responseJSON),
                    now: now()
                )
                try database.checkpointProviderResponse(
                    request,
                    responsePayloadJSON: responseJSON
                )
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
            if error == .invalidStream {
                try persistUnknown(request, reason: .invalidResponse)
            }
            throw error
        } catch is CancellationError {
            try persistUnknown(request, reason: .cancelled)
            throw ProviderAgentRunError.outcomeUnknown(.cancelled)
        } catch {
            do {
                try persistUnknown(request, reason: .network)
            } catch {
                throw ProviderAgentRunError.persistenceFailed
            }
            throw ProviderAgentRunError.outcomeUnknown(.network)
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
            try Task.checkCancellation()
            guard completion.request.identity.turnSequence
                    < ProviderRequestLifecycle.maximumTurnsPerAttempt else {
                throw ProviderAgentRunError.terminalRequest
            }
            let executions = try executeTools(for: completion)
            receipts.append(contentsOf: executions.map(\.receipt))
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
            toolCatalogManifestHash: digest([
                "provider-tool-catalog-v2",
                "project.create@1",
                "project.list@1",
                "project.status@1",
                "project.switch@1",
                "conversation.save_discussion@1"
            ]),
            disclosureScopeHash: digest([
                "provider-disclosure-v1",
                intent.userRequest
            ]),
            requestPolicyHash: digest([
                "provider-policy-v1",
                connection.provider.rawValue,
                connection.baseURL.absoluteString,
                connection.selectedModel,
                "stream=true",
                "usage=required",
                "max-response-bytes=262144"
            ]),
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
              request.requestPolicyHash == expected.requestPolicyHash,
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
            executions: executeTools(for: previousCompletion),
            userRequest: intent.userRequest
        )
    }

    private func executeTools(
        for completion: ProviderRunCompletion
    ) throws -> [ProviderToolExecutionResult] {
        try completion.response.toolCalls.map { call in
            guard let callID = call.id, let name = call.name else {
                throw ProviderAgentRunError.invalidStream
            }
            let invocation: ProjectToolInvocation
            do {
                invocation = try ProjectToolInvocation.parse(
                    providerFunctionName: name,
                    argumentsJSON: call.argumentsJSON,
                    providerCallID: callID,
                    providerCallIndex: call.index,
                    providerRequestID: completion.request.identity.requestID,
                    runID: completion.request.identity.runID,
                    conversationID: completion.request.identity.conversationID,
                    projectID: completion.request.identity.projectID
                )
            } catch {
                throw ProviderAgentRunError.invalidStream
            }
            return try database.executeProviderTool(invocation, now: now())
        }
    }

    private func continuationPrompt(
        response: ProviderResponsePayload,
        executions: [ProviderToolExecutionResult],
        userRequest: String
    ) throws -> ProviderGenerationPrompt {
        try ProviderGenerationPrompt.continuation(
            systemPrompt: Self.systemPrompt,
            userPrompt: userRequest,
            assistantResponse: response,
            toolResults: try executions.map(Self.generationToolResult)
        )
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
                    "title": project.title,
                    "premise": project.premise
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
                "provider-prompt-v2",
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
        try database.updateProviderRequest(unknown)
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
        provider == .deepSeek || provider == .openAI || provider == .openRouter
    }

    private static func acceptedToolCatalogManifestHash(
        _ actual: String,
        expected: String
    ) -> Bool {
        actual == expected
            || actual == digest([
                "provider-tool-catalog-v1",
                "project.create@1",
                "project.status@1"
            ])
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

private extension ProviderResponsePayload {
    static let empty = ProviderResponsePayload(
        text: "",
        toolCalls: [],
        finishReason: nil
    )
}
