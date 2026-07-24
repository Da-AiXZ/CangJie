import Foundation

public enum BudgetGovernanceError: Error, Equatable, Sendable {
    case invalidPolicy
    case invalidUsage
    case invalidRequestIdentity
    case invalidEstimate
    case invalidApprovalBinding
}

public enum BudgetCostBasis: String, Codable, CaseIterable, Sendable {
    case estimated
    case actual
}

public enum BudgetUnknownCostReason: String, Codable, CaseIterable, Sendable {
    case pricingUnavailable
    case providerChargeUnavailable
    case outcomeUnknown
}

public enum BudgetCost: Codable, Equatable, Sendable {
    public static let microUnitScale: Int64 = 1_000_000

    case known(
        microUnits: Int64,
        basis: BudgetCostBasis,
        pricingVersion: String,
        currencyCode: String,
        scale: Int64
    )
    case unknown(
        reason: BudgetUnknownCostReason,
        pricingKey: String,
        currencyCode: String,
        scale: Int64
    )

    public var currencyCode: String {
        switch self {
        case let .known(_, _, _, currencyCode, _),
             let .unknown(_, _, currencyCode, _):
            return currencyCode
        }
    }

    public var scale: Int64 {
        switch self {
        case let .known(_, _, _, _, scale),
             let .unknown(_, _, _, scale):
            return scale
        }
    }

    fileprivate var knownMicroUnits: Int64? {
        guard case let .known(microUnits, _, _, _, _) = self else { return nil }
        return microUnits
    }

    fileprivate var isStructurallyValid: Bool {
        guard BudgetCanonical.validCurrencyCode(currencyCode),
              scale == Self.microUnitScale else {
            return false
        }
        switch self {
        case let .known(microUnits, _, pricingVersion, _, _):
            return microUnits >= 0
                && BudgetCanonical.validCanonicalText(
                    pricingVersion,
                    maximumUTF8Bytes: 512
                )
        case let .unknown(_, pricingKey, _, _):
            return BudgetCanonical.validCanonicalText(
                pricingKey,
                maximumUTF8Bytes: 8_192
            )
        }
    }

    fileprivate func appendCanonicalFields(to encoder: inout CanonicalFieldEncoder) {
        switch self {
        case let .known(microUnits, basis, pricingVersion, currencyCode, scale):
            encoder.append(name: "costKind", value: "known")
            encoder.append(name: "costMicroUnits", value: String(microUnits))
            encoder.append(name: "costBasis", value: basis.rawValue)
            encoder.append(name: "pricingVersion", value: pricingVersion)
            encoder.append(name: "costCurrencyCode", value: currencyCode)
            encoder.append(name: "costScale", value: String(scale))
        case let .unknown(reason, pricingKey, currencyCode, scale):
            encoder.append(name: "costKind", value: "unknown")
            encoder.append(name: "unknownCostReason", value: reason.rawValue)
            encoder.append(name: "pricingKey", value: pricingKey)
            encoder.append(name: "costCurrencyCode", value: currencyCode)
            encoder.append(name: "costScale", value: String(scale))
        }
    }

    private enum Kind: String, Codable {
        case known
        case unknown
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case microUnits
        case basis
        case pricingVersion
        case reason
        case pricingKey
        case currencyCode
        case scale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let decoded: BudgetCost
        switch kind {
        case .known:
            guard !container.contains(.reason), !container.contains(.pricingKey) else {
                throw BudgetCanonical.corrupted(
                    decoder,
                    "Known budget cost contains unknown-cost fields."
                )
            }
            decoded = .known(
                microUnits: try container.decode(Int64.self, forKey: .microUnits),
                basis: try container.decode(BudgetCostBasis.self, forKey: .basis),
                pricingVersion: try container.decode(String.self, forKey: .pricingVersion),
                currencyCode: try container.decode(String.self, forKey: .currencyCode),
                scale: try container.decode(Int64.self, forKey: .scale)
            )
        case .unknown:
            guard !container.contains(.microUnits),
                  !container.contains(.basis),
                  !container.contains(.pricingVersion) else {
                throw BudgetCanonical.corrupted(
                    decoder,
                    "Unknown budget cost contains known-cost fields."
                )
            }
            decoded = .unknown(
                reason: try container.decode(BudgetUnknownCostReason.self, forKey: .reason),
                pricingKey: try container.decode(String.self, forKey: .pricingKey),
                currencyCode: try container.decode(String.self, forKey: .currencyCode),
                scale: try container.decode(Int64.self, forKey: .scale)
            )
        }
        guard decoded.isStructurallyValid else {
            throw BudgetCanonical.corrupted(decoder, "Invalid budget cost.")
        }
        self = decoded
    }

    public func encode(to encoder: Encoder) throws {
        guard isStructurallyValid else {
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Invalid budget cost."
                )
            )
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .known(microUnits, basis, pricingVersion, currencyCode, scale):
            try container.encode(Kind.known, forKey: .kind)
            try container.encode(microUnits, forKey: .microUnits)
            try container.encode(basis, forKey: .basis)
            try container.encode(pricingVersion, forKey: .pricingVersion)
            try container.encode(currencyCode, forKey: .currencyCode)
            try container.encode(scale, forKey: .scale)
        case let .unknown(reason, pricingKey, currencyCode, scale):
            try container.encode(Kind.unknown, forKey: .kind)
            try container.encode(reason, forKey: .reason)
            try container.encode(pricingKey, forKey: .pricingKey)
            try container.encode(currencyCode, forKey: .currencyCode)
            try container.encode(scale, forKey: .scale)
        }
    }
}

