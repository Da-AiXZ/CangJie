import Foundation

public enum ProviderRequestPhase: String, Codable, Equatable, Sendable {
    case prepared
    case sending
    case streaming
    case responseComplete
    case continuationCommitted
    case cancelled
    case failed
    case outcomeUnknown
}

public enum ProviderRequestFailure: String, Codable, Equatable, Sendable {
    case invalidRequest
    case authentication
    case permissionDenied
    case rateLimited
    case providerUnavailable
    case invalidResponse
    case unsupportedProvider
    case network
    case timeout
    case outputLimit
}

public enum ProviderRequestInterruption: String, Codable, Equatable, Sendable {
    case cancelled
    case network
    case timeout
    case outputLimit
    case lifecycleInterruption
    case invalidResponse
    case providerUnavailable
}

public enum ProviderRequestError: Error, Equatable, Sendable {
    case invalidHash
    case invalidIdentity
    case invalidSnapshot
    case invalidTimestamp
    case invalidUsage
    case nonMonotonicStreamCheckpoint
    case invalidTransition(from: ProviderRequestPhase, to: ProviderRequestPhase)
}

public struct ProviderUsage: Codable, Equatable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int

    public init(inputTokens: Int, outputTokens: Int, totalTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }
}

public struct ProviderRequestIdentity: Codable, Equatable, Sendable {
    public let requestID: UUID
    public let idempotencyKey: String
    public let intentID: UUID
    public let conversationID: UUID
    public let projectID: UUID?
    public let branchID: UUID?
    public let runID: UUID
    public let connectionID: UUID
    public let credentialID: UUID
    public let credentialVersionID: UUID
    public let credentialVersionProof: String
    public let credentialPayloadHash: String
    public let setupAuthorizationHash: String?
    public let provider: ModelProvider
    public let baseURL: URL
    public let modelID: String

    init(
        requestID: UUID,
        idempotencyKey: String,
        intentID: UUID,
        conversationID: UUID,
        projectID: UUID?,
        branchID: UUID?,
        runID: UUID,
        connectionID: UUID,
        credentialID: UUID,
        credentialVersionID: UUID,
        credentialVersionProof: String,
        credentialPayloadHash: String,
        setupAuthorizationHash: String?,
        provider: ModelProvider,
        baseURL: URL,
        modelID: String
    ) {
        self.requestID = requestID
        self.idempotencyKey = idempotencyKey
        self.intentID = intentID
        self.conversationID = conversationID
        self.projectID = projectID
        self.branchID = branchID
        self.runID = runID
        self.connectionID = connectionID
        self.credentialID = credentialID
        self.credentialVersionID = credentialVersionID
        self.credentialVersionProof = credentialVersionProof
        self.credentialPayloadHash = credentialPayloadHash
        self.setupAuthorizationHash = setupAuthorizationHash
        self.provider = provider
        self.baseURL = baseURL
        self.modelID = modelID
    }
}

public struct ProviderRequestSnapshot: Codable, Equatable, Sendable {
    public let identity: ProviderRequestIdentity
    public let responseAssetID: UUID
    public let promptManifestHash: String
    public let contextManifestHash: String
    public let toolCatalogManifestHash: String
    public let disclosureScopeHash: String
    public let requestPolicyHash: String
    public let phase: ProviderRequestPhase
    public let streamCursor: Int
    public let receivedUTF8Bytes: Int
    public let responseHash: String?
    public let usage: ProviderUsage?
    public let failure: ProviderRequestFailure?
    public let interruption: ProviderRequestInterruption?
    public let createdAt: Date
    public let updatedAt: Date

