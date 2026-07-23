import CangJieCore
import Foundation
import GRDB

struct ProviderToolExecutionResult: Equatable {
    let invocation: ProjectToolInvocation
    let receipt: ToolReceipt
    let project: NovelProject?
    let projects: [NovelProject]
    let artifact: AgentArtifact?
    let status: String
}

extension AppDatabase {
    func executeProviderTool(
        _ invocation: ProjectToolInvocation,
        now: Date = Date()
    ) throws -> ProviderToolExecutionResult {
        let canonicalNow = try Self.canonicalProviderToolTimestamp(now)
        return try queue.write { db in
            let request = try Self.validatedProviderRequest(
                for: invocation,
                in: db
            )
            let exactInvocation = try Self.validatedInvocation(
                invocation,
                request: request,
                in: db
            )
            if let replay = try Self.providerToolReceipt(
                invocation: exactInvocation,
                in: db
            ) {
                return try Self.replayedProviderToolResult(
                    invocation: exactInvocation,
                    receipt: replay,
                    in: db
                )
            }

            let result: (
                project: NovelProject?,
                projects: [NovelProject],
                artifact: AgentArtifact?,
                status: String,
                outputReference: String?,
                receiptProjectID: UUID?
            )
            switch exactInvocation.arguments {
            case let .create(title, premise):
                guard exactInvocation.projectID == nil else {
                    throw AppDatabaseError.invalidProviderToolInvocation
                }
                let project = NovelProject(
                    id: UUID(),
                    title: title,
                    premise: premise,
                    createdAt: canonicalNow,
                    updatedAt: canonicalNow
                )
                try db.execute(
                    sql: """
                        INSERT INTO novelProject (
                            id, title, premise, createdAt, updatedAt
                        ) VALUES (?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        project.id.uuidString,
                        project.title,
                        project.premise,
                        canonicalNow.timeIntervalSince1970,
                        canonicalNow.timeIntervalSince1970
                    ]
                )
                result = (
                    project,
                    [project],
                    nil,
                    "created",
                    project.id.uuidString,
                    project.id
                )
            case .list:
                let projects = try Self.projects(in: db)
                let artifact = try Self.insertProviderProjectListSnapshot(
                    projects: projects,
                    conversationID: exactInvocation.conversationID,
                    projectID: exactInvocation.projectID,
                    now: canonicalNow,
                    in: db
                )
                result = (
                    nil,
                    projects,
                    artifact,
                    "listed",
                    artifact.id.uuidString,
                    exactInvocation.projectID
                )
            case .status:
                if let projectID = exactInvocation.projectID {
                    guard let project = try Self.project(
                        id: projectID.uuidString,
                        in: db
                    ) else {
                        throw AppDatabaseError.projectNotFound
                    }
                    result = (
                        project,
                        [project],
                        nil,
                        "available",
                        project.id.uuidString,
                        project.id
                    )
                } else {
                    result = (
                        nil,
                        [],
                        nil,
                        "noCurrentProject",
                        nil,
                        nil
                    )
                }
            case let .switchProject(projectID):
                guard let project = try Self.project(
                    id: projectID.uuidString,
                    in: db
                ) else {
                    throw AppDatabaseError.projectNotFound
                }
                try Self.focusProject(
                    projectID,
                    conversationID: exactInvocation.conversationID,
                    now: canonicalNow,
                    in: db
                )
                result = (
                    project,
                    [project],
                    nil,
                    "switched",
                    project.id.uuidString,
                    project.id
                )
            case let .saveDiscussion(title, body):
                let artifact = try Self.insertProviderDiscussionArtifact(
                    title: title,
                    body: body,
                    conversationID: exactInvocation.conversationID,
                    projectID: exactInvocation.projectID,
                    now: canonicalNow,
                    in: db
                )
                result = (
                    nil,
                    [],
                    artifact,
                    "saved",
                    artifact.id.uuidString,
                    exactInvocation.projectID
                )
            }

            if case .create = exactInvocation.arguments,
               let project = result.project {
                try Self.focusProject(
                    project.id,
                    conversationID: exactInvocation.conversationID,
                    now: canonicalNow,
                    in: db
                )
            }

            let receipt = ToolReceipt(
                id: UUID(),
                toolID: exactInvocation.toolID,
                toolVersion: exactInvocation.toolVersion,
                inputSummary: exactInvocation.toolID,
                inputHash: exactInvocation.inputHash,
                outcome: "completed",
                conversationID: exactInvocation.conversationID,
                projectID: result.receiptProjectID,
                originRunID: exactInvocation.runID,
                idempotencyKey: exactInvocation.idempotencyKey,
                outputReference: result.outputReference,
                providerRequestID: exactInvocation.providerRequestID,
                providerCallID: exactInvocation.providerCallID,
                providerCallIndex: exactInvocation.providerCallIndex,
                createdAt: canonicalNow
            )
            try Self.updateRunAfterProviderTool(
                exactInvocation,
                projectID: result.project?.id ?? exactInvocation.projectID,
                now: canonicalNow,
                in: db
            )
            try Self.insertToolReceipt(receipt, in: db)
            return ProviderToolExecutionResult(
                invocation: exactInvocation,
                receipt: receipt,
                project: result.project,
                projects: result.projects,
                artifact: result.artifact,
                status: result.status
            )
        }
    }

    private static func validatedProviderRequest(
        for invocation: ProjectToolInvocation,
        in db: Database
    ) throws -> ProviderRequestSnapshot {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM providerRequest WHERE id = ?",
            arguments: [invocation.providerRequestID.uuidString]
        ) else {
            throw AppDatabaseError.invalidProviderToolInvocation
        }
        let request = try decodeProviderRequest(row)
        guard request.phase == .responseComplete,
              request.identity.runID == invocation.runID,
              request.identity.conversationID == invocation.conversationID,
              request.identity.projectID == invocation.projectID else {
            throw AppDatabaseError.invalidProviderToolInvocation
        }
        return request
    }

    private static func validatedInvocation(
        _ invocation: ProjectToolInvocation,
        request: ProviderRequestSnapshot,
        in db: Database
    ) throws -> ProjectToolInvocation {
        guard let assetRow = try Row.fetchOne(
            db,
            sql: "SELECT * FROM providerResponseAsset WHERE id = ?",
            arguments: [request.responseAssetID.uuidString]
        ) else {
            throw AppDatabaseError.invalidProviderResponseAsset
        }
        let version: Int = assetRow["payloadVersion"]
        let json: String = assetRow["payloadJSON"]
        let storedHash: String = assetRow["payloadHash"]
        guard version == 1,
              storedHash == payloadHash(json),
              let expectedHash = request.responseHash,
              expectedHash == storedHash else {
            throw AppDatabaseError.invalidProviderResponseAsset
        }
        let response = try decodeProviderResponse(json)
        try response.validate(allowIncompleteToolCalls: false)
        guard response.toolCalls.indices.contains(invocation.providerCallIndex) else {
            throw AppDatabaseError.invalidProviderToolInvocation
        }
        let call = response.toolCalls[invocation.providerCallIndex]
        guard call.index == invocation.providerCallIndex,
              let callID = call.id,
              let functionName = call.name else {
            throw AppDatabaseError.invalidProviderToolInvocation
        }
        let exact: ProjectToolInvocation
        do {
            exact = try ProjectToolInvocation.parse(
                providerFunctionName: functionName,
                argumentsJSON: call.argumentsJSON,
                providerCallID: callID,
                providerCallIndex: call.index,
                providerRequestID: request.identity.requestID,
                runID: request.identity.runID,
                conversationID: request.identity.conversationID,
                projectID: request.identity.projectID
            )
        } catch {
            throw AppDatabaseError.invalidProviderToolInvocation
        }
        guard exact == invocation else {
            throw AppDatabaseError.invalidProviderToolInvocation
        }
        return exact
    }

    private static func providerToolReceipt(
        invocation: ProjectToolInvocation,
        in db: Database
    ) throws -> ToolReceipt? {
        let providerCallRow = try Row.fetchOne(
            db,
            sql: """
                SELECT * FROM toolReceipt
                WHERE providerRequestID = ? AND providerCallIndex = ?
                LIMIT 1
                """,
            arguments: [
                invocation.providerRequestID.uuidString,
                invocation.providerCallIndex
            ]
        )
        let byProviderCall = providerCallRow.flatMap { row in
            decodeToolReceipt(row)
        }
        let byIdempotency = try receipt(
            idempotencyKey: invocation.idempotencyKey,
            in: db
        )
        guard byProviderCall == byIdempotency else {
            throw AppDatabaseError.idempotencyConflict
        }
        guard let receipt = byProviderCall else {
            return nil
        }
        guard receipt.toolID == invocation.toolID,
              receipt.toolVersion == invocation.toolVersion,
              receipt.inputHash == invocation.inputHash,
              receipt.outcome == "completed",
              receipt.conversationID == invocation.conversationID,
              receipt.originRunID == invocation.runID,
              receipt.idempotencyKey == invocation.idempotencyKey,
              receipt.providerRequestID == invocation.providerRequestID,
              receipt.providerCallID == invocation.providerCallID,
              receipt.providerCallIndex == invocation.providerCallIndex else {
            throw AppDatabaseError.idempotencyConflict
        }
        return receipt
    }

    private static func replayedProviderToolResult(
        invocation: ProjectToolInvocation,
        receipt: ToolReceipt,
        in db: Database
    ) throws -> ProviderToolExecutionResult {
        let project: NovelProject?
        let projects: [NovelProject]
        let artifact: AgentArtifact?
        switch invocation.arguments {
        case .create:
            guard let outputReference = receipt.outputReference,
                  let storedProject = try Self.project(
                    id: outputReference,
                    in: db
                  ), receipt.projectID == storedProject.id else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            project = storedProject
            projects = [storedProject]
            artifact = nil
        case .list:
            guard receipt.projectID == invocation.projectID,
                  let outputReference = receipt.outputReference else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            let snapshot = try Self.providerProjectListSnapshot(
                id: outputReference,
                conversationID: invocation.conversationID,
                projectID: invocation.projectID,
                in: db
            )
            project = nil
            projects = snapshot.projects
            artifact = snapshot.artifact
        case .status:
            if let outputReference = receipt.outputReference {
                guard let storedProject = try Self.project(
                    id: outputReference,
                    in: db
                ), receipt.projectID == storedProject.id else {
                    throw AppDatabaseError.invalidToolReceiptReference
                }
                project = storedProject
            } else {
                guard receipt.projectID == nil else {
                    throw AppDatabaseError.invalidToolReceiptReference
                }
                project = nil
            }
            projects = project.map { [$0] } ?? []
            artifact = nil
        case let .switchProject(projectID):
            guard let outputReference = receipt.outputReference,
                  outputReference == projectID.uuidString,
                  receipt.projectID == projectID,
                  let storedProject = try Self.project(
                    id: projectID.uuidString,
                    in: db
                  ) else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            project = storedProject
            projects = [storedProject]
            artifact = nil
        case let .saveDiscussion(title, body):
            guard let outputReference = receipt.outputReference,
                  let storedArtifact = try Self.artifact(
                    id: outputReference,
                    in: db
                  ),
                  storedArtifact.kind == "discussion",
                  storedArtifact.title == title,
                  storedArtifact.body == body,
                  storedArtifact.contentHash == ApprovalFingerprint.artifactHash(
                    conversationID: invocation.conversationID,
                    projectID: invocation.projectID,
                    kind: "discussion",
                    title: title,
                    body: body
                  ),
                  storedArtifact.status == "saved",
                  storedArtifact.conversationID == invocation.conversationID,
                  storedArtifact.projectID == invocation.projectID else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            project = nil
            projects = []
            artifact = storedArtifact
        }
        let status: String
        switch invocation.arguments {
        case .create:
            status = "created"
        case .list:
            status = "listed"
        case .status:
            status = project == nil ? "noCurrentProject" : "available"
        case .switchProject:
            status = "switched"
        case .saveDiscussion:
            status = "saved"
        }
        return ProviderToolExecutionResult(
            invocation: invocation,
            receipt: receipt,
            project: project,
            projects: projects,
            artifact: artifact,
            status: status
        )
    }

    private static func updateRunAfterProviderTool(
        _ invocation: ProjectToolInvocation,
        projectID: UUID?,
        now: Date,
        in db: Database
    ) throws {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentRun WHERE id = ? AND conversationID = ?",
            arguments: [
                invocation.runID.uuidString,
                invocation.conversationID.uuidString
            ]
        ) else {
            throw AppDatabaseError.invalidAgentRun
        }
        let run = try decodeAgentRun(row)
        guard run.kind == "providerTurn", run.status == .running else {
            throw AppDatabaseError.invalidAgentRun
        }
        switch invocation.arguments {
        case .create:
            guard run.projectID == nil, projectID != nil else {
                throw AppDatabaseError.invalidAgentRun
            }
        case .list, .status, .saveDiscussion:
            guard run.projectID == projectID else {
                throw AppDatabaseError.invalidAgentRun
            }
        case let .switchProject(targetID):
            guard run.projectID == invocation.projectID,
                  projectID == targetID else {
                throw AppDatabaseError.invalidAgentRun
            }
        }
        try db.execute(
            sql: """
                UPDATE agentRun
                SET projectID = ?, currentStage = ?, updatedAt = ?
                WHERE id = ?
                  AND conversationID = ?
                  AND projectID IS ?
                  AND kind = 'providerTurn'
                  AND status = 'running'
                """,
            arguments: [
                projectID?.uuidString,
                "provider.toolExecuted",
                now.timeIntervalSince1970,
                run.id.uuidString,
                invocation.conversationID.uuidString,
                run.projectID?.uuidString
            ]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.idempotencyConflict
        }
    }

    private static func focusProject(
        _ projectID: UUID,
        conversationID: UUID,
        now: Date,
        in db: Database
    ) throws {
        if let row = try Row.fetchOne(
            db,
            sql: "SELECT interviewStep, currentQuestion, interviewAnswersJSON FROM agentSession WHERE conversationID = ?",
            arguments: [conversationID.uuidString]
        ) {
            let interviewStep: Int = row["interviewStep"]
            let currentQuestion: String = row["currentQuestion"]
            let answersJSON: String = row["interviewAnswersJSON"]
            try db.execute(
                sql: """
                    UPDATE agentSession
                    SET focusedProjectID = ?, interviewStep = ?,
                        currentQuestion = ?, interviewAnswersJSON = ?,
                        updatedAt = ?
                    WHERE conversationID = ?
                    """,
                arguments: [
                    projectID.uuidString,
                    interviewStep,
                    currentQuestion,
                    answersJSON,
                    now.timeIntervalSince1970,
                    conversationID.uuidString
                ]
            )
        } else {
            try db.execute(
                sql: """
                    INSERT INTO agentSession (
                        conversationID, focusedProjectID, interviewStep,
                        currentQuestion, interviewAnswersJSON, updatedAt
                    ) VALUES (?, ?, 0, '', '[]', ?)
                    """,
                arguments: [
                    conversationID.uuidString,
                    projectID.uuidString,
                    now.timeIntervalSince1970
                ]
            )
        }
    }

    private static func projects(in db: Database) throws -> [NovelProject] {
        try Row.fetchAll(
            db,
            sql: "SELECT * FROM novelProject ORDER BY updatedAt DESC, rowid DESC"
        ).map { row in
            guard let id = UUID(uuidString: row["id"]) else {
                throw AppDatabaseError.invalidProviderToolInvocation
            }
            let createdAt = try canonicalProviderToolTimestamp(
                Date(timeIntervalSince1970: row["createdAt"])
            )
            let updatedAt = try canonicalProviderToolTimestamp(
                Date(timeIntervalSince1970: row["updatedAt"])
            )
            return NovelProject(
                id: id,
                title: row["title"],
                premise: row["premise"],
                version: row["version"] ?? 1,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    private static func insertProviderDiscussionArtifact(
        title: String,
        body: String,
        conversationID: UUID,
        projectID: UUID?,
        now: Date,
        in db: Database
    ) throws -> AgentArtifact {
        let contentHash = ApprovalFingerprint.artifactHash(
            conversationID: conversationID,
            projectID: projectID,
            kind: "discussion",
            title: title,
            body: body
        )
        let previousRow: Row?
        if let projectID {
            previousRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM agentArtifact
                    WHERE kind = ? AND conversationID = ? AND projectID = ?
                    ORDER BY updatedAt DESC, rowid DESC LIMIT 1
                    """,
                arguments: [
                    "discussion",
                    conversationID.uuidString,
                    projectID.uuidString
                ]
            )
        } else {
            previousRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM agentArtifact
                    WHERE kind = ? AND conversationID = ? AND projectID IS NULL
                    ORDER BY updatedAt DESC, rowid DESC LIMIT 1
                    """,
                arguments: ["discussion", conversationID.uuidString]
            )
        }
        let previous = previousRow.flatMap(Self.decodeAgentArtifact)
        let artifact = AgentArtifact(
            id: UUID(),
            logicalID: previous?.logicalID,
            revision: (previous?.revision ?? 0) + 1,
            contentHash: contentHash,
            parentArtifactID: previous?.id,
            kind: "discussion",
            title: title,
            body: body,
            status: "saved",
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

    private static func canonicalProviderToolTimestamp(
        _ timestamp: Date
    ) throws -> Date {
        let microseconds = timestamp.timeIntervalSince1970 * 1_000_000
        guard microseconds.isFinite,
              microseconds >= Double(Int64.min),
              microseconds < Double(Int64.max) else {
            throw AppDatabaseError.invalidProviderToolInvocation
        }
        let epochMicroseconds = Int64(microseconds.rounded(.down))
        return Date(
            timeIntervalSince1970: Double(epochMicroseconds) / 1_000_000
        )
    }
}