public struct TaskBudgetPolicy: Codable, Equatable, Sendable {
    public let taskID: UUID
    public let version: Int64
    public let maximumInputTokens: Int64
    public let maximumOutputTokens: Int64
    public let maximumCostMicroUnits: Int64
    public let currencyCode: String
    public let costScale: Int64
    public let maximumElapsedMilliseconds: Int64

    public var canonicalHash: String {
        var encoder = CanonicalFieldEncoder()
        encoder.append(name: "schema", value: "cangjie.task-budget-policy.v1")
        encoder.append(name: "taskID", value: taskID.canonicalString)
        encoder.append(name: "version", value: String(version))
        encoder.append(name: "maximumInputTokens", value: String(maximumInputTokens))
        encoder.append(name: "maximumOutputTokens", value: String(maximumOutputTokens))
        encoder.append(name: "maximumCostMicroUnits", value: String(maximumCostMicroUnits))
        encoder.append(name: "currencyCode", value: currencyCode)
        encoder.append(name: "costScale", value: String(costScale))
        encoder.append(
            name: "maximumElapsedMilliseconds",
            value: String(maximumElapsedMilliseconds)
        )
        return BudgetCanonical.hash(encoder.bytes)
    }

    public init(
        taskID: UUID,
        version: Int64,
        maximumInputTokens: Int64,
        maximumOutputTokens: Int64,
        maximumCostMicroUnits: Int64,
        currencyCode: String,
        costScale: Int64,
        maximumElapsedMilliseconds: Int64
    ) throws {
        guard version > 0,
              maximumInputTokens >= 0,
              maximumOutputTokens >= 0,
              maximumCostMicroUnits >= 0,
              maximumElapsedMilliseconds >= 0,
              BudgetCanonical.validCurrencyCode(currencyCode),
              costScale == BudgetCost.microUnitScale else {
            throw BudgetGovernanceError.invalidPolicy
        }
        self.taskID = taskID
        self.version = version
        self.maximumInputTokens = maximumInputTokens
        self.maximumOutputTokens = maximumOutputTokens
        self.maximumCostMicroUnits = maximumCostMicroUnits
        self.currencyCode = currencyCode
        self.costScale = costScale
        self.maximumElapsedMilliseconds = maximumElapsedMilliseconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            taskID: try container.decode(UUID.self, forKey: .taskID),
            version: try container.decode(Int64.self, forKey: .version),
            maximumInputTokens: try container.decode(Int64.self, forKey: .maximumInputTokens),
            maximumOutputTokens: try container.decode(Int64.self, forKey: .maximumOutputTokens),
            maximumCostMicroUnits: try container.decode(
                Int64.self,
                forKey: .maximumCostMicroUnits
            ),
            currencyCode: try container.decode(String.self, forKey: .currencyCode),
            costScale: try container.decode(Int64.self, forKey: .costScale),
            maximumElapsedMilliseconds: try container.decode(
                Int64.self,
                forKey: .maximumElapsedMilliseconds
            )
        )
    }
}

public struct BudgetUsageSnapshot: Codable, Equatable, Sendable {
    public let taskID: UUID
    public let budgetVersion: Int64
    public let revision: Int64
    public let cumulativeInputTokens: Int64
    public let cumulativeOutputTokens: Int64
    public let cumulativeCost: BudgetCost
    public let cumulativeElapsedMilliseconds: Int64
    public let hasUnsettledReservation: Bool

    public var canonicalHash: String {
        var encoder = CanonicalFieldEncoder()
        encoder.append(name: "schema", value: "cangjie.budget-usage.v1")
        encoder.append(name: "taskID", value: taskID.canonicalString)
        encoder.append(name: "budgetVersion", value: String(budgetVersion))
        encoder.append(name: "revision", value: String(revision))
        encoder.append(
            name: "cumulativeInputTokens",
            value: String(cumulativeInputTokens)
        )
        encoder.append(
            name: "cumulativeOutputTokens",
            value: String(cumulativeOutputTokens)
        )
        cumulativeCost.appendCanonicalFields(to: &encoder)
        encoder.append(
            name: "cumulativeElapsedMilliseconds",
            value: String(cumulativeElapsedMilliseconds)
        )
        encoder.append(
            name: "hasUnsettledReservation",
            value: hasUnsettledReservation ? "true" : "false"
        )
        return BudgetCanonical.hash(encoder.bytes)
    }