    fileprivate init(
        identity: ProviderRequestIdentity,
        responseAssetID: UUID,
        promptManifestHash: String,
        contextManifestHash: String,
        toolCatalogManifestHash: String,
        disclosureScopeHash: String,
        requestPolicyHash: String,
        phase: ProviderRequestPhase,
        streamCursor: Int,
        receivedUTF8Bytes: Int,
        responseHash: String?,
        usage: ProviderUsage?,
        failure: ProviderRequestFailure?,
        interruption: ProviderRequestInterruption?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.identity = identity
        self.responseAssetID = responseAssetID
        self.promptManifestHash = promptManifestHash
        self.contextManifestHash = contextManifestHash
        self.toolCatalogManifestHash = toolCatalogManifestHash
        self.disclosureScopeHash = disclosureScopeHash
        self.requestPolicyHash = requestPolicyHash
        self.phase = phase
        self.streamCursor = streamCursor
        self.receivedUTF8Bytes = receivedUTF8Bytes
        self.responseHash = responseHash
        self.usage = usage
        self.failure = failure
        self.interruption = interruption
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            identity: try container.decode(
                ProviderRequestIdentity.self,
                forKey: .identity
            ),
            responseAssetID: try container.decode(UUID.self, forKey: .responseAssetID),
            promptManifestHash: try container.decode(String.self, forKey: .promptManifestHash),
            contextManifestHash: try container.decode(String.self, forKey: .contextManifestHash),
            toolCatalogManifestHash: try container.decode(String.self, forKey: .toolCatalogManifestHash),
            disclosureScopeHash: try container.decode(String.self, forKey: .disclosureScopeHash),
            requestPolicyHash: try container.decode(String.self, forKey: .requestPolicyHash),
            phase: try container.decode(ProviderRequestPhase.self, forKey: .phase),
            streamCursor: try container.decode(Int.self, forKey: .streamCursor),
            receivedUTF8Bytes: try container.decode(Int.self, forKey: .receivedUTF8Bytes),
            responseHash: try container.decodeIfPresent(String.self, forKey: .responseHash),
            usage: try container.decodeIfPresent(ProviderUsage.self, forKey: .usage),
            failure: try container.decodeIfPresent(ProviderRequestFailure.self, forKey: .failure),
            interruption: try container.decodeIfPresent(
                ProviderRequestInterruption.self,
                forKey: .interruption
            ),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
        try validateInvariants()
    }

    fileprivate func validateInvariants() throws {
        guard ProviderRequestLifecycle.validIdentity(identity),
              ProviderRequestLifecycle.isCanonicalSHA256(promptManifestHash),
              ProviderRequestLifecycle.isCanonicalSHA256(contextManifestHash),
              ProviderRequestLifecycle.isCanonicalSHA256(toolCatalogManifestHash),
              ProviderRequestLifecycle.isCanonicalSHA256(disclosureScopeHash),
              ProviderRequestLifecycle.isCanonicalSHA256(requestPolicyHash),
              createdAt.timeIntervalSinceReferenceDate.isFinite,
              updatedAt.timeIntervalSinceReferenceDate.isFinite,
              updatedAt >= createdAt,
              streamCursor >= 0,
              receivedUTF8Bytes >= 0 else {
            throw ProviderRequestError.invalidSnapshot
        }

        if let responseHash,
           !ProviderRequestLifecycle.isCanonicalSHA256(responseHash) {
            throw ProviderRequestError.invalidSnapshot
        }
        if let usage, !ProviderRequestLifecycle.validUsage(usage) {
            throw ProviderRequestError.invalidSnapshot
        }

        let hasStream = streamCursor > 0
        guard hasStream == (responseHash != nil) else {
            throw ProviderRequestError.invalidSnapshot
        }
        switch phase {
        case .prepared, .sending, .cancelled:
            guard streamCursor == 0,
                  receivedUTF8Bytes == 0,
                  responseHash == nil,
                  usage == nil,
                  failure == nil,
                  interruption == nil else {
                throw ProviderRequestError.invalidSnapshot
            }
        case .streaming:
            guard hasStream,
                  usage == nil,
                  failure == nil,
                  interruption == nil else {
                throw ProviderRequestError.invalidSnapshot
            }
        case .responseComplete, .continuationCommitted:
            guard hasStream,
                  usage != nil,
                  failure == nil,
                  interruption == nil else {
                throw ProviderRequestError.invalidSnapshot
            }
        case .failed:
            guard streamCursor == 0,
                  receivedUTF8Bytes == 0,
                  responseHash == nil,
                  usage == nil,
                  failure != nil,
                  interruption == nil else {
                throw ProviderRequestError.invalidSnapshot
            }
        case .outcomeUnknown:
            guard usage == nil,
                  failure == nil,
                  interruption != nil else {
                throw ProviderRequestError.invalidSnapshot
            }
        }
    }
}

