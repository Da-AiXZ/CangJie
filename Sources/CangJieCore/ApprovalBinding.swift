import Foundation

public struct ApprovalBinding: Codable, Equatable, Sendable {
    public static let bindingHashAlgorithm = "sha256-v1"

    public let approvalRequestID: UUID
    public let conversationID: UUID
    public let projectID: UUID
    public let artifactLogicalID: UUID
    public let artifactID: UUID
    public let artifactRevision: Int
    public let artifactHash: String
    public let toolID: String
    public let toolVersion: String
    public let parametersHash: String
    public let targetVersions: [String: Int]
    public let estimatedCostMinorUnits: Int
    public let budgetCeilingMinorUnits: Int
    public let expiresAtEpochMilliseconds: Int64
    public let expectedDiffHash: String

    public var expiresAt: Date {
        Date(timeIntervalSince1970: Double(expiresAtEpochMilliseconds) / 1_000)
    }

    public var bindingHash: String {
        let digest = SHA256.digest(canonicalBindingBytes)
        return "\(Self.bindingHashAlgorithm):\(digest.hexadecimalString)"
    }

    public init(
        approvalRequestID: UUID,
        conversationID: UUID,
        projectID: UUID,
        artifactLogicalID: UUID,
        artifactID: UUID,
        artifactRevision: Int,
        artifactHash: String,
        toolID: String,
        toolVersion: String,
        parametersHash: String,
        targetVersions: [String: Int],
        estimatedCostMinorUnits: Int,
        budgetCeilingMinorUnits: Int,
        expiresAtEpochMilliseconds: Int64,
        expectedDiffHash: String
    ) {
        self.approvalRequestID = approvalRequestID
        self.conversationID = conversationID
        self.projectID = projectID
        self.artifactLogicalID = artifactLogicalID
        self.artifactID = artifactID
        self.artifactRevision = artifactRevision
        self.artifactHash = artifactHash
        self.toolID = toolID
        self.toolVersion = toolVersion
        self.parametersHash = parametersHash
        self.targetVersions = targetVersions
        self.estimatedCostMinorUnits = estimatedCostMinorUnits
        self.budgetCeilingMinorUnits = budgetCeilingMinorUnits
        self.expiresAtEpochMilliseconds = expiresAtEpochMilliseconds
        self.expectedDiffHash = expectedDiffHash
    }

    public func validate(
        candidate: ApprovalBinding,
        nowEpochMilliseconds: Int64
    ) -> ApprovalValidationResult {
        var reasons = structuralInvalidationReasons
        reasons.formUnion(candidate.structuralInvalidationReasons)

        if approvalRequestID != candidate.approvalRequestID {
            reasons.insert(.approvalRequestIDChanged)
        }
        if conversationID != candidate.conversationID {
            reasons.insert(.conversationIDChanged)
        }
        if projectID != candidate.projectID {
            reasons.insert(.projectIDChanged)
        }
        if artifactLogicalID != candidate.artifactLogicalID {
            reasons.insert(.artifactLogicalIDChanged)
        }
        if artifactID != candidate.artifactID {
            reasons.insert(.artifactIDChanged)
        }
        if artifactRevision != candidate.artifactRevision {
            reasons.insert(.artifactRevisionChanged)
        }
        if artifactHash != candidate.artifactHash {
            reasons.insert(.artifactHashChanged)
        }
        if toolID != candidate.toolID {
            reasons.insert(.toolIDChanged)
        }
        if toolVersion != candidate.toolVersion {
            reasons.insert(.toolVersionChanged)
        }
        if parametersHash != candidate.parametersHash {
            reasons.insert(.parametersHashChanged)
        }
        if targetVersions != candidate.targetVersions {
            reasons.insert(.targetVersionsChanged)
        }
        if estimatedCostMinorUnits != candidate.estimatedCostMinorUnits {
            reasons.insert(.estimatedCostChanged)
        }
        if budgetCeilingMinorUnits != candidate.budgetCeilingMinorUnits {
            reasons.insert(.budgetCeilingChanged)
        }
        if expiresAtEpochMilliseconds != candidate.expiresAtEpochMilliseconds {
            reasons.insert(.expirationChanged)
        }
        if expectedDiffHash != candidate.expectedDiffHash {
            reasons.insert(.expectedDiffChanged)
        }
        if bindingHash != candidate.bindingHash {
            reasons.insert(.bindingHashChanged)
        }

        if nowEpochMilliseconds >= expiresAtEpochMilliseconds ||
            nowEpochMilliseconds >= candidate.expiresAtEpochMilliseconds {
            reasons.insert(.expired)
        }

        return reasons.isEmpty ? .approved : .requiresReapproval(reasons: reasons)
    }

