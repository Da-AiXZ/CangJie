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

    func testAgentRunRetryRequiresOriginalDurableIdentity() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Run identity", premise: "P")
            let key = "agent.approval.plan-1"
            let first = AgentRunSnapshot(
                id: UUID(),
                projectID: project.id,
                kind: "approval",
                status: .running,
                idempotencyKey: key,
                currentStage: "openingPlan.approve",
                startedAt: Date(timeIntervalSince1970: 600),
                updatedAt: Date(timeIntervalSince1970: 600)
            )
            let validRetry = AgentRunSnapshot(
                id: first.id,
                projectID: project.id,
                kind: "approval",
                status: .completed,
                idempotencyKey: key,
                currentStage: "openingPlan.approved",
                startedAt: first.startedAt,
                updatedAt: Date(timeIntervalSince1970: 602)
            )
            let differentRun = AgentRunSnapshot(
                id: UUID(),
                projectID: project.id,
                kind: "approval",
                status: .completed,
                idempotencyKey: key,
                currentStage: "openingPlan.approved",
                startedAt: Date(timeIntervalSince1970: 603),
                updatedAt: Date(timeIntervalSince1970: 603)
            )

            try database.saveAgentRun(first, conversationID: conversation.id)
            try database.saveAgentRun(validRetry, conversationID: conversation.id)
            XCTAssertThrowsError(try database.saveAgentRun(differentRun, conversationID: conversation.id)) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }

            let restored = try database.agentRun(idempotencyKey: key)
            XCTAssertEqual(restored?.id, first.id)
            XCTAssertEqual(restored?.projectID, project.id)
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
            let approvalPolicy = OpeningPlanApprovalExecutionPolicy(
                toolID: "artifact.openingPlan.approve",
                toolVersion: "1",
                parametersHash: ApprovalFingerprint.parametersHash("{}"),
                estimatedCostMinorUnits: 500,
                budgetCeilingMinorUnits: 2_000
            )

            let first = try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: saved.approval.id,
                displayedBindingHash: saved.approval.bindingHash,
                idempotencyKey: key,
                now: Date(timeIntervalSince1970: 1_100),
                currentPolicy: approvalPolicy
            )
            let replay = try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: saved.approval.id,
                displayedBindingHash: saved.approval.bindingHash,
                idempotencyKey: key,
                now: Date(timeIntervalSince1970: 1_200),
                currentPolicy: approvalPolicy
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

    func testOpeningPlanBlankIdempotencyKeysFailClosedBeforeWrites() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Blank approval key", premise: "P")

            XCTAssertThrowsError(try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Body",
                idempotencyKey: " \t "
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
            XCTAssertEqual(try database.countArtifacts(kind: "openingPlan"), 0)
            XCTAssertEqual(try database.countToolReceipts(toolID: "artifact.openingPlan.save"), 0)

            let saved = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Body",
                idempotencyKey: "opening.blank.valid-save"
            )
            XCTAssertThrowsError(try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: saved.approval.id,
                displayedBindingHash: saved.approval.bindingHash,
                idempotencyKey: "\n\t"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
            XCTAssertEqual(try database.approvalRequest(id: saved.approval.id)?.status, .pending)
            XCTAssertEqual(try database.countToolReceipts(toolID: "artifact.openingPlan.approve"), 0)
        }
    }

    func testOpeningPlanReplayRejectsTamperedCanonicalInputSummary() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Tampered replay", premise: "P")
            let saved = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Body",
                idempotencyKey: "opening.tampered.save"
            )
            try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE toolReceipt SET inputSummary = ? WHERE id = ?",
                    arguments: ["tampered", saved.receipt.id.uuidString]
                )
            }
            XCTAssertThrowsError(try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "Body",
                idempotencyKey: "opening.tampered.save"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
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


    func testChapterGenerateUsesCanonicalExactApprovalValidatorIncludingReceiptIdentity() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Canonical approval", premise: "P")
            let openingPlan = try makeApprovedOpeningPlan(
                database: database,
                conversationID: conversation.id,
                projectID: project.id,
                keyPrefix: "chapter.canonical-approval"
            )
            try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE toolReceipt SET inputSummary = ?, idempotencyKey = NULL WHERE id = ?",
                    arguments: ["tampered", openingPlan.approvalReceiptID.uuidString]
                )
            }

            XCTAssertThrowsError(try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.artifact.id,
                openingPlanHash: openingPlan.artifact.contentHash,
                idempotencyKey: "chapter.canonical-approval.generate"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .chapterOpeningPlanNotApproved)
            }
            XCTAssertEqual(try database.countChapterVersions(projectID: project.id, chapterNumber: 1), 0)
        }
    }

    func testChapterDiagnosisRequiresCanonicalThreeQuestionOrderAndFinalScope() throws {
        try withDatabase { database in
            let setup = try makeGeneratedChapter(database: database, keyPrefix: "chapter.diagnosis-protocol")
            _ = try database.executeChapterRejectTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                reason: "The protagonist is passive.",
                idempotencyKey: "chapter.diagnosis-protocol.reject"
            )

            XCTAssertThrowsError(try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "must-preserve",
                question: ChapterDiagnosisProtocol.orderedQuestions[1],
                answer: "The opening image.",
                rewriteScope: nil,
                idempotencyKey: "chapter.diagnosis-protocol.out-of-order"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidChapterDiagnosis)
            }
            XCTAssertThrowsError(try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "root-cause",
                question: ChapterDiagnosisProtocol.orderedQuestions[0],
                answer: "The protagonist only reacts.",
                rewriteScope: "Scope is forbidden before question three.",
                idempotencyKey: "chapter.diagnosis-protocol.early-scope"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidRewriteScope)
            }

            _ = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "root-cause",
                question: ChapterDiagnosisProtocol.orderedQuestions[0],
                answer: "The protagonist only reacts.",
                rewriteScope: nil,
                idempotencyKey: "chapter.diagnosis-protocol.answer.1"
            )
            _ = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "must-preserve",
                question: ChapterDiagnosisProtocol.orderedQuestions[1],
                answer: "The opening image and paragraph one.",
                rewriteScope: nil,
                idempotencyKey: "chapter.diagnosis-protocol.answer.2"
            )
            XCTAssertThrowsError(try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "chapter-end",
                question: ChapterDiagnosisProtocol.orderedQuestions[2],
                answer: "With an active irreversible choice.",
                rewriteScope: nil,
                idempotencyKey: "chapter.diagnosis-protocol.missing-final-scope"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidRewriteScope)
            }
            let completed = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "chapter-end",
                question: ChapterDiagnosisProtocol.orderedQuestions[2],
                answer: "With an active irreversible choice.",
                rewriteScope: "Keep paragraph 1 byte-exact; rewrite paragraph 2 around the choice.",
                idempotencyKey: "chapter.diagnosis-protocol.answer.3"
            )
            XCTAssertEqual(completed.calibration.diagnosisEntries.map(\.questionID), ChapterDiagnosisProtocol.orderedQuestionIDs)
            XCTAssertEqual(completed.calibration.stage, .awaitingRewriteConfirmation)
            XCTAssertNotNil(completed.calibration.rewriteScopeHash)
        }
    }

    func testChapterScopedReadsAndTriggersRejectCrossScopeVersionReferences() throws {
        try withDatabase { database in
            let first = try makeGeneratedChapter(database: database, keyPrefix: "chapter.scope.first")
            let second = try makeGeneratedChapter(database: database, keyPrefix: "chapter.scope.second")

            XCTAssertNotNil(try database.chapterVersion(
                id: first.version.id,
                conversationID: first.conversationID,
                projectID: first.projectID
            ))
            XCTAssertNil(try database.chapterVersion(
                id: first.version.id,
                conversationID: first.conversationID,
                projectID: second.projectID
            ))
            XCTAssertThrowsError(try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE chapterCalibration SET activeVersionID = ? WHERE chapterLogicalID = ?",
                    arguments: [second.version.id.uuidString, first.version.logicalID.uuidString]
                )
            })
        }
    }

    func testChapterInputsEnforceUTF8HardLimitsBeforeWrites() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Limits", premise: "P")
            let openingPlan = try makeApprovedOpeningPlan(
                database: database,
                conversationID: conversation.id,
                projectID: project.id,
                keyPrefix: "chapter.limits.plan"
            )
            XCTAssertThrowsError(try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: String(repeating: "?", count: ChapterInputLimits.titleUTF8Bytes),
                body: "Body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.artifact.id,
                openingPlanHash: openingPlan.artifact.contentHash,
                idempotencyKey: "chapter.limits.generate"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .chapterInputLimitExceeded(field: "title"))
            }
            XCTAssertEqual(try database.countChapterVersions(projectID: project.id, chapterNumber: 1), 0)

            let generated = try makeGeneratedChapter(database: database, keyPrefix: "chapter.limits.generated")
            XCTAssertThrowsError(try database.executeChapterLockParagraphSetTool(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                versionID: generated.version.id,
                displayedContentHash: generated.version.contentHash,
                lockedParagraphIndexes: Array(0...ChapterInputLimits.maximumLockedParagraphIndexes),
                idempotencyKey: "chapter.limits.locked-indexes"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .chapterInputLimitExceeded(field: "lockedParagraphIndexes"))
            }
            XCTAssertThrowsError(try database.executeChapterRejectTool(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                versionID: generated.version.id,
                displayedContentHash: generated.version.contentHash,
                reason: String(repeating: "?", count: ChapterInputLimits.rejectionUTF8Bytes),
                idempotencyKey: "chapter.limits.rejection"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .chapterInputLimitExceeded(field: "rejection"))
            }
        }
    }

    func testLockedParagraphProtectsItsOriginalTrailingSeparatorBytes() throws {
        XCTAssertThrowsError(try ChapterByteExactParagraphs.validateLockedParagraphs(
            originalBody: "LOCKED\r\n\r\nunlocked",
            revisedBody: "LOCKED\n\nunlocked",
            indexes: [0]
        )) { error in
            XCTAssertEqual(error as? AppDatabaseError, .chapterLockedContentChanged(index: 0))
        }
    }

    func testChapterReplayReturnsReceiptBoundHistoricalCalibrationSnapshot() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Replay snapshot", premise: "P")
            let openingPlan = try makeApprovedOpeningPlan(
                database: database,
                conversationID: conversation.id,
                projectID: project.id,
                keyPrefix: "chapter.replay-snapshot.plan"
            )
            let generated = try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "LOCKED\n\nunlocked",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.artifact.id,
                openingPlanHash: openingPlan.artifact.contentHash,
                idempotencyKey: "chapter.replay-snapshot.generate"
            )
            _ = try database.executeChapterLockParagraphSetTool(
                conversationID: conversation.id,
                projectID: project.id,
                versionID: generated.version.id,
                displayedContentHash: generated.version.contentHash,
                lockedParagraphIndexes: [0],
                idempotencyKey: "chapter.replay-snapshot.lock"
            )
            let replay = try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "LOCKED\n\nunlocked",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.artifact.id,
                openingPlanHash: openingPlan.artifact.contentHash,
                idempotencyKey: "chapter.replay-snapshot.generate"
            )
            let live = try XCTUnwrap(try database.chapterCalibration(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1
            ))

            XCTAssertTrue(replay.isReplay)
            XCTAssertEqual(replay.calibration.stage, .reviewingV1)
            XCTAssertEqual(replay.calibration.lockedParagraphIndexes, [])
            XCTAssertEqual(live.lockedParagraphIndexes, [0])
        }
    }

    func testChapterLockedParagraphComparisonIsRawUTF8WithoutTrimOrNewlineNormalization() throws {
        XCTAssertThrowsError(try ChapterByteExactParagraphs.validateLockedParagraphs(
            originalBody: "A\n\nKeep trailing space. \nsecond line\n\nC",
            revisedBody: "A\n\nKeep trailing space.\nsecond line\n\nC",
            indexes: [1]
        )) { error in
            XCTAssertEqual(error as? AppDatabaseError, .chapterLockedContentChanged(index: 1))
        }
        XCTAssertThrowsError(try ChapterByteExactParagraphs.validateLockedParagraphs(
            originalBody: "A\r\n\r\nKeep\r\nline\r\n\r\nC",
            revisedBody: "A\n\nKeep\nline\n\nC",
            indexes: [1]
        )) { error in
            XCTAssertEqual(error as? AppDatabaseError, .chapterLockedContentChanged(index: 1))
        }
    }

    func testChapterGeneratePersistsImmutableV1AndReplaysExactly() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Calibration", premise: "P")
            let openingPlan = try makeApprovedOpeningPlan(
                database: database,
                conversationID: conversation.id,
                projectID: project.id,
                keyPrefix: "chapter.generate.plan"
            )

            let first = try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Kept paragraph.\n\nRewrite me.",
                evidenceReview: "No canon conflicts.",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: openingPlan.contentHash,
                idempotencyKey: "chapter.generate.v1",
                now: Date(timeIntervalSince1970: 10_000)
            )
            let replay = try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Kept paragraph.\n\nRewrite me.",
                evidenceReview: "No canon conflicts.",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: openingPlan.contentHash,
                idempotencyKey: "chapter.generate.v1",
                now: Date(timeIntervalSince1970: 10_100)
            )

            XCTAssertEqual(first.version, replay.version)
            XCTAssertEqual(first.receipt, replay.receipt)
            XCTAssertFalse(first.isReplay)
            XCTAssertTrue(replay.isReplay)
            XCTAssertEqual(first.version.revision, 1)
            XCTAssertEqual(first.version.creationStatus, .calibrationReview)
            XCTAssertEqual(first.calibration.stage.rawValue, "reviewingV1")
            XCTAssertEqual(try database.listChapterVersions(
                chapterLogicalID: first.version.logicalID,
                conversationID: conversation.id,
                projectID: project.id
            ), [first.version])
            XCTAssertThrowsError(try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE chapterVersion SET body = ? WHERE id = ?",
                    arguments: ["mutated", first.version.id.uuidString]
                )
            })
        }
    }

    func testChapterGenerateRequiresExactApprovedOpeningPlanAndRejectsIdempotencyConflict() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Exact plan", premise: "P")
            let openingPlan = try makeApprovedOpeningPlan(
                database: database,
                conversationID: conversation.id,
                projectID: project.id,
                keyPrefix: "chapter.generate.exact-plan"
            )

            XCTAssertThrowsError(try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: "wrong-hash",
                idempotencyKey: "chapter.generate.wrong-plan"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .chapterBindingMismatch)
            }

            _ = try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: openingPlan.contentHash,
                idempotencyKey: "chapter.generate.conflict"
            )
            XCTAssertThrowsError(try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Different body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: openingPlan.contentHash,
                idempotencyKey: "chapter.generate.conflict"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
            XCTAssertEqual(try database.countChapterVersions(projectID: project.id, chapterNumber: 1), 1)
        }
    }

    func testChapterLockRejectAndDiagnosisPersistExactStateAndReceipts() throws {
        try withDatabase { database in
            let setup = try makeGeneratedChapter(database: database, keyPrefix: "chapter.diagnosis")
            let locked = try database.executeChapterLockParagraphSetTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                lockedParagraphIndexes: [0, 0],
                idempotencyKey: "chapter.lock.1"
            )
            XCTAssertEqual(locked.calibration.lockedParagraphIndexes, [0])

            XCTAssertThrowsError(try database.executeChapterLockParagraphSetTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                lockedParagraphIndexes: [9],
                idempotencyKey: "chapter.lock.invalid"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidChapterParagraphIndex(9))
            }

            let rejected = try database.executeChapterRejectTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                reason: "The protagonist feels passive.",
                idempotencyKey: "chapter.reject.1"
            )
            XCTAssertEqual(rejected.calibration.stage.rawValue, "diagnosing")

            _ = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "root-cause",
                question: ChapterDiagnosisProtocol.orderedQuestions[0],
                answer: "The protagonist reacts instead of choosing.",
                rewriteScope: nil,
                idempotencyKey: "chapter.diagnosis.answer.1"
            )
            _ = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "must-preserve",
                question: ChapterDiagnosisProtocol.orderedQuestions[1],
                answer: "The opening image and the locked first paragraph.",
                rewriteScope: nil,
                idempotencyKey: "chapter.diagnosis.answer.2"
            )
            let completed = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "chapter-end",
                question: ChapterDiagnosisProtocol.orderedQuestions[2],
                answer: "Urgent anticipation of an irreversible choice.",
                rewriteScope: "Keep paragraph 1 byte-identical; rewrite paragraph 2 around an active choice.",
                idempotencyKey: "chapter.diagnosis.answer.3"
            )

            XCTAssertEqual(completed.calibration.stage.rawValue, "awaitingRewriteConfirmation")
            XCTAssertEqual(completed.calibration.diagnosisEntries.map(\.questionID), ChapterDiagnosisProtocol.orderedQuestionIDs)
            XCTAssertFalse(completed.calibration.diagnosisHash.isEmpty)
            XCTAssertFalse(try XCTUnwrap(completed.calibration.rewriteScopeHash).isEmpty)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.lockParagraph.set"), 1)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.reject"), 1)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.diagnosis.answer"), 3)
        }
    }

    func testChapterRewriteFailsClosedWhenLockedParagraphChangesThenPreservesV1AndV2() throws {
        try withDatabase { database in
            let setup = try makeGeneratedChapter(database: database, keyPrefix: "chapter.rewrite")
            _ = try database.executeChapterLockParagraphSetTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                lockedParagraphIndexes: [0],
                idempotencyKey: "chapter.rewrite.lock"
            )
            _ = try database.executeChapterRejectTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                reason: "Weak agency",
                idempotencyKey: "chapter.rewrite.reject"
            )
            _ = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "root-cause",
                question: ChapterDiagnosisProtocol.orderedQuestions[0],
                answer: "The protagonist reacts instead of making a consequential choice.",
                rewriteScope: nil,
                idempotencyKey: "chapter.rewrite.diagnosis.1"
            )
            _ = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "must-preserve",
                question: ChapterDiagnosisProtocol.orderedQuestions[1],
                answer: "Preserve paragraph 1 and its opening image byte-for-byte.",
                rewriteScope: nil,
                idempotencyKey: "chapter.rewrite.diagnosis.2"
            )
            let diagnosis = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "chapter-end",
                question: ChapterDiagnosisProtocol.orderedQuestions[2],
                answer: "End on a decisive, irreversible choice.",
                rewriteScope: "Preserve paragraph 1; rewrite paragraph 2.",
                idempotencyKey: "chapter.rewrite.diagnosis.3"
            )
            let rewriteScopeHash = try XCTUnwrap(diagnosis.calibration.rewriteScopeHash)

            XCTAssertThrowsError(try database.executeChapterRewriteTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                sourceVersionID: setup.version.id,
                displayedSourceHash: setup.version.contentHash,
                diagnosisHash: diagnosis.calibration.diagnosisHash,
                rewriteScopeHash: rewriteScopeHash,
                displayedLockedParagraphIndexes: [0],
                title: "Chapter 1",
                body: "Changed kept paragraph.\n\nA decisive new ending.",
                evidenceReview: "Review V2",
                idempotencyKey: "chapter.rewrite.changed-lock"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .chapterLockedContentChanged(index: 0))
            }
            XCTAssertEqual(try database.countChapterVersions(projectID: setup.projectID, chapterNumber: 1), 1)

            let rewritten = try database.executeChapterRewriteTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                sourceVersionID: setup.version.id,
                displayedSourceHash: setup.version.contentHash,
                diagnosisHash: diagnosis.calibration.diagnosisHash,
                rewriteScopeHash: rewriteScopeHash,
                displayedLockedParagraphIndexes: [0],
                title: "Chapter 1",
                body: "Kept paragraph.\n\nA decisive new ending.",
                evidenceReview: "Review V2",
                idempotencyKey: "chapter.rewrite.valid"
            )

            XCTAssertEqual(rewritten.version.revision, 2)
            XCTAssertEqual(rewritten.version.parentVersionID, setup.version.id)
            XCTAssertEqual(rewritten.calibration.stage.rawValue, "reviewingV2")
            XCTAssertEqual(rewritten.calibration.diagnosisEntries.map(\.questionID), ChapterDiagnosisProtocol.orderedQuestionIDs)
            XCTAssertEqual(try database.listChapterVersions(
                chapterLogicalID: setup.version.logicalID,
                conversationID: setup.conversationID,
                projectID: setup.projectID
            ).map(\.id), [setup.version.id, rewritten.version.id])
        }
    }

    func testChapterReviewingV2CannotBeRejectedAgain() throws {
        try withDatabase { database in
            let setup = try makeGeneratedChapter(database: database, keyPrefix: "chapter.v2-reject")
            _ = try database.executeChapterRejectTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                reason: "The protagonist needs a consequential choice.",
                idempotencyKey: "chapter.v2-reject.reject-v1"
            )
            _ = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "root-cause",
                question: ChapterDiagnosisProtocol.orderedQuestions[0],
                answer: "The protagonist only reacts.",
                rewriteScope: nil,
                idempotencyKey: "chapter.v2-reject.diagnosis.1"
            )
            _ = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "must-preserve",
                question: ChapterDiagnosisProtocol.orderedQuestions[1],
                answer: "Preserve the first paragraph.",
                rewriteScope: nil,
                idempotencyKey: "chapter.v2-reject.diagnosis.2"
            )
            let diagnosis = try database.executeChapterDiagnosisAnswerTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: setup.version.id,
                displayedContentHash: setup.version.contentHash,
                questionID: "chapter-end",
                question: ChapterDiagnosisProtocol.orderedQuestions[2],
                answer: "Create anticipation around an irreversible choice.",
                rewriteScope: "Preserve paragraph 1; rewrite paragraph 2 around the choice.",
                idempotencyKey: "chapter.v2-reject.diagnosis.3"
            )
            let rewritten = try database.executeChapterRewriteTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                sourceVersionID: setup.version.id,
                displayedSourceHash: setup.version.contentHash,
                diagnosisHash: diagnosis.calibration.diagnosisHash,
                rewriteScopeHash: try XCTUnwrap(diagnosis.calibration.rewriteScopeHash),
                displayedLockedParagraphIndexes: [],
                title: "Chapter 1",
                body: "Kept paragraph.\n\nThe protagonist makes an irreversible choice.",
                evidenceReview: "Review V2",
                idempotencyKey: "chapter.v2-reject.rewrite"
            )

            XCTAssertThrowsError(try database.executeChapterRejectTool(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                versionID: rewritten.version.id,
                displayedContentHash: rewritten.version.contentHash,
                reason: "Reject V2 again.",
                idempotencyKey: "chapter.v2-reject.reject-v2"
            ))
            let calibration = try XCTUnwrap(try database.chapterCalibration(
                conversationID: setup.conversationID,
                projectID: setup.projectID,
                chapterNumber: 1
            ))
            XCTAssertEqual(calibration.stage, .reviewingV2)
            XCTAssertEqual(calibration.rejectionHistory.count, 1)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.reject"), 1)
        }
    }

    func testChapterBlankIdempotencyKeysFailClosedBeforeWrites() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Blank idempotency", premise: "P")
            let openingPlan = try makeApprovedOpeningPlan(
                database: database,
                conversationID: conversation.id,
                projectID: project.id,
                keyPrefix: "chapter.blank-idempotency.plan"
            )

            XCTAssertThrowsError(try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: openingPlan.contentHash,
                idempotencyKey: " \t "
            ))
            XCTAssertEqual(try database.countChapterVersions(projectID: project.id, chapterNumber: 1), 0)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.generate"), 0)

            let generated = try makeGeneratedChapter(database: database, keyPrefix: "chapter.blank-idempotency.generated")
            XCTAssertThrowsError(try database.executeChapterRejectTool(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                versionID: generated.version.id,
                displayedContentHash: generated.version.contentHash,
                reason: "Needs revision.",
                idempotencyKey: " \t "
            ))
            let calibration = try XCTUnwrap(try database.chapterCalibration(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                chapterNumber: 1
            ))
            XCTAssertEqual(calibration.stage, .reviewingV1)
            XCTAssertTrue(calibration.rejectionHistory.isEmpty)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.reject"), 0)
        }
    }

    func testChapterApprovedFrozenRejectsTamperedAcceptEvidence() throws {
        try withDatabase { database in
            let generated = try makeGeneratedChapter(database: database, keyPrefix: "chapter.forged-evidence")
            let receiptID = UUID()
            try database.queue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO toolReceipt (
                        id, toolID, toolVersion, inputSummary, inputHash, outcome,
                        conversationID, projectID, idempotencyKey, outputReference, createdAt
                    ) VALUES (?, 'chapter.accept', '1', ?, 'forged-input-hash', 'completed', ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        receiptID.uuidString,
                        "tampered-summary",
                        generated.conversationID.uuidString,
                        generated.projectID.uuidString,
                        "chapter.forged-evidence.accept",
                        generated.version.id.uuidString,
                        Date().timeIntervalSince1970
                    ]
                )
                try db.execute(
                    sql: """
                    INSERT INTO chapterToolResultSnapshot (
                        receiptID, toolID, inputHash, conversationID, projectID,
                        chapterLogicalID, chapterNumber, versionID,
                        calibrationJSON, calibrationHash, createdAt
                    ) VALUES (?, 'chapter.accept', 'forged-input-hash', ?, ?, ?, 1, ?, '{}', 'forged-calibration-hash', ?)
                    """,
                    arguments: [
                        receiptID.uuidString,
                        generated.conversationID.uuidString,
                        generated.projectID.uuidString,
                        generated.version.logicalID.uuidString,
                        generated.version.id.uuidString,
                        Date().timeIntervalSince1970
                    ]
                )
            }

            XCTAssertThrowsError(try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE chapterCalibration SET stage = 'approvedFrozen', acceptedVersionID = activeVersionID WHERE chapterLogicalID = ?",
                    arguments: [generated.version.logicalID.uuidString]
                )
            })
            let calibration = try XCTUnwrap(try database.chapterCalibration(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                chapterNumber: 1
            ))
            XCTAssertEqual(calibration.stage, .reviewingV1)
        }
    }

    func testChapterApprovedFrozenRejectsBlankAcceptIdempotencyKey() throws {
        try withDatabase { database in
            let generated = try makeGeneratedChapter(database: database, keyPrefix: "chapter.blank-accept-evidence")
            let receiptID = UUID()
            let canonicalSummary = "chapter:\(generated.version.id.uuidString):accept"
            try database.queue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO toolReceipt (
                        id, toolID, toolVersion, inputSummary, inputHash, outcome,
                        conversationID, projectID, idempotencyKey, outputReference, createdAt
                    ) VALUES (?, 'chapter.accept', '1', ?, 'forged-input-hash', 'completed', ?, ?, '   ', ?, ?)
                    """,
                    arguments: [
                        receiptID.uuidString,
                        canonicalSummary,
                        generated.conversationID.uuidString,
                        generated.projectID.uuidString,
                        generated.version.id.uuidString,
                        Date().timeIntervalSince1970
                    ]
                )
                try db.execute(
                    sql: """
                    INSERT INTO chapterToolResultSnapshot (
                        receiptID, toolID, inputHash, conversationID, projectID,
                        chapterLogicalID, chapterNumber, versionID,
                        calibrationJSON, calibrationHash, createdAt
                    ) VALUES (?, 'chapter.accept', 'forged-input-hash', ?, ?, ?, 1, ?, '{}', 'forged-calibration-hash', ?)
                    """,
                    arguments: [
                        receiptID.uuidString,
                        generated.conversationID.uuidString,
                        generated.projectID.uuidString,
                        generated.version.logicalID.uuidString,
                        generated.version.id.uuidString,
                        Date().timeIntervalSince1970
                    ]
                )
            }

            XCTAssertThrowsError(try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE chapterCalibration SET stage = 'approvedFrozen', acceptedVersionID = activeVersionID WHERE chapterLogicalID = ?",
                    arguments: [generated.version.logicalID.uuidString]
                )
            })
        }
    }

    func testChapterApprovedFrozenCannotBeInsertedDirectly() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Direct frozen insert", premise: "P")
            let versionID = UUID()
            try database.queue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO chapterVersion (
                        id, logicalID, conversationID, projectID, chapterNumber, revision,
                        parentVersionID, title, body, contentHash, creationStatus,
                        evidenceReview, diffSummary, createdAt
                    ) VALUES (?, ?, ?, ?, 1, 1, NULL, 'Chapter 1', 'Body', 'hash', 'calibrationReview', 'Review', NULL, ?)
                    """,
                    arguments: [
                        versionID.uuidString,
                        versionID.uuidString,
                        conversation.id.uuidString,
                        project.id.uuidString,
                        Date().timeIntervalSince1970
                    ]
                )
            }

            XCTAssertThrowsError(try database.queue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO chapterCalibration (
                        chapterLogicalID, conversationID, projectID, chapterNumber,
                        activeVersionID, stage, diagnosisEntriesJSON, diagnosisHash,
                        rejectionHistoryJSON, lockedParagraphIndexesJSON,
                        rewriteScope, rewriteScopeHash, acceptedVersionID, updatedAt
                    ) VALUES (?, ?, ?, 1, ?, 'approvedFrozen', '[]', 'hash', '[]', '[]', NULL, NULL, ?, ?)
                    """,
                    arguments: [
                        versionID.uuidString,
                        conversation.id.uuidString,
                        project.id.uuidString,
                        versionID.uuidString,
                        versionID.uuidString,
                        Date().timeIntervalSince1970
                    ]
                )
            })
            XCTAssertNil(try database.chapterCalibration(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1
            ))
        }
    }

    func testChapterAcceptRollsBackReceiptAndSnapshotWhenFreezeUpdateFails() throws {
        try withDatabase { database in
            let generated = try makeGeneratedChapter(database: database, keyPrefix: "chapter.accept-rollback")
            try database.queue.write { db in
                try db.execute(sql: """
                    CREATE TRIGGER test_reject_chapter_freeze
                    BEFORE UPDATE ON chapterCalibration
                    WHEN NEW.stage = 'approvedFrozen'
                    BEGIN
                        SELECT RAISE(ABORT, 'test freeze rejection');
                    END
                    """)
            }

            XCTAssertThrowsError(try database.executeChapterAcceptTool(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                versionID: generated.version.id,
                displayedContentHash: generated.version.contentHash,
                idempotencyKey: "chapter.accept-rollback.accept"
            ))
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.accept"), 0)
            let snapshotCount = try database.queue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM chapterToolResultSnapshot WHERE toolID = 'chapter.accept'") ?? -1
            }
            XCTAssertEqual(snapshotCount, 0)
        }
    }

    func testChapterApprovedFrozenRejectsForgedApprovalAndFurtherMutation() throws {
        try withDatabase { database in
            let generated = try makeGeneratedChapter(database: database, keyPrefix: "chapter.approved-frozen")

            XCTAssertThrowsError(try database.queue.write { db in
                try db.execute(
                    sql: """
                    UPDATE chapterCalibration
                    SET stage = 'approvedFrozen', acceptedVersionID = activeVersionID
                    WHERE chapterLogicalID = ?
                    """,
                    arguments: [generated.version.logicalID.uuidString]
                )
            })
            let reviewing = try XCTUnwrap(try database.chapterCalibration(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                chapterNumber: 1
            ))
            XCTAssertEqual(reviewing.stage, .reviewingV1)
            XCTAssertNil(reviewing.acceptedVersionID)

            let accepted = try database.executeChapterAcceptTool(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                versionID: generated.version.id,
                displayedContentHash: generated.version.contentHash,
                idempotencyKey: "chapter.approved-frozen.accept"
            )
            XCTAssertEqual(accepted.calibration.stage, .approvedFrozen)
            XCTAssertEqual(accepted.calibration.acceptedVersionID, generated.version.id)

            XCTAssertThrowsError(try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE chapterCalibration SET updatedAt = updatedAt + 1 WHERE chapterLogicalID = ?",
                    arguments: [generated.version.logicalID.uuidString]
                )
            })
            let frozen = try XCTUnwrap(try database.chapterCalibration(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                chapterNumber: 1
            ))
            XCTAssertTrue(frozen.isAuditEquivalent(to: accepted.calibration))
        }
    }

    func testChapterAcceptBindsExactDisplayedVersionAndSurvivesReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("test.sqlite").path
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }

        var scope: (conversationID: UUID, projectID: UUID, versionID: UUID, versionHash: String)?
        do {
            let database = try AppDatabase(path: path)
            let generated = try makeGeneratedChapter(database: database, keyPrefix: "chapter.accept")
            scope = (generated.conversationID, generated.projectID, generated.version.id, generated.version.contentHash)

            XCTAssertThrowsError(try database.executeChapterAcceptTool(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                versionID: generated.version.id,
                displayedContentHash: "not-what-user-saw",
                idempotencyKey: "chapter.accept.wrong-hash"
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .chapterBindingMismatch)
            }

            let accepted = try database.executeChapterAcceptTool(
                conversationID: generated.conversationID,
                projectID: generated.projectID,
                versionID: generated.version.id,
                displayedContentHash: generated.version.contentHash,
                idempotencyKey: "chapter.accept.exact"
            )
            XCTAssertEqual(accepted.calibration.stage.rawValue, "approvedFrozen")
            XCTAssertEqual(accepted.calibration.acceptedVersionID, generated.version.id)
            XCTAssertEqual(accepted.receipt.outputReference, generated.version.id.uuidString)
        }

        let restoredScope = try XCTUnwrap(scope)
        let reopened = try AppDatabase(path: path)
        let calibration = try XCTUnwrap(try reopened.chapterCalibration(
            conversationID: restoredScope.conversationID,
            projectID: restoredScope.projectID,
            chapterNumber: 1
        ))
        XCTAssertEqual(calibration.stage.rawValue, "approvedFrozen")
        XCTAssertEqual(calibration.acceptedVersionID, restoredScope.versionID)
        XCTAssertEqual(try reopened.chapterVersion(
            id: restoredScope.versionID,
            conversationID: restoredScope.conversationID,
            projectID: restoredScope.projectID
        )?.contentHash, restoredScope.versionHash)
        XCTAssertEqual(try reopened.countToolReceipts(toolID: "chapter.accept"), 1)
    }

    func testChapterReplayRejectsDifferentOriginRun() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Origin replay", premise: "P")
            let openingPlan = try makeApprovedOpeningPlan(
                database: database,
                conversationID: conversation.id,
                projectID: project.id,
                keyPrefix: "chapter.origin-replay.plan"
            )
            let firstRun = AgentRunSnapshot(
                id: UUID(),
                projectID: project.id,
                kind: "agentTurn",
                status: .running,
                idempotencyKey: "agent.turn.origin-replay.first",
                currentStage: "interpret",
                startedAt: Date(timeIntervalSince1970: 4_000),
                updatedAt: Date(timeIntervalSince1970: 4_000)
            )
            let secondRun = AgentRunSnapshot(
                id: UUID(),
                projectID: project.id,
                kind: "agentTurn",
                status: .running,
                idempotencyKey: "agent.turn.origin-replay.second",
                currentStage: "interpret",
                startedAt: Date(timeIntervalSince1970: 4_001),
                updatedAt: Date(timeIntervalSince1970: 4_001)
            )
            try database.saveAgentRun(firstRun, conversationID: conversation.id)
            try database.saveAgentRun(secondRun, conversationID: conversation.id)

            _ = try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: openingPlan.contentHash,
                idempotencyKey: "chapter.origin-replay.generate",
                originRunID: firstRun.id
            )
            XCTAssertThrowsError(try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: project.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: openingPlan.contentHash,
                idempotencyKey: "chapter.origin-replay.generate",
                originRunID: secondRun.id
            )) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.generate"), 1)
        }
    }

    func testChapterReceiptOriginRunMustExistAndMatchProjectScope() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let firstProject = try database.createProject(title: "First scope", premise: "P1")
            let secondProject = try database.createProject(title: "Second scope", premise: "P2")
            let openingPlan = try makeApprovedOpeningPlan(
                database: database,
                conversationID: conversation.id,
                projectID: secondProject.id,
                keyPrefix: "chapter.origin-scope.plan"
            )
            let wrongProjectRun = AgentRunSnapshot(
                id: UUID(),
                projectID: firstProject.id,
                kind: "agentTurn",
                status: .running,
                idempotencyKey: "agent.turn.origin-scope.wrong-project",
                currentStage: "interpret",
                startedAt: Date(timeIntervalSince1970: 4_100),
                updatedAt: Date(timeIntervalSince1970: 4_100)
            )
            try database.saveAgentRun(wrongProjectRun, conversationID: conversation.id)

            XCTAssertThrowsError(try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: secondProject.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: openingPlan.contentHash,
                idempotencyKey: "chapter.origin-scope.missing-run",
                originRunID: UUID()
            ))
            XCTAssertThrowsError(try database.executeChapterGenerateTool(
                conversationID: conversation.id,
                projectID: secondProject.id,
                chapterNumber: 1,
                title: "Chapter 1",
                body: "Body",
                evidenceReview: "Review",
                openingPlanArtifactID: openingPlan.id,
                openingPlanHash: openingPlan.contentHash,
                idempotencyKey: "chapter.origin-scope.wrong-project",
                originRunID: wrongProjectRun.id
            ))
            XCTAssertEqual(try database.countChapterVersions(projectID: secondProject.id, chapterNumber: 1), 0)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.generate"), 0)
        }
    }

    private struct ApprovedOpeningPlanFixture {
        let artifact: AgentArtifact
        let approvalID: UUID
        let approvalReceiptID: UUID

        var id: UUID { artifact.id }
        var contentHash: String { artifact.contentHash }
    }

    private func makeApprovedOpeningPlan(
        database: AppDatabase,
        conversationID: UUID,
        projectID: UUID,
        keyPrefix: String
    ) throws -> ApprovedOpeningPlanFixture {
        let saved = try database.executeOpeningPlanSaveTool(
            conversationID: conversationID,
            projectID: projectID,
            title: "Opening plan",
            body: "Approved opening plan",
            idempotencyKey: keyPrefix + ".save",
            expiresAt: Date(timeIntervalSinceNow: 3_600)
        )
        let approved = try database.executeOpeningPlanApprovalTool(
            conversationID: conversationID,
            approvalRequestID: saved.approval.id,
            displayedBindingHash: saved.approval.bindingHash,
            idempotencyKey: keyPrefix + ".approve"
        )
        return ApprovedOpeningPlanFixture(
            artifact: approved.artifact,
            approvalID: approved.approval.id,
            approvalReceiptID: approved.receipt.id
        )
    }

    private func makeGeneratedChapter(
        database: AppDatabase,
        keyPrefix: String
    ) throws -> (conversationID: UUID, projectID: UUID, version: ChapterVersion) {
        let conversation = try database.ensureDefaultConversation()
        let project = try database.createProject(title: "Generated", premise: "P")
        let openingPlan = try makeApprovedOpeningPlan(
            database: database,
            conversationID: conversation.id,
            projectID: project.id,
            keyPrefix: keyPrefix + ".plan"
        )
        let generated = try database.executeChapterGenerateTool(
            conversationID: conversation.id,
            projectID: project.id,
            chapterNumber: 1,
            title: "Chapter 1",
            body: "Kept paragraph.\n\nRewrite me.",
            evidenceReview: "Review V1",
            openingPlanArtifactID: openingPlan.id,
            openingPlanHash: openingPlan.contentHash,
            idempotencyKey: keyPrefix + ".generate"
        )
        return (conversation.id, project.id, generated.version)
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