    public init(
        taskID: UUID,
        budgetVersion: Int64,
        revision: Int64,
        cumulativeInputTokens: Int64,
        cumulativeOutputTokens: Int64,
        cumulativeCost: BudgetCost,
        cumulativeElapsedMilliseconds: Int64,
        hasUnsettledReservation: Bool
    ) throws {
        guard budgetVersion > 0,
              revision > 0,
              cumulativeInputTokens >= 0,
              cumulativeOutputTokens >= 0,
              cumulativeCost.isStructurallyValid,
              cumulativeElapsedMilliseconds >= 0 else {
            throw BudgetGovernanceError.invalidUsage
        }
        self.taskID = taskID
        self.budgetVersion = budgetVersion
        self.revision = revision
        self.cumulativeInputTokens = cumulativeInputTokens
        self.cumulativeOutputTokens = cumulativeOutputTokens
        self.cumulativeCost = cumulativeCost
        self.cumulativeElapsedMilliseconds = cumulativeElapsedMilliseconds
        self.hasUnsettledReservation = hasUnsettledReservation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            taskID: try container.decode(UUID.self, forKey: .taskID),
            budgetVersion: try container.decode(Int64.self, forKey: .budgetVersion),
            revision: try container.decode(Int64.self, forKey: .revision),
            cumulativeInputTokens: try container.decode(
                Int64.self,
                forKey: .cumulativeInputTokens
            ),
            cumulativeOutputTokens: try container.decode(
                Int64.self,
                forKey: .cumulativeOutputTokens
            ),
            cumulativeCost: try container.decode(BudgetCost.self, forKey: .cumulativeCost),
            cumulativeElapsedMilliseconds: try container.decode(
                Int64.self,
                forKey: .cumulativeElapsedMilliseconds
            ),
            hasUnsettledReservation: try container.decode(
                Bool.self,
                forKey: .hasUnsettledReservation
            )
        )
    }
}

public struct ProviderRequestBudgetTaskScope: Equatable, Sendable {
    public let taskID: UUID
    public let intentID: UUID
    public let activeRunID: UUID

    public init(taskID: UUID, intentID: UUID, activeRunID: UUID) {
        self.taskID = taskID
        self.intentID = intentID
        self.activeRunID = activeRunID
    }
}

public struct ProviderRequestBudgetIdentity: Codable, Equatable, Sendable {
    public let taskID: UUID
    public let identity: ProviderRequestIdentity
    public let responseAssetID: UUID
    public let promptManifestHash: String
    public let contextManifestHash: String
    public let toolCatalogManifestHash: String
    public let disclosureScopeHash: String
    public let requestPolicyHash: String

    public var requestID: UUID { identity.requestID }

    public var exactRequestHash: String {
        var encoder = CanonicalFieldEncoder()
        encoder.append(name: "schema", value: "cangjie.provider-budget-request.v1")
        encoder.append(name: "taskID", value: taskID.canonicalString)
        encoder.append(name: "requestID", value: identity.requestID.canonicalString)
        encoder.append(name: "idempotencyKey", value: identity.idempotencyKey)
        encoder.append(name: "intentID", value: identity.intentID.canonicalString)
        encoder.append(name: "conversationID", value: identity.conversationID.canonicalString)
        encoder.append(name: "projectID", value: identity.projectID?.canonicalString ?? "")
        encoder.append(name: "branchID", value: identity.branchID?.canonicalString ?? "")
        encoder.append(name: "runID", value: identity.runID.canonicalString)
        encoder.append(name: "attemptNumber", value: String(identity.attemptNumber))
        encoder.append(name: "turnSequence", value: String(identity.turnSequence))
        encoder.append(
            name: "previousRequestID",
            value: identity.previousRequestID?.canonicalString ?? ""
        )
        encoder.append(name: "connectionID", value: identity.connectionID.canonicalString)
        encoder.append(name: "credentialID", value: identity.credentialID.canonicalString)
        encoder.append(
            name: "credentialVersionID",
            value: identity.credentialVersionID.canonicalString
        )
        encoder.append(
            name: "credentialVersionProof",
            value: identity.credentialVersionProof
        )
        encoder.append(name: "credentialPayloadHash", value: identity.credentialPayloadHash)
        encoder.append(
            name: "setupAuthorizationHash",
            value: identity.setupAuthorizationHash ?? ""
        )
        encoder.append(name: "provider", value: identity.provider.rawValue)
        encoder.append(name: "baseURL", value: identity.baseURL.absoluteString)
        encoder.append(name: "modelID", value: identity.modelID)
        encoder.append(name: "responseAssetID", value: responseAssetID.canonicalString)
        encoder.append(name: "promptManifestHash", value: promptManifestHash)
        encoder.append(name: "contextManifestHash", value: contextManifestHash)
        encoder.append(name: "toolCatalogManifestHash", value: toolCatalogManifestHash)
        encoder.append(name: "disclosureScopeHash", value: disclosureScopeHash)
        encoder.append(name: "requestPolicyHash", value: requestPolicyHash)
        return BudgetCanonical.hash(encoder.bytes)
    }

    public init(
        trustedTaskScope: ProviderRequestBudgetTaskScope,
        request: ProviderRequestSnapshot
    ) throws {
        guard request.phase == .prepared,
              request.identity.intentID == trustedTaskScope.intentID,
              request.identity.runID == trustedTaskScope.activeRunID else {
            throw BudgetGovernanceError.invalidRequestIdentity
        }
        try self.init(
            taskID: trustedTaskScope.taskID,
            identity: request.identity,
            responseAssetID: request.responseAssetID,
            promptManifestHash: request.promptManifestHash,
            contextManifestHash: request.contextManifestHash,
            toolCatalogManifestHash: request.toolCatalogManifestHash,
            disclosureScopeHash: request.disclosureScopeHash,
            requestPolicyHash: request.requestPolicyHash
        )
    }