    public func validate(candidate: ApprovalBinding, now: Date) -> ApprovalValidationResult {
        guard let nowEpochMilliseconds = Self.canonicalEpochMilliseconds(from: now) else {
            var reasons = reasons(from: validate(candidate: candidate, nowEpochMilliseconds: 0))
            reasons.insert(.invalidCurrentTime)
            return .requiresReapproval(reasons: reasons)
        }

        return validate(candidate: candidate, nowEpochMilliseconds: nowEpochMilliseconds)
    }

    public static func canonicalEpochMilliseconds(from date: Date) -> Int64? {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite,
              milliseconds >= Double(Int64.min),
              milliseconds < Double(Int64.max) else {
            return nil
        }

        return Int64(milliseconds.rounded(.down))
    }

    private var structuralInvalidationReasons: Set<ApprovalInvalidationReason> {
        var reasons: Set<ApprovalInvalidationReason> = []

        if artifactRevision <= 0 {
            reasons.insert(.invalidArtifactRevision)
        }
        if artifactHash.isBlank {
            reasons.insert(.emptyArtifactHash)
        }
        if toolID.isBlank {
            reasons.insert(.emptyToolID)
        }
        if toolVersion.isBlank {
            reasons.insert(.emptyToolVersion)
        }
        if parametersHash.isBlank {
            reasons.insert(.emptyParametersHash)
        }
        if expectedDiffHash.isBlank {
            reasons.insert(.emptyExpectedDiffHash)
        }
        if targetVersions.isEmpty {
            reasons.insert(.emptyTargetVersions)
        }
        if targetVersions.keys.contains(where: \.isBlank) {
            reasons.insert(.emptyTargetIdentifier)
        }
        if targetVersions.values.contains(where: { $0 < 0 }) {
            reasons.insert(.invalidTargetVersion)
        }
        if estimatedCostMinorUnits < 0 {
            reasons.insert(.invalidEstimatedCost)
        }
        if budgetCeilingMinorUnits < 0 {
            reasons.insert(.invalidBudgetCeiling)
        }
        if estimatedCostMinorUnits > budgetCeilingMinorUnits {
            reasons.insert(.estimatedCostExceedsBudget)
        }
        if expiresAtEpochMilliseconds <= 0 {
            reasons.insert(.invalidExpiration)
        }

        return reasons
    }

    private var canonicalBindingBytes: [UInt8] {
        var encoder = CanonicalBindingEncoder()
        encoder.append(name: "schema", value: "cangjie.approval-binding.v1")
        encoder.append(name: "approvalRequestID", value: approvalRequestID.canonicalString)
        encoder.append(name: "conversationID", value: conversationID.canonicalString)
        encoder.append(name: "projectID", value: projectID.canonicalString)
        encoder.append(name: "artifactLogicalID", value: artifactLogicalID.canonicalString)
        encoder.append(name: "artifactID", value: artifactID.canonicalString)
        encoder.append(name: "artifactRevision", value: String(artifactRevision))
        encoder.append(name: "artifactHash", value: artifactHash)
        encoder.append(name: "toolID", value: toolID)
        encoder.append(name: "toolVersion", value: toolVersion)
        encoder.append(name: "parametersHash", value: parametersHash)
        encoder.append(name: "targetCount", value: String(targetVersions.count))

        for target in targetVersions.sorted(by: { lhs, rhs in
            lhs.key.utf8.lexicographicallyPrecedes(rhs.key.utf8)
        }) {
            encoder.append(name: "targetKey", value: target.key)
            encoder.append(name: "targetVersion", value: String(target.value))
        }

        encoder.append(name: "estimatedCostMinorUnits", value: String(estimatedCostMinorUnits))
        encoder.append(name: "budgetCeilingMinorUnits", value: String(budgetCeilingMinorUnits))
        encoder.append(
            name: "expiresAtEpochMilliseconds",
            value: String(expiresAtEpochMilliseconds)
        )
        encoder.append(name: "expectedDiffHash", value: expectedDiffHash)
        return encoder.bytes
    }

