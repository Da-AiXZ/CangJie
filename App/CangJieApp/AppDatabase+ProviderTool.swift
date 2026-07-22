import CangJieCore
import Foundation
import GRDB

struct ProviderToolExecutionResult: Equatable {
    let invocation: ProjectToolInvocation
    let receipt: ToolReceipt
    let project: NovelProject?
    let status: String
}

extension AppDatabase {
    func executeProviderTool(
        _ invocation: ProjectToolInvocation,
        now: Date = Date()
    ) throws -> ProviderToolExecutionResult {
        try queue.write { db in
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

            let result: (NovelProject?, String, String?)
            switch exactInvocation.arguments {
            case let .create(title, premise):
                guard exactInvocation.projectID == nil else {
                    throw AppDatabaseError.invalidProviderToolInvocation
                }
                let project = NovelProject(
                    id: UUID(),
                    title: title,
                    premise: premise,
                    createdAt: now,
                    updatedAt: now
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
                        now.timeIntervalSince1970,
                        now.timeIntervalSince1970
                    ]
                )
                result = (project, "created", project.id.uuidString)
            case .status:
                if let projectID = exactInvocation.projectID {
                    guard let project = try Self.project(
                        id: projectID.uuidString,
                        in: db
                    ) else {
                        throw AppDatabaseError.projectNotFound
                    }
                    result = (project, "available", project.id.uuidString)
                } else {
                    result = (nil, "noCurrentProject", nil)
                }
            }

            if case .create = exactInvocation.arguments,
               let project = result.0 {
                try Self.focusProject(
                    project.id,
                    conversationID: exactInvocation.conversationID,
                    now: now,
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
                projectID: result.0?.id ?? exactInvocation.projectID,
                originRunID: exactInvocation.runID,
                idempotencyKey: exactInvocation.idempotencyKey,
                outputReference: result.2,
                providerRequestID: exactInvocation.providerRequestID,
                providerCallID: exactInvocation.providerCallID,
                providerCallIndex: exactInvocation.providerCallIndex,
                createdAt: now
            )
            try Self.updateRunAfterProviderTool(
                exactInvocation,
                projectID: result.0?.id ?? exactInvocation.projectID,
                now: now,
                in: db
            )
            try Self.insertToolReceipt(receipt, in: db)
            return ProviderToolExecutionResult(
                invocation: exactInvocation,
                receipt: receipt,
                project: result.0,
                status: result.1
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
        }
        let status: String
        switch invocation.arguments {
        case .create:
            status = "created"
        case .status:
            status = project == nil ? "noCurrentProject" : "available"
        }
        return ProviderToolExecutionResult(
            invocation: invocation,
            receipt: receipt,
            project: project,
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
        try upsertAgentRun(
            AgentRunSnapshot(
                id: run.id,
                projectID: projectID,
                kind: run.kind,
                status: run.status,
                idempotencyKey: run.idempotencyKey,
                currentStage: "provider.toolExecuted",
                startedAt: run.startedAt,
                updatedAt: now
            ),
            conversationID: invocation.conversationID,
            in: db
        )
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
}
