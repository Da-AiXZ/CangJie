import GRDB
import XCTest
@testable import CangJie

final class AppDatabaseTests: XCTestCase {
    func testDraftAndCheckpointRoundTripUsesWAL() throws {
        try withDatabase { database in
            XCTAssertEqual(try database.journalMode().lowercased(), "wal")

            let date = Date(timeIntervalSince1970: 1_000)
            let taskID = UUID()
            let checkpoint = try database.checkpointDraft(
                content: "第一章草稿",
                taskID: taskID,
                reason: "manual",
                payloadHash: "abc",
                now: date
            )

            XCTAssertEqual(checkpoint.sequence, 1)
            XCTAssertEqual(
                try database.loadDraft(),
                DraftSnapshot(content: "第一章草稿", updatedAt: date)
            )
            XCTAssertEqual(try database.latestCheckpoint(taskID: taskID), checkpoint)
        }
    }

    func testSamePayloadReusesCheckpointWithoutAdvancingSequence() throws {
        try withDatabase { database in
            let taskID = UUID()
            let first = try database.checkpointDraft(
                content: "未变化草稿",
                taskID: taskID,
                reason: "inactive",
                payloadHash: "same",
                now: Date(timeIntervalSince1970: 1_000)
            )
            let second = try database.checkpointDraft(
                content: "未变化草稿",
                taskID: taskID,
                reason: "background",
                payloadHash: "same",
                now: Date(timeIntervalSince1970: 2_000)
            )

            XCTAssertEqual(second, first)
            XCTAssertEqual(try database.latestCheckpoint(taskID: taskID)?.sequence, 1)
        }
    }

    func testCreateAndListNovelProjectsPersistsNewestFirst() throws {
        try withDatabase { database in
            let first = try database.createProject(title: "First", premise: "A", now: Date(timeIntervalSince1970: 100))
            let second = try database.createProject(title: "Second", premise: "B", now: Date(timeIntervalSince1970: 200))
            let projects = try database.listProjects()

            XCTAssertEqual(projects.map(\.id), [second.id, first.id])
            XCTAssertEqual(projects.map(\.title), ["Second", "First"])
        }
    }


    func testPlanningArtifactRoundTripKeepsApprovalStatus() throws {
        try withDatabase { database in
            let saved = try database.saveArtifact(kind: "openingPlan", title: "Plan", body: "Body", status: "waitingApproval", now: Date(timeIntervalSince1970: 300))
            let restored = try database.latestArtifact(kind: "openingPlan")

            XCTAssertEqual(restored, saved)
        }
    }


    func testToolReceiptRoundTripIsAuditable() throws {
        try withDatabase { database in
            let receipt = try database.recordToolReceipt(toolID: "project.create", inputSummary: "premise", outcome: "completed", now: Date(timeIntervalSince1970: 400))
            XCTAssertEqual(try database.latestToolReceipt(), receipt)
        }
    }


