import CangJieCore
import Foundation
import GRDB

private struct ProviderProjectListSnapshot: Codable, Equatable {
    let projects: [ProviderProjectListEntry]
}

private struct ProviderProjectListEntry: Codable, Equatable {
    let id: UUID
    let title: String
    let premise: String
    let version: Int
    let createdAtMicroseconds: Int64
    let updatedAtMicroseconds: Int64

    var project: NovelProject {
        NovelProject(
            id: id,
            title: title,
            premise: premise,
            version: version,
            createdAt: Date(
                timeIntervalSince1970: Double(createdAtMicroseconds) / 1_000_000
            ),
            updatedAt: Date(
                timeIntervalSince1970: Double(updatedAtMicroseconds) / 1_000_000
            )
        )
    }
}

extension AppDatabase {
    static func insertProviderProjectListSnapshot(
        projects: [NovelProject],
        conversationID: UUID,
        projectID: UUID?,
        now: Date,
        in db: Database
    ) throws -> AgentArtifact {
        let entries = try projects.map { project in
            ProviderProjectListEntry(
                id: project.id,
                title: project.title,
                premise: project.premise,
                version: project.version,
                createdAtMicroseconds: try projectTimestampMicroseconds(
                    project.createdAt
                ),
                updatedAtMicroseconds: try projectTimestampMicroseconds(
                    project.updatedAt
                )
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let bodyData = try encoder.encode(
            ProviderProjectListSnapshot(projects: entries)
        )
        guard let body = String(data: bodyData, encoding: .utf8) else {
            throw AppDatabaseError.invalidProviderToolInvocation
        }
        let contentHash = ApprovalFingerprint.artifactHash(
            conversationID: conversationID,
            projectID: projectID,
            kind: "projectListSnapshot",
            title: "小说清单",
            body: body
        )
        let artifact = AgentArtifact(
            id: UUID(),
            contentHash: contentHash,
            kind: "projectListSnapshot",
            title: "小说清单",
            body: body,
            status: "readSnapshot",
            conversationID: conversationID,
            projectID: projectID,
            updatedAt: now
        )
        try db.execute(
            sql: """
                INSERT INTO agentArtifact (
                    id, logicalID, revision, contentHash, parentArtifactID, kind,
                    title, body, status, conversationID, projectID, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                artifact.id.uuidString,
                artifact.logicalID.uuidString,
                artifact.revision,
                artifact.contentHash,
                artifact.parentArtifactID?.uuidString,
                artifact.kind,
                artifact.title,
                artifact.body,
                artifact.status,
                artifact.conversationID?.uuidString,
                artifact.projectID?.uuidString,
                artifact.updatedAt.timeIntervalSince1970
            ]
        )
        return artifact
    }

    static func providerProjectListSnapshot(
        id: String,
        conversationID: UUID,
        projectID: UUID?,
        in db: Database
    ) throws -> (artifact: AgentArtifact, projects: [NovelProject]) {
        guard let storedArtifact = try artifact(id: id, in: db),
              storedArtifact.kind == "projectListSnapshot",
              storedArtifact.title == "小说清单",
              storedArtifact.status == "readSnapshot",
              storedArtifact.conversationID == conversationID,
              storedArtifact.projectID == projectID,
              storedArtifact.contentHash == ApprovalFingerprint.artifactHash(
                conversationID: conversationID,
                projectID: projectID,
                kind: storedArtifact.kind,
                title: storedArtifact.title,
                body: storedArtifact.body
              ) else {
            throw AppDatabaseError.invalidToolReceiptReference
        }
        return (
            storedArtifact,
            try decodeProviderProjectListSnapshot(storedArtifact.body)
        )
    }

    private static func decodeProviderProjectListSnapshot(
        _ body: String
    ) throws -> [NovelProject] {
        guard let data = body.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(
                ProviderProjectListSnapshot.self,
                from: data
              ),
              Set(snapshot.projects.map(\.id)).count == snapshot.projects.count,
              snapshot.projects.allSatisfy({ $0.version > 0 }) else {
            throw AppDatabaseError.invalidToolReceiptReference
        }
        return snapshot.projects.map(\.project)
    }

    private static func projectTimestampMicroseconds(
        _ timestamp: Date
    ) throws -> Int64 {
        let microseconds = timestamp.timeIntervalSince1970 * 1_000_000
        guard microseconds.isFinite,
              microseconds >= Double(Int64.min),
              microseconds < Double(Int64.max) else {
            throw AppDatabaseError.invalidProviderToolInvocation
        }
        return Int64(microseconds.rounded(.down))
    }
}