public enum ProviderRequestRecoveryAction: Equatable, Sendable {
    case sendPersistedRequest
    case reconcileUnknownOutcome
    case continueFromDurableResponse
    case terminal
}

public enum ProviderRequestRecovery {
    public static func nextAction(
        for request: ProviderRequestSnapshot
    ) -> ProviderRequestRecoveryAction {
        switch request.phase {
        case .prepared:
            return .sendPersistedRequest
        case .sending, .streaming, .outcomeUnknown:
            return .reconcileUnknownOutcome
        case .responseComplete:
            return .continueFromDurableResponse
        case .continuationCommitted, .cancelled, .failed:
            return .terminal
        }
    }
}

public enum ProviderRequestLifecycle {
    public static func validateTransition(
        from current: ProviderRequestSnapshot,
        to next: ProviderRequestSnapshot
    ) throws {
        let expected: ProviderRequestSnapshot
        switch (current.phase, next.phase) {
        case (.prepared, .sending):
            expected = try markSending(current, now: next.updatedAt)
        case (.prepared, .cancelled):
            expected = try cancel(current, now: next.updatedAt)
        case (.prepared, .failed):
            guard let failure = next.failure else {
                throw ProviderRequestError.invalidSnapshot
            }
            expected = try failBeforeSend(
                current,
                failure: failure,
                now: next.updatedAt
            )
        case (.sending, .streaming), (.streaming, .streaming):
            guard let responseHash = next.responseHash else {
                throw ProviderRequestError.invalidSnapshot
            }
            expected = try checkpointStream(
                current,
                cursor: next.streamCursor,
                receivedUTF8Bytes: next.receivedUTF8Bytes,
                responseHash: responseHash,
                now: next.updatedAt
            )
        case (.sending, .failed):
            guard let failure = next.failure else {
                throw ProviderRequestError.invalidSnapshot
            }
            expected = try reject(
                current,
                failure: failure,
                now: next.updatedAt
            )
        case (.sending, .outcomeUnknown), (.streaming, .outcomeUnknown):
            guard let interruption = next.interruption else {
                throw ProviderRequestError.invalidSnapshot
            }
            expected = try markOutcomeUnknown(
                current,
                reason: interruption,
                now: next.updatedAt
            )
        case (.streaming, .responseComplete):
            guard let responseHash = next.responseHash,
                  let usage = next.usage else {
                throw ProviderRequestError.invalidSnapshot
            }
            expected = try complete(
                current,
                responseHash: responseHash,
                usage: usage,
                now: next.updatedAt
            )
        case (.responseComplete, .continuationCommitted):
            expected = try commitContinuation(
                current,
                now: next.updatedAt
            )
        default:
            throw ProviderRequestError.invalidTransition(
                from: current.phase,
                to: next.phase
            )
        }
        guard expected == next else {
            throw ProviderRequestError.invalidSnapshot
        }
    }

    public static func prepare(
        requestID: UUID,
        runID: UUID,
        idempotencyKey: String,
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        responseAssetID: UUID,
        promptManifestHash: String,
        contextManifestHash: String,
        toolCatalogManifestHash: String,
        disclosureScopeHash: String,
        requestPolicyHash: String,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        let connection = verifiedConnection.connection
        let verification = verifiedConnection.credentialVerification
        let identity = ProviderRequestIdentity(
            requestID: requestID,
            idempotencyKey: idempotencyKey,
            intentID: intent.id,
            conversationID: intent.conversationID,
            projectID: intent.projectID,
            branchID: intent.branchID,
            runID: runID,
            connectionID: connection.id,
            credentialID: verification.credentialID,
            credentialVersionID: verification.versionID,
            credentialVersionProof: verification.credentialVersionProof,
            credentialPayloadHash: verification.credentialPayloadHash,
            setupAuthorizationHash: verification.setupAuthorizationHash,
            provider: connection.provider,
            baseURL: connection.baseURL,
            modelID: connection.selectedModel
        )
        return try prepare(
            identity: identity,
            responseAssetID: responseAssetID,
            promptManifestHash: promptManifestHash,
            contextManifestHash: contextManifestHash,
            toolCatalogManifestHash: toolCatalogManifestHash,
            disclosureScopeHash: disclosureScopeHash,
            requestPolicyHash: requestPolicyHash,
            now: now
        )
    }