    private func reasons(from result: ApprovalValidationResult) -> Set<ApprovalInvalidationReason> {
        switch result {
        case .approved:
            return []
        case let .requiresReapproval(reasons):
            return reasons
        }
    }

    private enum CodingKeys: String, CodingKey {
        case approvalRequestID
        case conversationID
        case projectID
        case artifactLogicalID
        case artifactID
        case artifactRevision
        case artifactHash
        case toolID
        case toolVersion
        case parametersHash
        case targetVersions
        case estimatedCostMinorUnits
        case budgetCeilingMinorUnits
        case expiresAtEpochMilliseconds
        case expectedDiffHash
        case bindingHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        approvalRequestID = try container.decode(UUID.self, forKey: .approvalRequestID)
        conversationID = try container.decode(UUID.self, forKey: .conversationID)
        projectID = try container.decode(UUID.self, forKey: .projectID)
        artifactLogicalID = try container.decode(UUID.self, forKey: .artifactLogicalID)
        artifactID = try container.decode(UUID.self, forKey: .artifactID)
        artifactRevision = try container.decode(Int.self, forKey: .artifactRevision)
        artifactHash = try container.decode(String.self, forKey: .artifactHash)
        toolID = try container.decode(String.self, forKey: .toolID)
        toolVersion = try container.decode(String.self, forKey: .toolVersion)
        parametersHash = try container.decode(String.self, forKey: .parametersHash)
        targetVersions = try container.decode([String: Int].self, forKey: .targetVersions)
        estimatedCostMinorUnits = try container.decode(Int.self, forKey: .estimatedCostMinorUnits)
        budgetCeilingMinorUnits = try container.decode(Int.self, forKey: .budgetCeilingMinorUnits)
        expiresAtEpochMilliseconds = try container.decode(
            Int64.self,
            forKey: .expiresAtEpochMilliseconds
        )
        expectedDiffHash = try container.decode(String.self, forKey: .expectedDiffHash)

        let encodedBindingHash = try container.decode(String.self, forKey: .bindingHash)
        guard encodedBindingHash == bindingHash else {
            throw DecodingError.dataCorruptedError(
                forKey: .bindingHash,
                in: container,
                debugDescription: "Approval binding hash does not match its canonical fields."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(approvalRequestID, forKey: .approvalRequestID)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(artifactLogicalID, forKey: .artifactLogicalID)
        try container.encode(artifactID, forKey: .artifactID)
        try container.encode(artifactRevision, forKey: .artifactRevision)
        try container.encode(artifactHash, forKey: .artifactHash)
        try container.encode(toolID, forKey: .toolID)
        try container.encode(toolVersion, forKey: .toolVersion)
        try container.encode(parametersHash, forKey: .parametersHash)
        try container.encode(targetVersions, forKey: .targetVersions)
        try container.encode(estimatedCostMinorUnits, forKey: .estimatedCostMinorUnits)
        try container.encode(budgetCeilingMinorUnits, forKey: .budgetCeilingMinorUnits)
        try container.encode(expiresAtEpochMilliseconds, forKey: .expiresAtEpochMilliseconds)
        try container.encode(expectedDiffHash, forKey: .expectedDiffHash)
        try container.encode(bindingHash, forKey: .bindingHash)
    }
}

public enum ApprovalInvalidationReason: String, Codable, Hashable, Sendable {
    case approvalRequestIDChanged
    case conversationIDChanged
    case projectIDChanged
    case artifactLogicalIDChanged
    case artifactIDChanged
    case artifactRevisionChanged
    case artifactHashChanged
    case toolIDChanged
    case toolVersionChanged
    case parametersHashChanged
    case targetVersionsChanged
    case estimatedCostChanged
    case budgetCeilingChanged
    case expirationChanged
    case expectedDiffChanged
    case bindingHashChanged
    case expired
    case invalidArtifactRevision
    case emptyArtifactHash
    case emptyToolID
    case emptyToolVersion
    case emptyParametersHash
    case emptyExpectedDiffHash
    case emptyTargetVersions
    case emptyTargetIdentifier
    case invalidTargetVersion
    case invalidEstimatedCost
    case invalidBudgetCeiling
    case estimatedCostExceedsBudget
    case invalidExpiration
    case invalidCurrentTime
}

public enum ApprovalValidationResult: Codable, Equatable, Sendable {
    case approved
    case requiresReapproval(reasons: Set<ApprovalInvalidationReason>)
}

private struct CanonicalBindingEncoder {
    private(set) var bytes: [UInt8] = []