    private init(
        taskID: UUID,
        identity: ProviderRequestIdentity,
        responseAssetID: UUID,
        promptManifestHash: String,
        contextManifestHash: String,
        toolCatalogManifestHash: String,
        disclosureScopeHash: String,
        requestPolicyHash: String
    ) throws {
        guard BudgetCanonical.validProviderIdentity(identity),
              [
                promptManifestHash,
                contextManifestHash,
                toolCatalogManifestHash,
                disclosureScopeHash,
                requestPolicyHash
              ].allSatisfy(BudgetCanonical.isCanonicalSHA256) else {
            throw BudgetGovernanceError.invalidRequestIdentity
        }
        self.taskID = taskID
        self.identity = identity
        self.responseAssetID = responseAssetID
        self.promptManifestHash = promptManifestHash
        self.contextManifestHash = contextManifestHash
        self.toolCatalogManifestHash = toolCatalogManifestHash
        self.disclosureScopeHash = disclosureScopeHash
        self.requestPolicyHash = requestPolicyHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            taskID: try container.decode(UUID.self, forKey: .taskID),
            identity: try container.decode(ProviderRequestIdentity.self, forKey: .identity),
            responseAssetID: try container.decode(UUID.self, forKey: .responseAssetID),
            promptManifestHash: try container.decode(String.self, forKey: .promptManifestHash),
            contextManifestHash: try container.decode(String.self, forKey: .contextManifestHash),
            toolCatalogManifestHash: try container.decode(
                String.self,
                forKey: .toolCatalogManifestHash
            ),
            disclosureScopeHash: try container.decode(
                String.self,
                forKey: .disclosureScopeHash
            ),
            requestPolicyHash: try container.decode(String.self, forKey: .requestPolicyHash)
        )
    }
}

public struct NextRequestBudgetEstimate: Codable, Equatable, Sendable {
    public let requestIdentity: ProviderRequestBudgetIdentity
    public let reservedInputTokens: Int64
    public let reservedOutputTokens: Int64
    public let reservedCost: BudgetCost
    public let reservedElapsedMilliseconds: Int64

    public var taskID: UUID { requestIdentity.taskID }

    public var canonicalHash: String {
        var encoder = CanonicalFieldEncoder()
        encoder.append(name: "schema", value: "cangjie.next-request-budget.v1")
        encoder.append(name: "taskID", value: requestIdentity.taskID.canonicalString)
        encoder.append(name: "exactRequestHash", value: requestIdentity.exactRequestHash)
        encoder.append(name: "reservedInputTokens", value: String(reservedInputTokens))
        encoder.append(name: "reservedOutputTokens", value: String(reservedOutputTokens))
        reservedCost.appendCanonicalFields(to: &encoder)
        encoder.append(
            name: "reservedElapsedMilliseconds",
            value: String(reservedElapsedMilliseconds)
        )
        return BudgetCanonical.hash(encoder.bytes)
    }

    public init(
        requestIdentity: ProviderRequestBudgetIdentity,
        reservedInputTokens: Int64,
        reservedOutputTokens: Int64,
        reservedCost: BudgetCost,
        reservedElapsedMilliseconds: Int64
    ) throws {
        guard reservedInputTokens >= 0,
              reservedOutputTokens >= 0,
              reservedCost.isStructurallyValid,
              reservedElapsedMilliseconds >= 0 else {
            throw BudgetGovernanceError.invalidEstimate
        }
        self.requestIdentity = requestIdentity
        self.reservedInputTokens = reservedInputTokens
        self.reservedOutputTokens = reservedOutputTokens
        self.reservedCost = reservedCost
        self.reservedElapsedMilliseconds = reservedElapsedMilliseconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            requestIdentity: try container.decode(
                ProviderRequestBudgetIdentity.self,
                forKey: .requestIdentity
            ),
            reservedInputTokens: try container.decode(Int64.self, forKey: .reservedInputTokens),
            reservedOutputTokens: try container.decode(Int64.self, forKey: .reservedOutputTokens),
            reservedCost: try container.decode(BudgetCost.self, forKey: .reservedCost),
            reservedElapsedMilliseconds: try container.decode(
                Int64.self,
                forKey: .reservedElapsedMilliseconds
            )
        )
    }
}

public enum BudgetApprovalReason: String, Codable, CaseIterable, Hashable, Sendable {
    case inputTokens
    case outputTokens
    case cost
    case elapsedTime
    case pricingUnavailable
    case cumulativeCostUnavailable
}

public enum BudgetBlockReason: String, Codable, CaseIterable, Hashable, Sendable {
    case scopeMismatch
    case costUnitMismatch
    case unsettledReservation
    case arithmeticOverflow
}

public enum BudgetReservationInvalidationReason: String, Codable, Hashable, Sendable {
    case taskChanged
    case budgetVersionChanged
    case policyChanged
    case usageChanged
    case providerRequestChanged
    case estimateChanged
    case preflightNoLongerProceeds
}

public enum BudgetReservationValidationResult: Equatable, Sendable {
    case valid
    case requiresNewPreflight(reasons: Set<BudgetReservationInvalidationReason>)
}

public struct BudgetReservationCandidate: Codable, Equatable, Sendable {
    public let taskID: UUID
    public let budgetVersion: Int64
    public let policyHash: String
    public let usageRevision: Int64
    public let usageHash: String
    public let providerRequestID: UUID
    public let exactRequestHash: String
    public let estimateHash: String