    static func prepare(
        identity: ProviderRequestIdentity,
        responseAssetID: UUID,
        promptManifestHash: String,
        contextManifestHash: String,
        toolCatalogManifestHash: String,
        disclosureScopeHash: String,
        requestPolicyHash: String,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        guard validIdentity(identity) else {
            throw ProviderRequestError.invalidIdentity
        }
        guard [
            promptManifestHash,
            contextManifestHash,
            toolCatalogManifestHash,
            disclosureScopeHash,
            requestPolicyHash
        ].allSatisfy(isCanonicalSHA256) else {
            throw ProviderRequestError.invalidHash
        }
        try requireFinite(now)
        let request = ProviderRequestSnapshot(
            identity: identity,
            responseAssetID: responseAssetID,
            promptManifestHash: promptManifestHash,
            contextManifestHash: contextManifestHash,
            toolCatalogManifestHash: toolCatalogManifestHash,
            disclosureScopeHash: disclosureScopeHash,
            requestPolicyHash: requestPolicyHash,
            phase: .prepared,
            streamCursor: 0,
            receivedUTF8Bytes: 0,
            responseHash: nil,
            usage: nil,
            failure: nil,
            interruption: nil,
            createdAt: now,
            updatedAt: now
        )
        try request.validateInvariants()
        return request
    }

    public static func markSending(
        _ request: ProviderRequestSnapshot,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        guard request.phase == .prepared else {
            throw ProviderRequestError.invalidTransition(
                from: request.phase,
                to: .sending
            )
        }
        return try transition(request, phase: .sending, now: now)
    }

    public static func checkpointStream(
        _ request: ProviderRequestSnapshot,
        cursor: Int,
        receivedUTF8Bytes: Int,
        responseHash: String,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        guard request.phase == .sending || request.phase == .streaming else {
            throw ProviderRequestError.invalidTransition(
                from: request.phase,
                to: .streaming
            )
        }
        guard cursor > request.streamCursor,
              receivedUTF8Bytes >= request.receivedUTF8Bytes else {
            throw ProviderRequestError.nonMonotonicStreamCheckpoint
        }
        guard isCanonicalSHA256(responseHash) else {
            throw ProviderRequestError.invalidHash
        }
        return try transition(
            request,
            phase: .streaming,
            streamCursor: cursor,
            receivedUTF8Bytes: receivedUTF8Bytes,
            responseHash: responseHash,
            now: now
        )
    }

    public static func complete(
        _ request: ProviderRequestSnapshot,
        responseHash: String,
        usage: ProviderUsage,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        guard request.phase == .streaming else {
            throw ProviderRequestError.invalidTransition(
                from: request.phase,
                to: .responseComplete
            )
        }
        guard isCanonicalSHA256(responseHash) else {
            throw ProviderRequestError.invalidHash
        }
        guard validUsage(usage) else {
            throw ProviderRequestError.invalidUsage
        }
        return try transition(
            request,
            phase: .responseComplete,
            responseHash: responseHash,
            usage: usage,
            now: now
        )
    }

    public static func commitContinuation(
        _ request: ProviderRequestSnapshot,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        guard request.phase == .responseComplete else {
            throw ProviderRequestError.invalidTransition(
                from: request.phase,
                to: .continuationCommitted
            )
        }
        return try transition(
            request,
            phase: .continuationCommitted,
            now: now
        )
    }

    public static func cancel(
        _ request: ProviderRequestSnapshot,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        guard request.phase == .prepared else {
            throw ProviderRequestError.invalidTransition(
                from: request.phase,
                to: .cancelled
            )
        }
        return try transition(request, phase: .cancelled, now: now)
    }

    public static func failBeforeSend(
        _ request: ProviderRequestSnapshot,
        failure: ProviderRequestFailure,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        guard request.phase == .prepared else {
            throw ProviderRequestError.invalidTransition(
                from: request.phase,
                to: .failed
            )
        }
        return try transition(
            request,
            phase: .failed,
            failure: failure,
            now: now
        )
    }

