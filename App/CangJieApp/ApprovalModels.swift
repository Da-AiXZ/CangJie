import CryptoKit
import Foundation

enum ApprovalRequestStatus: String, Codable, Equatable {
    case pending
    case approved
    case invalidated
    case expired
}

struct ApprovalTargetVersion: Codable, Equatable {
    let type: String
    let id: UUID
    let version: Int
}

struct ApprovalRequest: Identifiable, Equatable {
    let id: UUID
    let conversationID: UUID
    let projectID: UUID
    let artifactID: UUID
    let artifactLogicalID: UUID
    let artifactRevision: Int
    let artifactHash: String
    let toolID: String
    let toolVersion: String
    let parametersHash: String
    let targetVersions: [ApprovalTargetVersion]
    let targetVersionsHash: String
    let estimatedCostMinorUnits: Int
    let budgetCeilingMinorUnits: Int
    let expiresAtEpochMilliseconds: Int64
    let expectedDiffHash: String
    let bindingHash: String
    let status: ApprovalRequestStatus
    let invalidationReason: String?
    let createdAt: Date
    let updatedAt: Date
    let approvedAt: Date?

    var expiresAt: Date {
        Date(timeIntervalSince1970: Double(expiresAtEpochMilliseconds) / 1_000)
    }
}

struct OpeningPlanApprovalState: Equatable {
    let artifact: AgentArtifact
    let approval: ApprovalRequest
}

struct OpeningPlanSaveToolResult: Equatable {
    let artifact: AgentArtifact
    let approval: ApprovalRequest
    let receipt: ToolReceipt
}

struct OpeningPlanApprovalToolResult: Equatable {
    let artifact: AgentArtifact
    let approval: ApprovalRequest
    let receipt: ToolReceipt
    let isReplay: Bool
}

enum ApprovalFingerprint {
    static func artifactHash(
        conversationID: UUID?,
        projectID: UUID?,
        kind: String,
        title: String,
        body: String
    ) -> String {
        digest(fields: [
            "artifact-v1",
            conversationID?.uuidString ?? "",
            projectID?.uuidString ?? "",
            kind,
            title,
            body
        ])
    }

    static func parametersHash(_ canonicalParameters: String) -> String {
        digest(fields: ["parameters-v1", canonicalParameters])
    }

    static func targetVersionsHash(_ targets: [ApprovalTargetVersion]) -> String {
        let fields = targets
            .sorted { lhs, rhs in
                if lhs.type != rhs.type { return lhs.type < rhs.type }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .flatMap { [$0.type, $0.id.uuidString, String($0.version)] }
        return digest(fields: ["targets-v1"] + fields)
    }

    static func expectedDiffHash(artifactHash: String) -> String {
        digest(fields: ["expected-diff-v1", "approve", artifactHash])
    }

    private static func digest(fields: [String]) -> String {
        var data = Data()
        for field in fields {
            let bytes = Data(field.utf8)
            data.append(Data(String(bytes.count).utf8))
            data.append(0x3A)
            data.append(bytes)
            data.append(0x7C)
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