    public var canonicalHash: String {
        var encoder = CanonicalFieldEncoder()
        encoder.append(name: "schema", value: "cangjie.budget-reservation.v1")
        encoder.append(name: "taskID", value: taskID.canonicalString)
        encoder.append(name: "budgetVersion", value: String(budgetVersion))
        encoder.append(name: "policyHash", value: policyHash)
        encoder.append(name: "usageRevision", value: String(usageRevision))
        encoder.append(name: "usageHash", value: usageHash)
        encoder.append(name: "providerRequestID", value: providerRequestID.canonicalString)
        encoder.append(name: "exactRequestHash", value: exactRequestHash)
        encoder.append(name: "estimateHash", value: estimateHash)
        return BudgetCanonical.hash(encoder.bytes)
    }

    public func validate(
        policy: TaskBudgetPolicy,
        usage: BudgetUsageSnapshot,
        nextRequest: NextRequestBudgetEstimate
    ) -> BudgetReservationValidationResult {
        var invalidation: Set<BudgetReservationInvalidationReason> = []
        if taskID != policy.taskID || taskID != usage.taskID || taskID != nextRequest.taskID {
            invalidation.insert(.taskChanged)
        }
        if budgetVersion != policy.version || budgetVersion != usage.budgetVersion {
            invalidation.insert(.budgetVersionChanged)
        } else if policyHash != policy.canonicalHash {
            invalidation.insert(.policyChanged)
        }
        if usageRevision != usage.revision || usageHash != usage.canonicalHash {
            invalidation.insert(.usageChanged)
        }
        if providerRequestID != nextRequest.requestIdentity.requestID
            || exactRequestHash != nextRequest.requestIdentity.exactRequestHash {
            invalidation.insert(.providerRequestChanged)
        }
        if estimateHash != nextRequest.canonicalHash {
            invalidation.insert(.estimateChanged)
        }
        if case .proceed = BudgetGovernance().preflight(
            policy: policy,
            usage: usage,
            nextRequest: nextRequest
        ).outcome {
            // The exact current fields above remain the authorization boundary.
        } else {
            invalidation.insert(.preflightNoLongerProceeds)
        }
        return invalidation.isEmpty
            ? .valid
            : .requiresNewPreflight(reasons: invalidation)
    }

    fileprivate init(
        taskID: UUID,
        budgetVersion: Int64,
        policyHash: String,
        usageRevision: Int64,
        usageHash: String,
        providerRequestID: UUID,
        exactRequestHash: String,
        estimateHash: String
    ) {
        self.taskID = taskID
        self.budgetVersion = budgetVersion
        self.policyHash = policyHash
        self.usageRevision = usageRevision
        self.usageHash = usageHash
        self.providerRequestID = providerRequestID
        self.exactRequestHash = exactRequestHash
        self.estimateHash = estimateHash
    }

    private enum CodingKeys: String, CodingKey {
        case taskID
        case budgetVersion
        case policyHash
        case usageRevision
        case usageHash
        case providerRequestID
        case exactRequestHash
        case estimateHash
        case canonicalHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = BudgetReservationCandidate(
            taskID: try container.decode(UUID.self, forKey: .taskID),
            budgetVersion: try container.decode(Int64.self, forKey: .budgetVersion),
            policyHash: try container.decode(String.self, forKey: .policyHash),
            usageRevision: try container.decode(Int64.self, forKey: .usageRevision),
            usageHash: try container.decode(String.self, forKey: .usageHash),
            providerRequestID: try container.decode(UUID.self, forKey: .providerRequestID),
            exactRequestHash: try container.decode(String.self, forKey: .exactRequestHash),
            estimateHash: try container.decode(String.self, forKey: .estimateHash)
        )
        guard decoded.budgetVersion > 0,
              decoded.usageRevision > 0,
              [
                decoded.policyHash,
                decoded.usageHash,
                decoded.exactRequestHash,
                decoded.estimateHash
              ].allSatisfy(BudgetCanonical.isCanonicalSHA256),
              try container.decode(String.self, forKey: .canonicalHash)
                == decoded.canonicalHash else {
            throw BudgetCanonical.corrupted(decoder, "Invalid budget reservation candidate.")
        }
        self = decoded
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taskID, forKey: .taskID)
        try container.encode(budgetVersion, forKey: .budgetVersion)
        try container.encode(policyHash, forKey: .policyHash)
        try container.encode(usageRevision, forKey: .usageRevision)
        try container.encode(usageHash, forKey: .usageHash)
        try container.encode(providerRequestID, forKey: .providerRequestID)
        try container.encode(exactRequestHash, forKey: .exactRequestHash)
        try container.encode(estimateHash, forKey: .estimateHash)
        try container.encode(canonicalHash, forKey: .canonicalHash)
    }
}

public struct BudgetApprovalRequirement: Equatable, Sendable {
    public let taskID: UUID
    public let budgetVersion: Int64
    public let policyHash: String
    public let usageRevision: Int64
    public let usageHash: String
    public let providerRequestID: UUID
    public let exactRequestHash: String
    public let estimateHash: String
    public let reasons: Set<BudgetApprovalReason>

    fileprivate init(
        policy: TaskBudgetPolicy,
        usage: BudgetUsageSnapshot,
        nextRequest: NextRequestBudgetEstimate,
        reasons: Set<BudgetApprovalReason>
    ) {
        taskID = policy.taskID
        budgetVersion = policy.version
        policyHash = policy.canonicalHash
        usageRevision = usage.revision
        usageHash = usage.canonicalHash
        providerRequestID = nextRequest.requestIdentity.requestID
        exactRequestHash = nextRequest.requestIdentity.exactRequestHash
        estimateHash = nextRequest.canonicalHash
        self.reasons = reasons
    }
}