    public static func reject(
        _ request: ProviderRequestSnapshot,
        failure: ProviderRequestFailure,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        let definitiveFailures: Set<ProviderRequestFailure> = [
            .invalidRequest,
            .authentication,
            .permissionDenied,
            .rateLimited,
            .unsupportedProvider
        ]
        guard request.phase == .sending,
              definitiveFailures.contains(failure) else {
            throw ProviderRequestError.invalidTransition(
                from: request.phase,
                to: .failed
            )
        }
        return try transition(
            request,
            phase: .failed,
            failure: failure,
            now: now
        )
    }

    public static func markOutcomeUnknown(
        _ request: ProviderRequestSnapshot,
        reason: ProviderRequestInterruption,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        guard request.phase == .sending || request.phase == .streaming else {
            throw ProviderRequestError.invalidTransition(
                from: request.phase,
                to: .outcomeUnknown
            )
        }
        return try transition(
            request,
            phase: .outcomeUnknown,
            interruption: reason,
            now: now
        )
    }

    private static func transition(
        _ request: ProviderRequestSnapshot,
        phase: ProviderRequestPhase,
        streamCursor: Int? = nil,
        receivedUTF8Bytes: Int? = nil,
        responseHash: String? = nil,
        usage: ProviderUsage? = nil,
        failure: ProviderRequestFailure? = nil,
        interruption: ProviderRequestInterruption? = nil,
        now: Date
    ) throws -> ProviderRequestSnapshot {
        try request.validateInvariants()
        try requireFinite(now)
        guard now >= request.updatedAt else {
            throw ProviderRequestError.invalidTimestamp
        }
        let transitioned = ProviderRequestSnapshot(
            identity: request.identity,
            responseAssetID: request.responseAssetID,
            promptManifestHash: request.promptManifestHash,
            contextManifestHash: request.contextManifestHash,
            toolCatalogManifestHash: request.toolCatalogManifestHash,
            disclosureScopeHash: request.disclosureScopeHash,
            requestPolicyHash: request.requestPolicyHash,
            phase: phase,
            streamCursor: streamCursor ?? request.streamCursor,
            receivedUTF8Bytes: receivedUTF8Bytes ?? request.receivedUTF8Bytes,
            responseHash: responseHash ?? request.responseHash,
            usage: usage ?? request.usage,
            failure: failure,
            interruption: interruption,
            createdAt: request.createdAt,
            updatedAt: now
        )
        try transitioned.validateInvariants()
        return transitioned
    }

    fileprivate static func validIdentity(
        _ identity: ProviderRequestIdentity
    ) -> Bool {
        let modelID = identity.modelID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !identity.idempotencyKey.isEmpty,
              identity.idempotencyKey.utf8.count <= 512,
              !containsUnsafeDisplayControl(identity.idempotencyKey),
              !modelID.isEmpty,
              modelID.utf8.count <= ModelConnection.maximumModelIdentifierUTF8Bytes,
              !containsUnsafeDisplayControl(modelID),
              identity.branchID == nil || identity.projectID != nil,
              isCanonicalSHA256(identity.credentialVersionProof),
              isCanonicalSHA256(identity.credentialPayloadHash),
              identity.setupAuthorizationHash.map(isCanonicalSHA256) ?? true,
              let components = URLComponents(
                url: identity.baseURL,
                resolvingAgainstBaseURL: false
              ),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return false
        }
        return true
    }

    fileprivate static func validUsage(_ usage: ProviderUsage) -> Bool {
        guard usage.inputTokens >= 0,
              usage.outputTokens >= 0,
              usage.totalTokens >= 0 else {
            return false
        }
        let (sum, overflow) = usage.inputTokens.addingReportingOverflow(
            usage.outputTokens
        )
        return !overflow && sum == usage.totalTokens
    }

    private static func requireFinite(_ date: Date) throws {
        guard date.timeIntervalSinceReferenceDate.isFinite else {
            throw ProviderRequestError.invalidTimestamp
        }
    }

    private static func containsUnsafeDisplayControl(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            if CharacterSet.controlCharacters.contains(scalar) {
                return true
            }
            switch scalar.value {
            case 0x061C, 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x2069:
                return true
            default:
                return false
            }
        }
    }

    fileprivate static func isCanonicalSHA256(_ value: String) -> Bool {
        value.utf8.count == 64
            && value.unicodeScalars.allSatisfy { scalar in
                switch scalar.value {
                case 0x30...0x39, 0x61...0x66:
                    return true
                default:
                    return false
                }
            }
    }
}