    func testAgentConversationSessionAndRunRoundTrip() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 499))
            let user = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .user,
                content: "A forbidden inheritance",
                now: Date(timeIntervalSince1970: 500)
            )
            let assistant = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .assistant,
                content: "What does the protagonist want?",
                now: Date(timeIntervalSince1970: 501)
            )
            let session = AgentSessionState(
                focusedProjectID: UUID(),
                interviewStep: 1,
                currentQuestion: "What does the protagonist want?",
                interviewAnswers: ["A forbidden inheritance"],
                updatedAt: Date(timeIntervalSince1970: 502)
            )
            try database.saveAgentSession(session, conversationID: conversation.id)
            let run = AgentRunSnapshot(
                id: UUID(),
                kind: "strategicInterview",
                status: .waitingUser,
                idempotencyKey: "agent.turn.test",
                currentStage: "question.2",
                startedAt: Date(timeIntervalSince1970: 503),
                updatedAt: Date(timeIntervalSince1970: 504)
            )
            try database.saveAgentRun(run, conversationID: conversation.id)

            XCTAssertEqual(try database.listAgentMessages(conversationID: conversation.id), [user, assistant])
            XCTAssertEqual(try database.loadAgentSession(conversationID: conversation.id), session)
            XCTAssertEqual(try database.latestAgentRun(conversationID: conversation.id), run)
        }
    }

    func testProjectCreateToolIsIdempotentAndReturnsSameReceipt() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 599))
            let first = try database.executeProjectCreateTool(
                conversationID: conversation.id,
                title: "Untitled Novel",
                premise: "A mortal challenges heaven",
                idempotencyKey: "project.create.message-1",
                now: Date(timeIntervalSince1970: 600)
            )
            let second = try database.executeProjectCreateTool(
                conversationID: conversation.id,
                title: "Untitled Novel",
                premise: "A mortal challenges heaven",
                idempotencyKey: "project.create.message-1",
                now: Date(timeIntervalSince1970: 700)
            )

            XCTAssertEqual(first.project, second.project)
            XCTAssertEqual(first.receipt, second.receipt)
            XCTAssertEqual(try database.listProjects().count, 1)
            XCTAssertEqual(first.receipt.outputReference, first.project.id.uuidString)
        }
    }

    func testAgentRunRetryReusesIdempotencyKeyWithoutUniqueConstraintFailure() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let key = "agent.approval.plan-1"
            let first = AgentRunSnapshot(
                id: UUID(),
                kind: "approval",
                status: .running,
                idempotencyKey: key,
                currentStage: "openingPlan.approve",
                startedAt: Date(timeIntervalSince1970: 600),
                updatedAt: Date(timeIntervalSince1970: 600)
            )
            let retry = AgentRunSnapshot(
                id: UUID(),
                kind: "approval",
                status: .completed,
                idempotencyKey: key,
                currentStage: "openingPlan.approved",
                startedAt: Date(timeIntervalSince1970: 601),
                updatedAt: Date(timeIntervalSince1970: 602)
            )

            try database.saveAgentRun(first, conversationID: conversation.id)
            try database.saveAgentRun(retry, conversationID: conversation.id)

            let restored = try database.agentRun(idempotencyKey: key)
            XCTAssertEqual(restored?.id, first.id)
            XCTAssertEqual(restored?.status, .completed)
            XCTAssertEqual(restored?.currentStage, "openingPlan.approved")
        }
    }

    func testDefaultConversationAdoptsLegacyUnscopedArtifactsAndReceipts() throws {
        try withDatabase { database in
            let artifact = try database.saveArtifact(
                kind: "openingPlan",
                title: "Legacy plan",
                body: "Legacy body",
                status: "waitingApproval"
            )
            let receipt = try database.recordToolReceipt(
                toolID: "artifact.openingPlan.save",
                inputSummary: "legacy",
                outcome: "completed"
            )

            let conversation = try database.ensureDefaultConversation()

            XCTAssertEqual(try database.latestArtifact(kind: "openingPlan", conversationID: conversation.id)?.id, artifact.id)
            XCTAssertEqual(try database.latestToolReceipt(conversationID: conversation.id)?.id, receipt.id)
        }
    }


    func testExactApprovalReplayReturnsSameArtifactAndReceipt() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 1_000))
            let project = try database.createProject(
                title: "Exact approval",
                premise: "A governed opening",
                now: Date(timeIntervalSince1970: 1_001)
            )
            let saved = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Version one",
                idempotencyKey: "opening.save.exact",
                now: Date(timeIntervalSince1970: 1_002),
                expiresAt: Date(timeIntervalSince1970: 2_000),
                estimatedCostMinorUnits: 500,
                budgetCeilingMinorUnits: 2_000
            )
            let key = "opening.approve.exact"

            let first = try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: saved.approval.id,
                displayedBindingHash: saved.approval.bindingHash,
                idempotencyKey: key,
                now: Date(timeIntervalSince1970: 1_100)
            )
            let replay = try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: saved.approval.id,
                displayedBindingHash: saved.approval.bindingHash,
                idempotencyKey: key,
                now: Date(timeIntervalSince1970: 1_200)
            )

            XCTAssertEqual(first.artifact, replay.artifact)
            XCTAssertEqual(first.approval, replay.approval)
            XCTAssertEqual(first.receipt, replay.receipt)
            XCTAssertFalse(first.isReplay)
            XCTAssertTrue(replay.isReplay)
            XCTAssertEqual(try database.countArtifacts(kind: "openingPlan"), 1)
            XCTAssertEqual(try database.countToolReceipts(toolID: "artifact.openingPlan.approve"), 1)
        }
    }

    func testReusingIdempotencyKeyWithDifferentApprovalFingerprintFailsClosed() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Conflict", premise: "P")
            let first = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Revision one",
                idempotencyKey: "opening.save.conflict.1",
                expiresAt: Date(timeIntervalSinceNow: 3_600)
            )
            _ = try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: first.approval.id,
                displayedBindingHash: first.approval.bindingHash,
                idempotencyKey: "opening.approve.conflict"
            )
            let second = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Revision two",
                idempotencyKey: "opening.save.conflict.2",
                expiresAt: Date(timeIntervalSinceNow: 3_600)
            )

            XCTAssertThrowsError(try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: second.approval.id,
                displayedBindingHash: second.approval.bindingHash,
                idempotencyKey: "opening.approve.conflict"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
        }
    }

    func testMaterialPlanChangePersistsApprovalInvalidation() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Revision", premise: "P")
            let timestamp = Date(timeIntervalSince1970: 3_000)
            let first = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Revision one",
                idempotencyKey: "opening.save.revision.1",
                now: timestamp,
                expiresAt: Date(timeIntervalSince1970: 9_000)
            )
            let second = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Revision two",
                idempotencyKey: "opening.save.revision.2",
                now: timestamp,
                expiresAt: Date(timeIntervalSince1970: 9_000)
            )

            XCTAssertEqual(second.artifact.logicalID, first.artifact.logicalID)
            XCTAssertEqual(first.artifact.revision, 1)
            XCTAssertEqual(second.artifact.revision, 2)
            XCTAssertNotEqual(first.artifact.contentHash, second.artifact.contentHash)
            XCTAssertEqual(try database.approvalRequest(id: first.approval.id)?.status, .invalidated)
            XCTAssertEqual(try database.approvalRequest(id: second.approval.id)?.status, .pending)
            XCTAssertEqual(try database.latestArtifact(kind: "openingPlan", conversationID: conversation.id)?.id, second.artifact.id)
        }
    }

    func testSameTimestampRevisionCannotUseStaleApproval() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Ordering", premise: "P")
            let timestamp = Date(timeIntervalSince1970: 4_000)
            let first = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "First",
                idempotencyKey: "opening.save.same-time.1",
                now: timestamp,
                expiresAt: Date(timeIntervalSince1970: 9_000)
            )
            let second = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Second",
                idempotencyKey: "opening.save.same-time.2",
                now: timestamp,
                expiresAt: Date(timeIntervalSince1970: 9_000)
            )

            XCTAssertEqual(second.artifact.revision, first.artifact.revision + 1)
            XCTAssertThrowsError(try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: first.approval.id,
                displayedBindingHash: first.approval.bindingHash,
                idempotencyKey: "opening.approve.stale",
                now: Date(timeIntervalSince1970: 4_100)
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .approvalRequiresReapproval)
            }
        }
    }

    func testApprovalStateSurvivesActualDatabaseCloseAndReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("test.sqlite").path
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }

        var savedApprovalID: UUID?
        var savedBindingHash = ""
        do {
            let database = try AppDatabase(path: path)
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Restart", premise: "P")
            let saved = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Persistent binding",
                idempotencyKey: "opening.save.restart",
                expiresAt: Date(timeIntervalSinceNow: 3_600)
            )
            savedApprovalID = saved.approval.id
            savedBindingHash = saved.approval.bindingHash
        }

        do {
            let database = try AppDatabase(path: path)
            let restored = try XCTUnwrap(try database.approvalRequest(id: XCTUnwrap(savedApprovalID)))
            XCTAssertEqual(restored.bindingHash, savedBindingHash)
            XCTAssertEqual(restored.status, .pending)
        }
    }

    func testApprovalExpiresExactlyAtDatabaseBoundary() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Expiry", premise: "P")
            let expiration = Date(timeIntervalSince1970: 2_000)
            let saved = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Bound until the exact boundary",
                idempotencyKey: "opening.save.expiry-boundary",
                now: Date(timeIntervalSince1970: 1_000),
                expiresAt: expiration
            )

            XCTAssertThrowsError(try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: saved.approval.id,
                displayedBindingHash: saved.approval.bindingHash,
                idempotencyKey: "opening.approve.expiry-boundary",
                now: expiration
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .approvalExpired)
            }
            XCTAssertEqual(try database.approvalRequest(id: saved.approval.id)?.status, .expired)
            XCTAssertEqual(try database.countToolReceipts(toolID: "artifact.openingPlan.approve"), 0)
        }
    }

    func testCheckpointDoesNotModifyAgentBusinessRecords() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Isolation", premise: "P")
            let saved = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Stable business state",
                idempotencyKey: "opening.save.checkpoint-isolation",
                expiresAt: Date(timeIntervalSinceNow: 3_600)
            )
            let run = AgentRunSnapshot(
                id: UUID(),
                kind: "approval",
                status: .waitingUser,
                idempotencyKey: "approval.waiting.checkpoint-isolation",
                currentStage: "openingPlan.approval",
                startedAt: Date(timeIntervalSince1970: 100),
                updatedAt: Date(timeIntervalSince1970: 100)
            )
            try database.saveAgentRun(run, conversationID: conversation.id)
            let artifactBefore = try database.latestArtifact(
                kind: "openingPlan",
                conversationID: conversation.id
            )
            let approvalBefore = try database.approvalRequest(id: saved.approval.id)
            let receiptBefore = try database.latestToolReceipt(conversationID: conversation.id)
            let runBefore = try database.agentRun(idempotencyKey: run.idempotencyKey)

            _ = try database.checkpointDraft(
                content: "unsent text",
                taskID: UUID(),
                reason: "sceneInactive",
                payloadHash: "checkpoint-isolation",
                now: Date(timeIntervalSince1970: 200)
            )

            XCTAssertEqual(
                try database.latestArtifact(kind: "openingPlan", conversationID: conversation.id),
                artifactBefore
            )
            XCTAssertEqual(try database.approvalRequest(id: saved.approval.id), approvalBefore)
            XCTAssertEqual(try database.latestToolReceipt(conversationID: conversation.id), receiptBefore)
            XCTAssertEqual(try database.agentRun(idempotencyKey: run.idempotencyKey), runBefore)
        }
    }

    func testLegacyArtifactToolWritesCompleteExactIdentity() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Legacy writer", premise: "P")

            let first = try database.executeArtifactTool(
                conversationID: conversation.id,
                projectID: project.id,
                toolID: "legacy.openingPlan.save",
                kind: "openingPlan",
                title: "Plan",
                body: "First",
                status: "waitingApproval",
                idempotencyKey: "legacy.exact.1"
            ).artifact
            let second = try database.executeArtifactTool(
                conversationID: conversation.id,
                projectID: project.id,
                toolID: "legacy.openingPlan.save",
                kind: "openingPlan",
                title: "Plan",
                body: "Second",
                status: "waitingApproval",
                idempotencyKey: "legacy.exact.2"
            ).artifact

            XCTAssertEqual(first.revision, 1)
            XCTAssertFalse(first.contentHash.isEmpty)
            XCTAssertEqual(second.logicalID, first.logicalID)
            XCTAssertEqual(second.parentArtifactID, first.id)
            XCTAssertEqual(second.revision, 2)
            XCTAssertFalse(second.contentHash.isEmpty)
        }
    }

    func testDatabaseRejectsIncompleteArtifactIdentity() throws {
        try withDatabase { database in
            XCTAssertThrowsError(try database.queue.write { db in
                try db.execute(
                    sql: "INSERT INTO agentArtifact (id, kind, title, body, status, updatedAt) VALUES (?, ?, ?, ?, ?, ?)",
                    arguments: [UUID().uuidString, "openingPlan", "Invalid", "Missing identity", "waitingApproval", 100.0]
                )
            })
        }
    }

    func testDuplicateApprovalTargetsFailClosedInsteadOfTrapping() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Targets", premise: "P")
            let saved = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Plan",
                body: "Bound targets",
                idempotencyKey: "targets.save"
            )
            let duplicateTargets = """
            [{"type":"novelProject","id":"\(project.id.uuidString)","version":1},
             {"type":"novelProject","id":"\(project.id.uuidString)","version":1}]
            """
            try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE approvalRequest SET targetVersionsJSON = ? WHERE id = ?",
                    arguments: [duplicateTargets, saved.approval.id.uuidString]
                )
            }

            XCTAssertThrowsError(try database.approvalRequest(id: saved.approval.id)) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidApprovalRequest)
            }
        }
    }

    func testPendingApprovalRejectsChangedCurrentToolVersion() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 1_000))
            let project = try database.createProject(title: "Tool version", premise: "P", now: Date(timeIntervalSince1970: 1_001))
            let saved = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Plan",
                body: "Version bound",
                idempotencyKey: "tool-version.save",
                now: Date(timeIntervalSince1970: 1_002),
                expiresAt: Date(timeIntervalSince1970: 2_000)
            )

            XCTAssertThrowsError(try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: saved.approval.id,
                displayedBindingHash: saved.approval.bindingHash,
                idempotencyKey: "tool-version.approve",
                now: Date(timeIntervalSince1970: 1_100),
                currentPolicy: OpeningPlanApprovalExecutionPolicy(
                    toolID: "artifact.openingPlan.approve",
                    toolVersion: "2",
                    parametersHash: ApprovalFingerprint.parametersHash("{}"),
                    estimatedCostMinorUnits: 0,
                    budgetCeilingMinorUnits: 2_000
                )
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .approvalRequiresReapproval)
            }
            XCTAssertEqual(try database.approvalRequest(id: saved.approval.id)?.status, .invalidated)
        }
    }

    func testSameArtifactCanCreateASecondDistinctApprovalRequest() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 1_000))
            let project = try database.createProject(title: "Reapproval", premise: "P", now: Date(timeIntervalSince1970: 1_001))
            let expiration = Date(timeIntervalSince1970: 2_000)
            let first = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Plan",
                body: "Same content",
                idempotencyKey: "reapproval.save.1",
                now: Date(timeIntervalSince1970: 1_002),
                expiresAt: expiration
            )
            let second = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Plan",
                body: "Same content",
                idempotencyKey: "reapproval.save.2",
                now: Date(timeIntervalSince1970: 1_003),
                expiresAt: expiration
            )

            XCTAssertEqual(second.artifact.id, first.artifact.id)
            XCTAssertNotEqual(second.approval.id, first.approval.id)
            XCTAssertNotEqual(second.approval.bindingHash, first.approval.bindingHash)
            XCTAssertEqual(try database.approvalRequest(id: first.approval.id)?.status, .invalidated)
            XCTAssertEqual(second.approval.status, .pending)
        }
    }

    func testPreviousRuntimeSchemaMigratesToExactApprovalAndCanApprove() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }

        let databaseURL = directory.appendingPathComponent("legacy.sqlite")
        let conversationID = UUID()
        let projectID = UUID()
        let artifactID = UUID()
        let legacyReceiptID = UUID()
        try Self.createPreviousRuntimeDatabase(
            at: databaseURL.path,
            conversationID: conversationID,
            projectID: projectID,
            artifactID: artifactID,
            receiptID: legacyReceiptID
        )

        try Self.withOpenDatabase(at: databaseURL.path) { database in
            let migrated = try XCTUnwrap(
                database.latestArtifact(kind: "openingPlan", conversationID: conversationID)
            )
            XCTAssertEqual(migrated.id, artifactID)
            XCTAssertEqual(migrated.logicalID, artifactID)
            XCTAssertEqual(migrated.revision, 1)
            XCTAssertFalse(migrated.contentHash.isEmpty)

            let migratedReceipt = try XCTUnwrap(
                database.latestToolReceipt(conversationID: conversationID)
            )
            XCTAssertEqual(migratedReceipt.id, legacyReceiptID)
            XCTAssertNil(migratedReceipt.toolVersion)
            XCTAssertNil(migratedReceipt.inputHash)

            let state = try XCTUnwrap(database.ensureOpeningPlanApprovalState(
                conversationID: conversationID,
                focusedProjectID: projectID,
                now: Date(timeIntervalSince1970: 1_100)
            ))
            XCTAssertEqual(state.artifact.id, artifactID)
            XCTAssertEqual(state.approval.status, .pending)

            let approved = try database.executeOpeningPlanApprovalTool(
                conversationID: conversationID,
                approvalRequestID: state.approval.id,
                displayedBindingHash: state.approval.bindingHash,
                idempotencyKey: "legacy-schema.approve",
                now: Date(timeIntervalSince1970: 1_200)
            )
            XCTAssertEqual(approved.approval.status, .approved)
            XCTAssertEqual(approved.artifact.id, artifactID)
        }
    }

    func testArtifactToolRejectsReusedIdempotencyKeyForDifferentInput() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Idempotency", premise: "P")
            _ = try database.executeArtifactTool(
                conversationID: conversation.id,
                projectID: project.id,
                toolID: "artifact.note.save",
                kind: "note",
                title: "First",
                body: "Original",
                status: "saved",
                idempotencyKey: "artifact.same-key"
            )

            XCTAssertThrowsError(try database.executeArtifactTool(
                conversationID: conversation.id,
                projectID: project.id,
                toolID: "artifact.note.save",
                kind: "note",
                title: "Second",
                body: "Changed",
                status: "saved",
                idempotencyKey: "artifact.same-key"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
            XCTAssertEqual(try database.countArtifacts(kind: "note"), 1)
        }
    }

    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            XCTAssertNoThrow(try FileManager.default.removeItem(at: directory))
        }
        try Self.withOpenDatabase(
            at: directory.appendingPathComponent("test.sqlite").path,
            body
        )
    }

    private static func createPreviousRuntimeDatabase(
        at path: String,
        conversationID: UUID,
        projectID: UUID,
        artifactID: UUID,
        receiptID: UUID
    ) throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let queue = try DatabaseQueue(path: path, configuration: configuration)
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
            for identifier in [
                "m0-v1",
                "m1-projects",
                "m1-tool-receipts",
                "m1-agent-artifacts",
                "m1-agent-runtime"
            ] {
                try db.execute(
                    sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
                    arguments: [identifier]
                )
            }

            try db.execute(sql: "CREATE TABLE draft (id TEXT PRIMARY KEY, content TEXT NOT NULL, updatedAt DOUBLE NOT NULL)")
            try db.execute(sql: """
                CREATE TABLE checkpoint (
                    id TEXT PRIMARY KEY,
                    taskID TEXT NOT NULL,
                    idempotencyKey TEXT NOT NULL,
                    stage TEXT NOT NULL,
                    sequence INTEGER NOT NULL,
                    payloadHash TEXT NOT NULL,
                    createdAt DOUBLE NOT NULL,
                    UNIQUE(taskID, sequence),
                    UNIQUE(taskID, idempotencyKey)
                )
                """)
            try db.execute(sql: """
                CREATE TABLE novelProject (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    premise TEXT NOT NULL,
                    createdAt DOUBLE NOT NULL,
                    updatedAt DOUBLE NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE toolReceipt (
                    id TEXT PRIMARY KEY,
                    toolID TEXT NOT NULL,
                    inputSummary TEXT NOT NULL,
                    outcome TEXT NOT NULL,
                    createdAt DOUBLE NOT NULL,
                    conversationID TEXT,
                    projectID TEXT,
                    idempotencyKey TEXT,
                    outputReference TEXT
                )
                """)
            try db.execute(sql: "CREATE UNIQUE INDEX toolReceipt_on_idempotencyKey ON toolReceipt(idempotencyKey)")
            try db.execute(sql: """
                CREATE TABLE agentArtifact (
                    id TEXT PRIMARY KEY,
                    kind TEXT NOT NULL,
                    title TEXT NOT NULL,
                    body TEXT NOT NULL,
                    status TEXT NOT NULL,
                    updatedAt DOUBLE NOT NULL,
                    conversationID TEXT,
                    projectID TEXT
                )
                """)
            try db.execute(sql: """
                CREATE TABLE agentConversation (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    createdAt DOUBLE NOT NULL,
                    updatedAt DOUBLE NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE agentMessage (
                    id TEXT PRIMARY KEY,
                    conversationID TEXT NOT NULL REFERENCES agentConversation(id) ON DELETE CASCADE,
                    role TEXT NOT NULL,
                    content TEXT NOT NULL,
                    createdAt DOUBLE NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE agentSession (
                    conversationID TEXT PRIMARY KEY REFERENCES agentConversation(id) ON DELETE CASCADE,
                    focusedProjectID TEXT,
                    interviewStep INTEGER NOT NULL,
                    currentQuestion TEXT NOT NULL,
                    interviewAnswersJSON TEXT NOT NULL,
                    updatedAt DOUBLE NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE agentRun (
                    id TEXT PRIMARY KEY,
                    conversationID TEXT NOT NULL REFERENCES agentConversation(id) ON DELETE CASCADE,
                    kind TEXT NOT NULL,
                    status TEXT NOT NULL,
                    idempotencyKey TEXT NOT NULL UNIQUE,
                    currentStage TEXT NOT NULL,
                    startedAt DOUBLE NOT NULL,
                    updatedAt DOUBLE NOT NULL
                )
                """)

            try db.execute(
                sql: "INSERT INTO agentConversation (id, title, createdAt, updatedAt) VALUES (?, ?, ?, ?)",
                arguments: [conversationID.uuidString, "Legacy conversation", 1_000.0, 1_000.0]
            )
            try db.execute(
                sql: "INSERT INTO novelProject (id, title, premise, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?)",
                arguments: [projectID.uuidString, "Legacy project", "Imported premise", 1_000.0, 1_000.0]
            )
            try db.execute(
                sql: """
                    INSERT INTO toolReceipt (
                        id, toolID, inputSummary, outcome, createdAt, conversationID,
                        projectID, idempotencyKey, outputReference
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    receiptID.uuidString,
                    "artifact.openingPlan.save",
                    "legacy opening plan",
                    "completed",
                    1_000.0,
                    conversationID.uuidString,
                    projectID.uuidString,
                    "legacy-schema.save",
                    artifactID.uuidString
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO agentArtifact (
                        id, kind, title, body, status, updatedAt, conversationID, projectID
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    artifactID.uuidString,
                    "openingPlan",
                    "Legacy opening plan",
                    "A migrated opening plan",
                    "waitingApproval",
                    1_000.0,
                    conversationID.uuidString,
                    projectID.uuidString
                ]
            )
        }
    }

    private static func withOpenDatabase(
        at path: String,
        _ body: (AppDatabase) throws -> Void
    ) throws {
        let database = try AppDatabase(path: path)
        try body(database)
    }

}