    mutating func append(name: String, value: String) {
        appendLengthPrefixed(Array(name.utf8))
        appendLengthPrefixed(Array(value.utf8))
    }

    private mutating func appendLengthPrefixed(_ value: [UInt8]) {
        append(UInt32(value.count))
        bytes.append(contentsOf: value)
    }

    private mutating func append(_ value: UInt32) {
        bytes.append(UInt8((value >> 24) & 0xff))
        bytes.append(UInt8((value >> 16) & 0xff))
        bytes.append(UInt8((value >> 8) & 0xff))
        bytes.append(UInt8(value & 0xff))
    }
}

private enum SHA256 {
    private static let initialHash: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]

    private static let roundConstants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    static func digest(_ input: [UInt8]) -> [UInt8] {
        var message = input
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)

        while message.count % 64 != 56 {
            message.append(0)
        }

        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8((bitLength >> UInt64(shift)) & 0xff))
        }

        var hash = initialHash
        var schedule = [UInt32](repeating: 0, count: 64)

        for chunkStart in stride(from: 0, to: message.count, by: 64) {
            for index in 0..<16 {
                let offset = chunkStart + index * 4
                schedule[index] =
                    UInt32(message[offset]) << 24 |
                    UInt32(message[offset + 1]) << 16 |
                    UInt32(message[offset + 2]) << 8 |
                    UInt32(message[offset + 3])
            }

            for index in 16..<64 {
                let s0 = rotateRight(schedule[index - 15], by: 7) ^
                    rotateRight(schedule[index - 15], by: 18) ^
                    (schedule[index - 15] >> 3)
                let s1 = rotateRight(schedule[index - 2], by: 17) ^
                    rotateRight(schedule[index - 2], by: 19) ^
                    (schedule[index - 2] >> 10)
                schedule[index] = schedule[index - 16] &+ s0 &+ schedule[index - 7] &+ s1
            }

            var a = hash[0]
            var b = hash[1]
            var c = hash[2]
            var d = hash[3]
            var e = hash[4]
            var f = hash[5]
            var g = hash[6]
            var h = hash[7]

            for index in 0..<64 {
                let sum1 = rotateRight(e, by: 6) ^ rotateRight(e, by: 11) ^ rotateRight(e, by: 25)
                let choice = (e & f) ^ ((~e) & g)
                let temporary1 = h &+ sum1 &+ choice &+ roundConstants[index] &+ schedule[index]
                let sum0 = rotateRight(a, by: 2) ^ rotateRight(a, by: 13) ^ rotateRight(a, by: 22)
                let majority = (a & b) ^ (a & c) ^ (b & c)
                let temporary2 = sum0 &+ majority

                h = g
                g = f
                f = e
                e = d &+ temporary1
                d = c
                c = b
                b = a
                a = temporary1 &+ temporary2
            }

            hash[0] = hash[0] &+ a
            hash[1] = hash[1] &+ b
            hash[2] = hash[2] &+ c
            hash[3] = hash[3] &+ d
            hash[4] = hash[4] &+ e
            hash[5] = hash[5] &+ f
            hash[6] = hash[6] &+ g
            hash[7] = hash[7] &+ h
        }

        return hash.flatMap { value in
            [
                UInt8((value >> 24) & 0xff),
                UInt8((value >> 16) & 0xff),
                UInt8((value >> 8) & 0xff),
                UInt8(value & 0xff)
            ]
        }
    }

    private static func rotateRight(_ value: UInt32, by count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }
}

private extension Array where Element == UInt8 {
    var hexadecimalString: String {
        let alphabet = Array("0123456789abcdef".utf8)
        var output = [UInt8]()
        output.reserveCapacity(count * 2)

        for byte in self {
            output.append(alphabet[Int(byte >> 4)])
            output.append(alphabet[Int(byte & 0x0f)])
        }

        return String(decoding: output, as: UTF8.self)
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private extension UUID {
    var canonicalString: String {
        uuidString.lowercased()
    }
}