public struct BudgetPreflightDecision: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        case proceed(reservation: BudgetReservationCandidate)
        case requiresApproval(requirement: BudgetApprovalRequirement)
        case blocked(reasons: Set<BudgetBlockReason>)
    }

    public let outcome: Outcome

    fileprivate init(outcome: Outcome) {
        self.outcome = outcome
    }
}

public struct BudgetGovernance: Sendable {
    public init() {}

    public func preflight(
        policy: TaskBudgetPolicy,
        usage: BudgetUsageSnapshot,
        nextRequest: NextRequestBudgetEstimate
    ) -> BudgetPreflightDecision {
        guard policy.taskID == usage.taskID,
              policy.version == usage.budgetVersion,
              policy.taskID == nextRequest.taskID else {
            return BudgetPreflightDecision(outcome: .blocked(reasons: [.scopeMismatch]))
        }
        guard usage.cumulativeCost.currencyCode == policy.currencyCode,
              usage.cumulativeCost.scale == policy.costScale,
              nextRequest.reservedCost.currencyCode == policy.currencyCode,
              nextRequest.reservedCost.scale == policy.costScale else {
            return BudgetPreflightDecision(outcome: .blocked(reasons: [.costUnitMismatch]))
        }
        guard !usage.hasUnsettledReservation else {
            return BudgetPreflightDecision(
                outcome: .blocked(reasons: [.unsettledReservation])
            )
        }

        let input = usage.cumulativeInputTokens.addingReportingOverflow(
            nextRequest.reservedInputTokens
        )
        let output = usage.cumulativeOutputTokens.addingReportingOverflow(
            nextRequest.reservedOutputTokens
        )
        let elapsed = usage.cumulativeElapsedMilliseconds.addingReportingOverflow(
            nextRequest.reservedElapsedMilliseconds
        )
        guard !input.overflow, !output.overflow, !elapsed.overflow else {
            return BudgetPreflightDecision(outcome: .blocked(reasons: [.arithmeticOverflow]))
        }

        var reasons: Set<BudgetApprovalReason> = []
        if input.partialValue > policy.maximumInputTokens {
            reasons.insert(.inputTokens)
        }
        if output.partialValue > policy.maximumOutputTokens {
            reasons.insert(.outputTokens)
        }
        if elapsed.partialValue > policy.maximumElapsedMilliseconds {
            reasons.insert(.elapsedTime)
        }

        switch (usage.cumulativeCost.knownMicroUnits, nextRequest.reservedCost.knownMicroUnits) {
        case let (.some(current), .some(reserved)):
            let cost = current.addingReportingOverflow(reserved)
            guard !cost.overflow else {
                return BudgetPreflightDecision(
                    outcome: .blocked(reasons: [.arithmeticOverflow])
                )
            }
            if cost.partialValue > policy.maximumCostMicroUnits {
                reasons.insert(.cost)
            }
        case (.none, .some):
            reasons.insert(.cumulativeCostUnavailable)
        case (.some, .none):
            reasons.insert(.pricingUnavailable)
        case (.none, .none):
            reasons.formUnion([.cumulativeCostUnavailable, .pricingUnavailable])
        }

        guard reasons.isEmpty else {
            return BudgetPreflightDecision(
                outcome: .requiresApproval(
                    requirement: BudgetApprovalRequirement(
                        policy: policy,
                        usage: usage,
                        nextRequest: nextRequest,
                        reasons: reasons
                    )
                )
            )
        }
        return BudgetPreflightDecision(
            outcome: .proceed(
                reservation: BudgetReservationCandidate(
                    taskID: policy.taskID,
                    budgetVersion: policy.version,
                    policyHash: policy.canonicalHash,
                    usageRevision: usage.revision,
                    usageHash: usage.canonicalHash,
                    providerRequestID: nextRequest.requestIdentity.requestID,
                    exactRequestHash: nextRequest.requestIdentity.exactRequestHash,
                    estimateHash: nextRequest.canonicalHash
                )
            )
        )
    }

    public func makeApprovalBinding(
        approvalRequestID: UUID,
        decision: BudgetPreflightDecision,
        expiresAtEpochMilliseconds: Int64,
        nowEpochMilliseconds: Int64
    ) throws -> BudgetApprovalBinding {
        guard nowEpochMilliseconds >= 0,
              expiresAtEpochMilliseconds > nowEpochMilliseconds,
              case let .requiresApproval(requirement) = decision.outcome else {
            throw BudgetGovernanceError.invalidApprovalBinding
        }
        return try BudgetApprovalBinding(
            approvalRequestID: approvalRequestID,
            requirement: requirement,
            expiresAtEpochMilliseconds: expiresAtEpochMilliseconds
        )
    }
}

public enum BudgetApprovalInvalidationReason: String, Codable, Hashable, Sendable {
    case approvalRequestIDChanged
    case taskChanged
    case budgetVersionChanged
    case policyChanged
    case usageChanged
    case providerRequestChanged
    case estimateChanged
    case reasonsChanged
    case approvalExpired
    case invalidCurrentTime
    case bindingHashChanged
    case preflightNoLongerRequiresApproval
    case preflightBlocked
}

public enum BudgetApprovalValidationResult: Equatable, Sendable {
    case approved
    case requiresReapproval(reasons: Set<BudgetApprovalInvalidationReason>)
}

public struct BudgetApprovalBinding: Codable, Equatable, Sendable {
    public static let bindingHashAlgorithm = "sha256-v1"

    public let approvalRequestID: UUID
    public let taskID: UUID
    public let budgetVersion: Int64
    public let policyHash: String
    public let usageRevision: Int64
    public let usageHash: String
    public let providerRequestID: UUID
    public let exactRequestHash: String
    public let estimateHash: String
    public let reasons: Set<BudgetApprovalReason>
    public let expiresAtEpochMilliseconds: Int64

    public var bindingHash: String {
        "\(Self.bindingHashAlgorithm):\(BudgetCanonical.hash(canonicalBytes))"
    }

    fileprivate init(
        approvalRequestID: UUID,
        requirement: BudgetApprovalRequirement,
        expiresAtEpochMilliseconds: Int64
    ) throws {
        try self.init(
            approvalRequestID: approvalRequestID,
            taskID: requirement.taskID,
            budgetVersion: requirement.budgetVersion,
            policyHash: requirement.policyHash,
            usageRevision: requirement.usageRevision,
            usageHash: requirement.usageHash,
            providerRequestID: requirement.providerRequestID,
            exactRequestHash: requirement.exactRequestHash,
            estimateHash: requirement.estimateHash,
            reasons: requirement.reasons,
            expiresAtEpochMilliseconds: expiresAtEpochMilliseconds
        )
    }

    private init(
        approvalRequestID: UUID,
        taskID: UUID,
        budgetVersion: Int64,
        policyHash: String,
        usageRevision: Int64,
        usageHash: String,
        providerRequestID: UUID,
        exactRequestHash: String,
        estimateHash: String,
        reasons: Set<BudgetApprovalReason>,
        expiresAtEpochMilliseconds: Int64
    ) throws {
        guard budgetVersion > 0,
              usageRevision > 0,
              expiresAtEpochMilliseconds > 0,
              [policyHash, usageHash, exactRequestHash, estimateHash]
                .allSatisfy(BudgetCanonical.isCanonicalSHA256),
              !reasons.isEmpty else {
            throw BudgetGovernanceError.invalidApprovalBinding
        }
        self.approvalRequestID = approvalRequestID
        self.taskID = taskID
        self.budgetVersion = budgetVersion
        self.policyHash = policyHash
        self.usageRevision = usageRevision
        self.usageHash = usageHash
        self.providerRequestID = providerRequestID
        self.exactRequestHash = exactRequestHash
        self.estimateHash = estimateHash
        self.reasons = reasons
        self.expiresAtEpochMilliseconds = expiresAtEpochMilliseconds
    }

    public func validate(
        approvalRequestID expectedApprovalRequestID: UUID,
        approvedBindingHash: String,
        decision: BudgetPreflightDecision,
        nowEpochMilliseconds: Int64
    ) -> BudgetApprovalValidationResult {
        var invalidation: Set<BudgetApprovalInvalidationReason> = []
        if approvalRequestID != expectedApprovalRequestID {
            invalidation.insert(.approvalRequestIDChanged)
        }
        if bindingHash != approvedBindingHash {
            invalidation.insert(.bindingHashChanged)
        }
        if nowEpochMilliseconds < 0 {
            invalidation.insert(.invalidCurrentTime)
        } else if nowEpochMilliseconds >= expiresAtEpochMilliseconds {
            invalidation.insert(.approvalExpired)
        }

        switch decision.outcome {
        case let .requiresApproval(requirement):
            if taskID != requirement.taskID {
                invalidation.insert(.taskChanged)
            }
            if budgetVersion != requirement.budgetVersion {
                invalidation.insert(.budgetVersionChanged)
            } else if policyHash != requirement.policyHash {
                invalidation.insert(.policyChanged)
            }
            if usageRevision != requirement.usageRevision
                || usageHash != requirement.usageHash {
                invalidation.insert(.usageChanged)
            }
            if providerRequestID != requirement.providerRequestID
                || exactRequestHash != requirement.exactRequestHash {
                invalidation.insert(.providerRequestChanged)
            }
            if estimateHash != requirement.estimateHash {
                invalidation.insert(.estimateChanged)
            }
            if reasons != requirement.reasons {
                invalidation.insert(.reasonsChanged)
            }
        case .proceed:
            invalidation.insert(.preflightNoLongerRequiresApproval)
        case .blocked:
            invalidation.insert(.preflightBlocked)
        }
        return invalidation.isEmpty
            ? .approved
            : .requiresReapproval(reasons: invalidation)
    }

    private var canonicalBytes: [UInt8] {
        var encoder = CanonicalFieldEncoder()
        encoder.append(name: "schema", value: "cangjie.budget-approval-binding.v2")
        encoder.append(
            name: "approvalRequestID",
            value: approvalRequestID.canonicalString
        )
        encoder.append(name: "taskID", value: taskID.canonicalString)
        encoder.append(name: "budgetVersion", value: String(budgetVersion))
        encoder.append(name: "policyHash", value: policyHash)
        encoder.append(name: "usageRevision", value: String(usageRevision))
        encoder.append(name: "usageHash", value: usageHash)
        encoder.append(
            name: "providerRequestID",
            value: providerRequestID.canonicalString
        )
        encoder.append(name: "exactRequestHash", value: exactRequestHash)
        encoder.append(name: "estimateHash", value: estimateHash)
        let sortedReasons = reasons.map(\.rawValue).sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }
        encoder.append(name: "reasonCount", value: String(sortedReasons.count))
        for reason in sortedReasons {
            encoder.append(name: "reason", value: reason)
        }
        encoder.append(
            name: "expiresAtEpochMilliseconds",
            value: String(expiresAtEpochMilliseconds)
        )
        return encoder.bytes
    }

    private enum CodingKeys: String, CodingKey {
        case approvalRequestID
        case taskID
        case budgetVersion
        case policyHash
        case usageRevision
        case usageHash
        case providerRequestID
        case exactRequestHash
        case estimateHash
        case reasons
        case expiresAtEpochMilliseconds
        case bindingHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedReasons = try container.decode(
            [BudgetApprovalReason].self,
            forKey: .reasons
        )
        guard Set(decodedReasons).count == decodedReasons.count else {
            throw BudgetCanonical.corrupted(decoder, "Duplicate budget approval reasons.")
        }
        try self.init(
            approvalRequestID: try container.decode(UUID.self, forKey: .approvalRequestID),
            taskID: try container.decode(UUID.self, forKey: .taskID),
            budgetVersion: try container.decode(Int64.self, forKey: .budgetVersion),
            policyHash: try container.decode(String.self, forKey: .policyHash),
            usageRevision: try container.decode(Int64.self, forKey: .usageRevision),
            usageHash: try container.decode(String.self, forKey: .usageHash),
            providerRequestID: try container.decode(UUID.self, forKey: .providerRequestID),
            exactRequestHash: try container.decode(String.self, forKey: .exactRequestHash),
            estimateHash: try container.decode(String.self, forKey: .estimateHash),
            reasons: Set(decodedReasons),
            expiresAtEpochMilliseconds: try container.decode(
                Int64.self,
                forKey: .expiresAtEpochMilliseconds
            )
        )
        let encodedHash = try container.decode(String.self, forKey: .bindingHash)
        guard encodedHash == bindingHash else {
            throw BudgetCanonical.corrupted(
                decoder,
                "Budget approval binding hash does not match canonical fields."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(approvalRequestID, forKey: .approvalRequestID)
        try container.encode(taskID, forKey: .taskID)
        try container.encode(budgetVersion, forKey: .budgetVersion)
        try container.encode(policyHash, forKey: .policyHash)
        try container.encode(usageRevision, forKey: .usageRevision)
        try container.encode(usageHash, forKey: .usageHash)
        try container.encode(providerRequestID, forKey: .providerRequestID)
        try container.encode(exactRequestHash, forKey: .exactRequestHash)
        try container.encode(estimateHash, forKey: .estimateHash)
        let sortedReasons = reasons.sorted {
            $0.rawValue.utf8.lexicographicallyPrecedes($1.rawValue.utf8)
        }
        try container.encode(sortedReasons, forKey: .reasons)
        try container.encode(
            expiresAtEpochMilliseconds,
            forKey: .expiresAtEpochMilliseconds
        )
        try container.encode(bindingHash, forKey: .bindingHash)
    }
}

private enum BudgetCanonical {
    static func hash(_ bytes: [UInt8]) -> String {
        CangJieSHA256.digest(bytes).hexadecimalString
    }

    static func isCanonicalSHA256(_ value: String) -> Bool {
        value.utf8.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x30...0x39, 0x61...0x66:
                return true
            default:
                return false
            }
        }
    }

    static func validCanonicalText(
        _ value: String,
        maximumUTF8Bytes: Int
    ) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value == trimmed
            && !value.isEmpty
            && value.utf8.count <= maximumUTF8Bytes
            && !containsUnsafeControl(value)
    }

    static func validCurrencyCode(_ value: String) -> Bool {
        value.utf8.count == 3 && value.utf8.allSatisfy { (65...90).contains($0) }
    }

    static func validProviderIdentity(_ identity: ProviderRequestIdentity) -> Bool {
        guard validCanonicalText(identity.idempotencyKey, maximumUTF8Bytes: 512),
              (1...ProviderRequestLifecycle.maximumAttempts).contains(identity.attemptNumber),
              (1...ProviderRequestLifecycle.maximumTurnsPerAttempt).contains(identity.turnSequence),
              ((identity.attemptNumber == 1 && identity.turnSequence == 1)
                == (identity.previousRequestID == nil)),
              validCanonicalText(
                identity.modelID,
                maximumUTF8Bytes: ModelConnection.maximumModelIdentifierUTF8Bytes
              ),
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
              components.fragment == nil,
              identity.baseURL.absoluteString.utf8.count
                <= ModelConnection.maximumBaseURLUTF8Bytes,
              host.utf8.count <= ModelConnection.maximumBaseURLHostUTF8Bytes,
              components.percentEncodedPath.utf8.count
                <= ModelConnection.maximumBaseURLPathUTF8Bytes else {
            return false
        }
        if let port = components.port, !(1...65_535).contains(port) {
            return false
        }
        return true
    }

    static func corrupted(_ decoder: Decoder, _ description: String) -> DecodingError {
        .dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: description
            )
        )
    }

    private static func containsUnsafeControl(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
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
}
