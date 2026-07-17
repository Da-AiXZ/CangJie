import CangJieCore
import Foundation

final class AgentRuntime {
    static let maximumInputUTF8Bytes = 32_768
    static let interviewQuestions = [
        "What is the one-sentence hook that makes this novel impossible to confuse with another?",
        "Who is the protagonist before the first major change, and what do they want right now?",
        "What concrete cost or danger makes the first victory matter?"
    ]

    private let database: AppDatabase
    let conversation: AgentConversation

    init(database: AppDatabase) throws {
        self.database = database
        conversation = try database.ensureDefaultConversation()
    }

    func restore(now: Date = Date()) throws -> AgentRuntimeSnapshot {
        let session = try database.loadAgentSession(conversationID: conversation.id) ?? .empty(now: now)
        let approvalState = try database.ensureOpeningPlanApprovalState(
            conversationID: conversation.id,
            focusedProjectID: session.focusedProjectID,
            now: now
        )
        let exactApprovalReceipt = try reconcileApprovedOpeningPlan(approvalState, now: now)
        var chapter = try session.focusedProjectID.flatMap { projectID in
            try loadChapterSnapshot(projectID: projectID)
        }
        if let focusedProjectID = session.focusedProjectID,
           let currentChapter = chapter,
           let committed = try database.latestValidatedAgentChapterToolResult(
            conversationID: conversation.id,
            projectID: focusedProjectID,
            chapterLogicalID: currentChapter.calibration.chapterLogicalID
           ) {
            _ = try reconcileCommittedChapterTool(committed, now: now)
            chapter = try loadChapterSnapshot(projectID: focusedProjectID)
        }
        let latestReceipt = try database.latestToolReceipt(conversationID: conversation.id)
        let lastReceipt: ToolReceipt?
        if let chapterReceipt = chapter?.lastReceipt {
            lastReceipt = chapterReceipt
        } else if approvalState?.approval.status == .approved {
            lastReceipt = exactApprovalReceipt
        } else {
            lastReceipt = latestReceipt
        }

        return AgentRuntimeSnapshot(
            conversation: conversation,
            messages: try database.listAgentMessages(conversationID: conversation.id),
            projects: try database.listProjects(),
            session: session,
            openingPlan: approvalState?.artifact,
            openingPlanApproval: approvalState?.approval,
            chapter: chapter,
            lastReceipt: lastReceipt,
            latestRun: try database.latestAgentRun(conversationID: conversation.id)
        )
    }

    func handleUserMessage(_ rawText: String, now: Date = Date()) throws -> AgentTurnResult {
        guard rawText.utf8.count < Self.maximumInputUTF8Bytes else {
            throw AppDatabaseError.chapterInputLimitExceeded(field: "agentMessage")
        }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return AgentTurnResult(snapshot: try restore(now: now), status: "Ready") }

        let userMessage = try database.appendAgentMessage(
            conversationID: conversation.id,
            role: .user,
            content: text,
            now: now
        )
        let projects = try database.listProjects()
        let focusedProjectID = try database.focusedProjectID(conversationID: conversation.id)
        let run = AgentRunSnapshot(
            id: UUID(),
            projectID: focusedProjectID ?? projects.first?.id,
            kind: "agentTurn",
            status: .running,
            idempotencyKey: "agent.turn." + userMessage.id.uuidString,
            currentStage: "interpret",
            startedAt: now,
            updatedAt: now
        )
        try database.saveAgentRun(run, conversationID: conversation.id)

        do {
        let storedSession = try database.loadAgentSession(conversationID: conversation.id)
        if projects.isEmpty && Self.isProjectCreationIntent(text) {
            let tool = try database.executeProjectCreateTool(
                conversationID: conversation.id,
                title: "Untitled Novel",
                premise: text,
                idempotencyKey: "project.create." + userMessage.id.uuidString,
                now: now
            )
            try appendAssistant("Project created: " + tool.project.title, now: now)
            try appendAssistant(Self.interviewQuestions[0], now: now)
            try database.saveAgentSession(
                AgentSessionState(
                    focusedProjectID: tool.project.id,
                    interviewStep: 0,
                    currentQuestion: Self.interviewQuestions[0],
                    interviewAnswers: [],
                    updatedAt: now
                ),
                conversationID: conversation.id
            )
            try finish(run: run, status: .waitingUser, stage: "strategicInterview.question.1", now: now)
            return AgentTurnResult(snapshot: try restore(now: now), status: "Verified: project.create")
        }

        guard !projects.isEmpty else {
            try appendAssistant("Tell me the idea or ask me to create a novel, and I will lead the next step.", now: now)
            try finish(run: run, status: .waitingUser, stage: "awaitingProjectIntent", now: now)
            return AgentTurnResult(snapshot: try restore(now: now), status: "Waiting for a novel idea")
        }

        let current = storedSession ?? AgentSessionState(
            focusedProjectID: projects.first?.id,
            interviewStep: 0,
            currentQuestion: Self.interviewQuestions[0],
            interviewAnswers: [],
            updatedAt: now
        )
        if let approvalState = try database.ensureOpeningPlanApprovalState(
            conversationID: conversation.id,
            focusedProjectID: current.focusedProjectID,
            now: now
        ) {
            switch approvalState.approval.status {
            case .pending:
                try appendAssistant(
                    "The opening plan is waiting for your exact approval. Review the bound revision, budget, expiration, and expected change before we continue.",
                    now: now
                )
                try finish(run: run, status: .waitingUser, stage: "openingPlan.approval", now: now)
                return AgentTurnResult(snapshot: try restore(now: now), status: "Waiting for opening plan approval")
            case .approved:
                return try handleApprovedOpeningPlan(
                    text: text,
                    run: run,
                    projects: projects,
                    session: current,
                    approvalState: approvalState,
                    now: now
                )
            case .invalidated, .expired:
                try finish(run: run, status: .waitingUser, stage: "openingPlan.reapprovalRequired", now: now)
                return AgentTurnResult(snapshot: try restore(now: now), status: "Opening plan changed; re-approval required")
            }
        }

        var answers = current.interviewAnswers
        answers.append(text)
        let step = answers.count

        if step < Self.interviewQuestions.count {
            let question = Self.interviewQuestions[step]
            try database.saveAgentSession(
                AgentSessionState(
                    focusedProjectID: current.focusedProjectID ?? projects.first?.id,
                    interviewStep: step,
                    currentQuestion: question,
                    interviewAnswers: answers,
                    updatedAt: now
                ),
                conversationID: conversation.id
            )
            try appendAssistant(question, now: now)
            try finish(run: run, status: .waitingUser, stage: "strategicInterview.question.\(step + 1)", now: now)
            return AgentTurnResult(snapshot: try restore(now: now), status: "Strategic interview in progress")
        }

        guard let projectID = current.focusedProjectID ?? projects.first?.id else {
            try finish(run: run, status: .failed, stage: "openingPlan.missingProject", now: now)
            throw AppDatabaseError.invalidApprovalRequest
        }
        let planBody = Self.makeOpeningPlan(answers: answers)
        _ = try database.executeOpeningPlanSaveTool(
            conversationID: conversation.id,
            projectID: projectID,
            title: "Opening plan",
            body: planBody,
            idempotencyKey: "artifact.openingPlan.save." + userMessage.id.uuidString,
            now: now
        )
        try database.saveAgentSession(
            AgentSessionState(
                focusedProjectID: projectID,
                interviewStep: Self.interviewQuestions.count,
                currentQuestion: "",
                interviewAnswers: Array(answers.prefix(Self.interviewQuestions.count)),
                updatedAt: now
            ),
            conversationID: conversation.id
        )
        try appendAssistant(
            "I have compiled the opening plan. Review its exact approval card before chapter planning.",
            now: now
        )
            try finish(run: run, status: .waitingUser, stage: "openingPlan.approval", now: now)
            return AgentTurnResult(snapshot: try restore(now: now), status: "Waiting for opening plan approval")
        } catch {
            let recoveredResult: ChapterToolResult?
            do {
                recoveredResult = try database.validatedAgentChapterToolResult(
                    originRunID: run.id,
                    conversationID: conversation.id
                )
            } catch {
                recoveredResult = nil
            }
            if let recovered = recoveredResult,
               (try? reconcileCommittedChapterTool(recovered, now: now)) == true {
                return AgentTurnResult(
                    snapshot: try restore(now: now),
                    status: "Recovered committed chapter operation"
                )
            }
            try? finish(run: run, status: .failed, stage: "agentTurn.failed", now: now)
            throw error
        }
    }

    func approveOpeningPlan(
        approvalRequestID: UUID,
        displayedBindingHash: String,
        now: Date = Date()
    ) throws -> AgentTurnResult {
        guard !displayedBindingHash.isEmpty else { throw AppDatabaseError.invalidApprovalRequest }
        let approvalKey = Self.approvalIdempotencyKey(requestID: approvalRequestID, bindingHash: displayedBindingHash)
        let existingRun = try database.agentRun(idempotencyKey: approvalKey)
        let run: AgentRunSnapshot
        if let existingRun {
            run = existingRun
        } else {
            let projectID = try database.loadAgentSession(conversationID: conversation.id)?.focusedProjectID
            run = AgentRunSnapshot(
                id: UUID(), projectID: projectID,
                kind: "approval", status: .running, idempotencyKey: approvalKey,
                currentStage: "openingPlan.approve", startedAt: now, updatedAt: now
            )
        }
        try database.saveAgentRun(
            AgentRunSnapshot(
                id: run.id, projectID: run.projectID,
                kind: run.kind, status: .running, idempotencyKey: run.idempotencyKey,
                currentStage: "openingPlan.approve", startedAt: run.startedAt, updatedAt: now
            ),
            conversationID: conversation.id
        )

        do {
            let result = try database.executeOpeningPlanApprovalTool(
                conversationID: conversation.id,
                approvalRequestID: approvalRequestID,
                displayedBindingHash: displayedBindingHash,
                idempotencyKey: approvalKey,
                now: now
            )
            try Self.validateExactApprovalReceipt(
                result.receipt,
                state: OpeningPlanApprovalState(artifact: result.artifact, approval: result.approval),
                idempotencyKey: approvalKey
            )
            try appendApprovalSuccessMessage(for: result.approval, now: now)
            try finish(run: run, status: .completed, stage: "openingPlan.approved", now: now)
            return AgentTurnResult(
                snapshot: try restore(now: now),
                status: result.isReplay ? "Verified: opening plan approval replayed safely" : "Verified: opening plan approved"
            )
        } catch let error as AppDatabaseError {
            switch error {
            case .approvalRequiresReapproval, .approvalExpired, .approvalBudgetExceeded:
                try? finish(run: run, status: .waitingUser, stage: "openingPlan.reapprovalRequired", now: now)
            default:
                try? finish(run: run, status: .failed, stage: "openingPlan.approvalFailed", now: now)
            }
            throw error
        } catch {
            try? finish(run: run, status: .failed, stage: "openingPlan.approvalFailed", now: now)
            throw error
        }
    }

    private func handleApprovedOpeningPlan(
        text: String,
        run: AgentRunSnapshot,
        projects: [NovelProject],
        session: AgentSessionState,
        approvalState: OpeningPlanApprovalState,
        now: Date
    ) throws -> AgentTurnResult {
        guard let projectID = session.focusedProjectID ?? projects.first?.id,
              let project = projects.first(where: { $0.id == projectID }) else {
            try finish(run: run, status: .failed, stage: "chapter.1.missingProject", now: now)
            throw AppDatabaseError.invalidApprovalRequest
        }

        guard let snapshot = try loadChapterSnapshot(projectID: projectID) else {
            let intent = ChapterAgentTemplates.intent(for: text, stage: .notStarted)
            guard intent == .generate else {
                try appendAssistant(
                    "Chapter planning is unlocked. Say ‘生成第一章’, ‘开始生成第一章’, ‘继续’, or ‘generate chapter’ to begin the governed Chapter 1 calibration.",
                    now: now
                )
                try finish(run: run, status: .waitingUser, stage: "chapter.1.notStarted", now: now)
                return AgentTurnResult(snapshot: try restore(now: now), status: "Opening plan approved; Chapter 1 generation ready")
            }
            return try generateFirstChapter(
                project: project,
                approvalState: approvalState,
                run: run,
                now: now
            )
        }

        let intent = ChapterAgentTemplates.intent(for: text, stage: snapshot.stage)
        if intent == .status {
            try appendAssistant(Self.chapterStatusMessage(snapshot), now: now)
            try finish(run: run, status: .waitingUser, stage: "chapter.1.\(snapshot.stage.rawValue)", now: now)
            return AgentTurnResult(snapshot: try restore(now: now), status: Self.chapterStatusLabel(snapshot.stage))
        }

        switch snapshot.stage {
        case .notStarted:
            guard intent == .generate else {
                try appendAssistant("Chapter 1 is ready to generate when you say ‘生成第一章’ or ‘继续’.", now: now)
                try finish(run: run, status: .waitingUser, stage: "chapter.1.notStarted", now: now)
                return AgentTurnResult(snapshot: try restore(now: now), status: "Chapter 1 generation ready")
            }
            return try generateFirstChapter(project: project, approvalState: approvalState, run: run, now: now)
        case .reviewingV1, .reviewingV2:
            switch intent {
            case .accept:
                return try acceptChapter(snapshot: snapshot, run: run, now: now)
            case .reject:
                return try rejectChapter(snapshot: snapshot, reason: text, run: run, now: now)
            default:
                try appendAssistant(
                    "Review Chapter 1 revision \(snapshot.activeVersion.revision). You may accept and freeze it, or reject it and enter diagnosis. I will not reroll it without a diagnosis.",
                    now: now
                )
                try finish(run: run, status: .waitingUser, stage: "chapter.1.\(snapshot.stage.rawValue)", now: now)
                return AgentTurnResult(snapshot: try restore(now: now), status: Self.chapterStatusLabel(snapshot.stage))
            }
        case .diagnosing:
            return try handleDiagnosis(text: text, snapshot: snapshot, run: run, now: now)
        case .awaitingRewriteConfirmation:
            guard intent == .confirmRewrite else {
                try appendAssistant(
                    "The diagnosis and exact rewrite scope are ready. Confirm that scope before I create revision 2; a generic regenerate request will not bypass this gate.",
                    now: now
                )
                try finish(run: run, status: .waitingUser, stage: "chapter.1.awaitingRewriteConfirmation", now: now)
                return AgentTurnResult(snapshot: try restore(now: now), status: "Waiting for exact rewrite-scope confirmation")
            }
            return try rewriteChapter(snapshot: snapshot, run: run, now: now)
        case .rewriting:
            return try rewriteChapter(snapshot: snapshot, run: run, now: now)
        case .approvedFrozen:
            try appendAssistant(
                "Chapter 1 revision \(snapshot.activeVersion.revision) is approved and frozen. Its versions, diagnosis, and tool receipts remain available for audit.",
                now: now
            )
            try finish(run: run, status: .completed, stage: "chapter.1.approvedFrozen", now: now)
            return AgentTurnResult(snapshot: try restore(now: now), status: "Chapter 1 approved and frozen")
        }
    }

    private func generateFirstChapter(
        project: NovelProject,
        approvalState: OpeningPlanApprovalState,
        run: AgentRunSnapshot,
        now: Date
    ) throws -> AgentTurnResult {
        let body = ChapterAgentTemplates.initialChapterBody(project: project, openingPlan: approvalState.artifact)
        let evidence = ChapterAgentTemplates.initialEvidenceReview(openingPlan: approvalState.artifact)
        let key = [
            "chapter.generate", conversation.id.uuidString, project.id.uuidString, "1",
            approvalState.artifact.id.uuidString, approvalState.artifact.contentHash
        ].joined(separator: ".")
        let result = try database.executeChapterGenerateTool(
            conversationID: conversation.id,
            projectID: project.id,
            chapterNumber: 1,
            title: "Chapter 1",
            body: body,
            evidenceReview: evidence,
            openingPlanArtifactID: approvalState.artifact.id,
            openingPlanHash: approvalState.artifact.contentHash,
            idempotencyKey: key,
            originRunID: run.id,
            now: now
        )
        try appendAssistant(
            "Chapter 1 revision 1 has been generated and evidence-reviewed. Review the exact revision, then accept and freeze it or reject it for diagnosis.",
            idempotencyKey: "chapter-message.generate." + result.version.id.uuidString,
            now: now
        )
        try finish(run: run, status: .waitingUser, stage: "chapter.1.reviewingV1", now: now)
        return AgentTurnResult(
            snapshot: try restore(now: now),
            status: result.isReplay ? "Verified: Chapter 1 generation replayed safely" : "Chapter 1 revision 1 ready for review"
        )
    }
    private func rejectChapter(
        snapshot: ChapterRuntimeSnapshot,
        reason: String,
        run: AgentRunSnapshot,
        now: Date
    ) throws -> AgentTurnResult {
        let version = snapshot.activeVersion
        let reasonHash = ChapterAgentTemplates.fingerprint([reason])
        let result = try database.executeChapterRejectTool(
            conversationID: conversation.id,
            projectID: snapshot.calibration.projectID,
            versionID: version.id,
            displayedContentHash: version.contentHash,
            reason: reason,
            idempotencyKey: ["chapter.reject", version.id.uuidString, version.contentHash, reasonHash].joined(separator: "."),
            originRunID: run.id,
            now: now
        )
        let question = ChapterAgentTemplates.diagnosisQuestions[0]
        try appendAssistant(
            "I will not reroll the chapter. We will diagnose it one high-information question at a time.\n\n" + question,
            idempotencyKey: "chapter-message.diagnosis.\(version.id.uuidString).1",
            now: now
        )
        try finish(run: run, status: .waitingUser, stage: "chapter.1.diagnosing.question.1", now: now)
        return AgentTurnResult(
            snapshot: try restore(now: now),
            status: result.isReplay ? "Verified: rejection replayed safely" : "Chapter 1 diagnosis started"
        )
    }

    private func handleDiagnosis(
        text: String,
        snapshot: ChapterRuntimeSnapshot,
        run: AgentRunSnapshot,
        now: Date
    ) throws -> AgentTurnResult {
        let currentAnswers = snapshot.diagnosisAnswers
        let questionIndex = min(currentAnswers.count, ChapterDiagnosisProtocol.orderedQuestions.count - 1)
        let question = ChapterDiagnosisProtocol.orderedQuestions[questionIndex]
        if ChapterAgentTemplates.isBlindRegenerationRequest(text) || ChapterAgentTemplates.isLowInformationDiagnosisAnswer(text) {
            try appendAssistant(
                "A direct reroll would hide the root cause and is not allowed. Please answer the current diagnosis question with one concrete observation:\n\n" + question,
                now: now
            )
            try finish(run: run, status: .waitingUser, stage: "chapter.1.diagnosing.question.\(questionIndex + 1)", now: now)
            return AgentTurnResult(snapshot: try restore(now: now), status: "Waiting for a concrete diagnosis answer")
        }

        let answers = currentAnswers + [text]
        let isFinalQuestion = answers.count == ChapterDiagnosisProtocol.orderedQuestions.count
        let summary = isFinalQuestion
            ? ChapterAgentTemplates.diagnosisSummary(
                answers: answers,
                lockedParagraphIndexes: snapshot.calibration.lockedParagraphIndexes
            )
            : nil
        let scope = summary.map { ChapterAgentTemplates.rewriteScope(summary: $0, source: snapshot.activeVersion) }
        let answerHash = ChapterAgentTemplates.fingerprint([text])
        let result = try database.executeChapterDiagnosisAnswerTool(
            conversationID: conversation.id,
            projectID: snapshot.calibration.projectID,
            versionID: snapshot.activeVersion.id,
            displayedContentHash: snapshot.activeVersion.contentHash,
            questionID: ChapterDiagnosisProtocol.orderedQuestionIDs[questionIndex],
            question: question,
            answer: text,
            rewriteScope: scope,
            idempotencyKey: [
                "chapter.diagnosis.answer", snapshot.activeVersion.id.uuidString,
                ChapterDiagnosisProtocol.orderedQuestionIDs[questionIndex], answerHash
            ].joined(separator: "."),
            originRunID: run.id,
            now: now
        )

        if isFinalQuestion {
            let confirmedScope = result.calibration.rewriteScope ?? scope ?? ""
            try appendDiagnosisCompleteMessage(
                summary: summary ?? "",
                scope: confirmedScope,
                scopeHash: result.calibration.rewriteScopeHash ?? result.calibration.diagnosisHash,
                now: now
            )
            try finish(run: run, status: .waitingUser, stage: "chapter.1.awaitingRewriteConfirmation", now: now)
            return AgentTurnResult(snapshot: try restore(now: now), status: "Diagnosis complete; rewrite confirmation required")
        }

        let nextIndex = questionIndex + 1
        try appendAssistant(
            ChapterDiagnosisProtocol.orderedQuestions[nextIndex],
            idempotencyKey: "chapter-message.diagnosis.\(snapshot.activeVersion.id.uuidString).\(nextIndex + 1).\(result.calibration.diagnosisHash)",
            now: now
        )
        try finish(run: run, status: .waitingUser, stage: "chapter.1.diagnosing.question.\(nextIndex + 1)", now: now)
        return AgentTurnResult(snapshot: try restore(now: now), status: "Chapter 1 diagnosis in progress")
    }

    private func appendDiagnosisCompleteMessage(
        summary: String,
        scope: String,
        scopeHash: String,
        now: Date
    ) throws {
        try appendAssistant(
            "Diagnosis complete. Review the exact rewrite scope before revision 2 is created.\n\n\(summary)\n\nRewrite scope:\n\(scope)\n\nSay \u{2018}\u{786e}\u{8ba4}\u{91cd}\u{5199}\u{2019} to authorize only this scope.",
            idempotencyKey: "chapter-message.rewrite-scope." + scopeHash,
            now: now
        )
    }

    private func rewriteChapter(
        snapshot: ChapterRuntimeSnapshot,
        run: AgentRunSnapshot,
        now: Date
    ) throws -> AgentTurnResult {
        guard !snapshot.calibration.diagnosisHash.isEmpty,
              let rewriteScopeHash = snapshot.calibration.rewriteScopeHash,
              !rewriteScopeHash.isEmpty else {
            try finish(run: run, status: .failed, stage: "chapter.1.rewrite.missingBinding", now: now)
            throw AppDatabaseError.chapterBindingMismatch
        }
        let version = snapshot.activeVersion
        let body = ChapterAgentTemplates.revisedChapterBody(source: version, snapshot: snapshot)
        let evidence = ChapterAgentTemplates.revisedEvidenceReview(source: version, snapshot: snapshot)
        let lockedBinding = ChapterAgentTemplates.fingerprint(
            snapshot.calibration.lockedParagraphIndexes.sorted().map(String.init)
        )
        let key = [
            "chapter.rewrite", version.id.uuidString, version.contentHash,
            snapshot.calibration.diagnosisHash, rewriteScopeHash, lockedBinding
        ].joined(separator: ".")
        let result = try database.executeChapterRewriteTool(
            conversationID: conversation.id,
            projectID: snapshot.calibration.projectID,
            sourceVersionID: version.id,
            displayedSourceHash: version.contentHash,
            diagnosisHash: snapshot.calibration.diagnosisHash,
            rewriteScopeHash: rewriteScopeHash,
            displayedLockedParagraphIndexes: snapshot.calibration.lockedParagraphIndexes,
            title: version.title,
            body: body,
            evidenceReview: evidence,
            idempotencyKey: key,
            originRunID: run.id,
            now: now
        )
        try appendAssistant(
            "Chapter 1 revision \(result.version.revision) is ready. Locked paragraphs were verified byte-for-byte. Review the V1/V2 diff, then accept and freeze this final calibration candidate.",
            idempotencyKey: "chapter-message.rewrite." + result.version.id.uuidString,
            now: now
        )
        try finish(run: run, status: .waitingUser, stage: "chapter.1.reviewingV2", now: now)
        return AgentTurnResult(
            snapshot: try restore(now: now),
            status: result.isReplay ? "Verified: chapter rewrite replayed safely" : "Chapter 1 revision 2 ready for review"
        )
    }
    private func acceptChapter(
        snapshot: ChapterRuntimeSnapshot,
        run: AgentRunSnapshot,
        now: Date
    ) throws -> AgentTurnResult {
        let version = snapshot.activeVersion
        let key = ["chapter.accept", version.id.uuidString, version.contentHash].joined(separator: ".")
        let result = try database.executeChapterAcceptTool(
            conversationID: conversation.id,
            projectID: snapshot.calibration.projectID,
            versionID: version.id,
            displayedContentHash: version.contentHash,
            idempotencyKey: key,
            originRunID: run.id,
            now: now
        )
        try appendAssistant(
            "Chapter 1 revision \(version.revision) is approved and frozen. The exact content hash, version history, and receipts have been preserved.",
            idempotencyKey: "chapter-message.accept." + version.id.uuidString + "." + version.contentHash,
            now: now
        )
        try finish(run: run, status: .completed, stage: "chapter.1.approvedFrozen", now: now)
        return AgentTurnResult(
            snapshot: try restore(now: now),
            status: result.isReplay ? "Verified: chapter acceptance replayed safely" : "Chapter 1 approved and frozen"
        )
    }

    @discardableResult
    private func reconcileCommittedChapterTool(_ result: ChapterToolResult, now: Date) throws -> Bool {
        guard let originRunID = result.receipt.originRunID,
              let run = try database.agentRun(id: originRunID, conversationID: conversation.id),
              run.kind == "agentTurn" else { return false }

        let settlement: (status: AgentRunStatus, stage: String)
        switch result.receipt.toolID {
        case "chapter.generate":
            guard result.calibration.stage == .reviewingV1 else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            try appendAssistant(
                "Chapter 1 revision 1 has been generated and evidence-reviewed. Review the exact revision, then accept and freeze it or reject it for diagnosis.",
                idempotencyKey: "chapter-message.generate." + result.version.id.uuidString,
                now: now
            )
            settlement = (.waitingUser, "chapter.1.reviewingV1")
        case "chapter.reject":
            guard result.calibration.stage == .diagnosing,
                  result.calibration.diagnosisEntries.isEmpty else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            try appendAssistant(
                "I will not reroll the chapter. We will diagnose it one high-information question at a time.\n\n" + ChapterDiagnosisProtocol.orderedQuestions[0],
                idempotencyKey: "chapter-message.diagnosis.\(result.version.id.uuidString).1",
                now: now
            )
            settlement = (.waitingUser, "chapter.1.diagnosing.question.1")
        case "chapter.diagnosis.answer":
            let answerCount = result.calibration.diagnosisEntries.count
            guard answerCount > 0, answerCount <= ChapterDiagnosisProtocol.orderedQuestions.count else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            if result.calibration.stage == .awaitingRewriteConfirmation {
                guard answerCount == ChapterDiagnosisProtocol.orderedQuestions.count,
                      let scope = result.calibration.rewriteScope,
                      let scopeHash = result.calibration.rewriteScopeHash else {
                    throw AppDatabaseError.invalidToolReceiptReference
                }
                let summary = ChapterAgentTemplates.diagnosisSummary(
                    answers: result.calibration.diagnosisEntries.map(\.answer),
                    lockedParagraphIndexes: result.calibration.lockedParagraphIndexes
                )
                try appendDiagnosisCompleteMessage(
                    summary: summary,
                    scope: scope,
                    scopeHash: scopeHash,
                    now: now
                )
                settlement = (.waitingUser, "chapter.1.awaitingRewriteConfirmation")
            } else {
                guard result.calibration.stage == .diagnosing,
                      answerCount < ChapterDiagnosisProtocol.orderedQuestions.count else {
                    throw AppDatabaseError.invalidToolReceiptReference
                }
                try appendAssistant(
                    ChapterDiagnosisProtocol.orderedQuestions[answerCount],
                    idempotencyKey: "chapter-message.diagnosis.\(result.version.id.uuidString).\(answerCount + 1).\(result.calibration.diagnosisHash)",
                    now: now
                )
                settlement = (.waitingUser, "chapter.1.diagnosing.question.\(answerCount + 1)")
            }
        case "chapter.rewrite":
            guard result.calibration.stage == .reviewingV2,
                  result.version.revision == 2 else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            try appendAssistant(
                "Chapter 1 revision \(result.version.revision) is ready. Locked paragraphs were verified byte-for-byte. Review the V1/V2 diff, then accept and freeze this final calibration candidate.",
                idempotencyKey: "chapter-message.rewrite." + result.version.id.uuidString,
                now: now
            )
            settlement = (.waitingUser, "chapter.1.reviewingV2")
        case "chapter.accept":
            guard result.calibration.stage == .approvedFrozen,
                  result.calibration.acceptedVersionID == result.version.id else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            try appendAssistant(
                "Chapter 1 revision \(result.version.revision) is approved and frozen. The exact content hash, version history, and receipts have been preserved.",
                idempotencyKey: "chapter-message.accept." + result.version.id.uuidString + "." + result.version.contentHash,
                now: now
            )
            settlement = (.completed, "chapter.1.approvedFrozen")
        case "chapter.lockParagraph.set":
            return false
        default:
            throw AppDatabaseError.invalidToolReceiptReference
        }

        guard run.status == .running,
              run.currentStage == "interpret" else { return true }
        try finish(run: run, status: settlement.status, stage: settlement.stage, now: now)
        return true
    }

    private func loadChapterSnapshot(projectID: UUID) throws -> ChapterRuntimeSnapshot? {
        guard let calibration = try database.chapterCalibration(
            conversationID: conversation.id,
            projectID: projectID,
            chapterNumber: 1
        ) else { return nil }
        guard let active = try database.chapterVersion(
            id: calibration.activeVersionID,
            conversationID: conversation.id,
            projectID: projectID
        ) else {
            throw AppDatabaseError.chapterBindingMismatch
        }
        let versions = try database.listChapterVersions(
            chapterLogicalID: calibration.chapterLogicalID,
            conversationID: conversation.id,
            projectID: projectID
        )
        guard !versions.isEmpty,
              versions.last == active,
              versions.allSatisfy({
                $0.logicalID == calibration.chapterLogicalID
                    && $0.conversationID == conversation.id
                    && $0.projectID == projectID
                    && $0.chapterNumber == calibration.chapterNumber
              }) else {
            throw AppDatabaseError.chapterBindingMismatch
        }
        guard let chapterReceipt = try database.latestChapterToolReceipt(
            conversationID: conversation.id,
            projectID: projectID,
            chapterLogicalID: calibration.chapterLogicalID
        ) else {
            throw AppDatabaseError.invalidToolReceiptReference
        }
        let validatedResult = try database.validatedChapterToolResult(
            receiptID: chapterReceipt.id,
            conversationID: conversation.id,
            projectID: projectID,
            chapterLogicalID: calibration.chapterLogicalID
        )
        guard validatedResult.receipt == chapterReceipt else {
            #if DEBUG
            print(
                "Chapter snapshot mismatch [receipt] expected=\(chapterReceipt.id.uuidString) "
                    + "actual=\(validatedResult.receipt.id.uuidString) tool=\(chapterReceipt.toolID)"
            )
            #endif
            throw AppDatabaseError.invalidToolReceiptReference
        }
        guard validatedResult.calibration.isAuditEquivalent(to: calibration) else {
            #if DEBUG
            print(
                "Chapter snapshot mismatch [calibration] tool=\(chapterReceipt.toolID) "
                    + "liveStage=\(calibration.stage.rawValue) snapshotStage=\(validatedResult.calibration.stage.rawValue) "
                    + "liveVersion=\(calibration.activeVersionID.uuidString) "
                    + "snapshotVersion=\(validatedResult.calibration.activeVersionID.uuidString) "
                    + "liveUpdatedAt=\(calibration.updatedAt.timeIntervalSinceReferenceDate.bitPattern) "
                    + "snapshotUpdatedAt=\(validatedResult.calibration.updatedAt.timeIntervalSinceReferenceDate.bitPattern)"
            )
            #endif
            throw AppDatabaseError.invalidToolReceiptReference
        }
        guard validatedResult.version == active else {
            #if DEBUG
            print(
                "Chapter snapshot mismatch [version] tool=\(chapterReceipt.toolID) "
                    + "live=\(active.id.uuidString):\(active.revision):\(active.createdAt.timeIntervalSinceReferenceDate.bitPattern) "
                    + "snapshot=\(validatedResult.version.id.uuidString):\(validatedResult.version.revision):"
                    + "\(validatedResult.version.createdAt.timeIntervalSinceReferenceDate.bitPattern)"
            )
            #endif
            throw AppDatabaseError.invalidToolReceiptReference
        }
        if calibration.stage == .approvedFrozen {
            guard chapterReceipt.toolID == "chapter.accept",
                  chapterReceipt.toolVersion == "1",
                  chapterReceipt.inputSummary == "chapter:\(active.id.uuidString):accept",
                  chapterReceipt.outcome == "completed",
                  chapterReceipt.outputReference == active.id.uuidString,
                  calibration.acceptedVersionID == active.id else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
        }
        return ChapterRuntimeSnapshot(
            calibration: calibration,
            activeVersion: active,
            versions: versions,
            lastReceipt: chapterReceipt
        )
    }

    private func reconcileApprovedOpeningPlan(_ state: OpeningPlanApprovalState?, now: Date) throws -> ToolReceipt? {
        guard let state, state.approval.status == .approved else { return nil }
        let approvalKey = Self.approvalIdempotencyKey(requestID: state.approval.id, bindingHash: state.approval.bindingHash)
        guard let receipt = try database.toolReceipt(idempotencyKey: approvalKey) else {
            throw AppDatabaseError.invalidToolReceiptReference
        }
        try Self.validateExactApprovalReceipt(receipt, state: state, idempotencyKey: approvalKey)
        try appendApprovalSuccessMessage(for: state.approval, now: now)
        if let interruptedRun = try database.agentRun(idempotencyKey: approvalKey),
           interruptedRun.status.canReconcileSuccessfulApproval {
            try finish(run: interruptedRun, status: .completed, stage: "openingPlan.approved", now: now)
        }
        return receipt
    }

    private func appendApprovalSuccessMessage(for approval: ApprovalRequest, now: Date) throws {
        try appendAssistant(
            "Opening plan approved and persisted. Chapter planning is now unlocked.",
            idempotencyKey: Self.approvalMessageIdempotencyKey(requestID: approval.id, bindingHash: approval.bindingHash),
            now: now
        )
    }

    private func appendAssistant(_ content: String, idempotencyKey: String? = nil, now: Date) throws {
        _ = try database.appendAgentMessage(
            conversationID: conversation.id,
            role: .assistant,
            content: content,
            idempotencyKey: idempotencyKey,
            now: now
        )
    }

    private static func validateExactApprovalReceipt(
        _ receipt: ToolReceipt,
        state: OpeningPlanApprovalState,
        idempotencyKey: String
    ) throws {
        let approval = state.approval
        guard receipt.toolID == approval.toolID,
              receipt.toolVersion == approval.toolVersion,
              receipt.inputSummary == "openingPlan:approved",
              receipt.inputHash == approval.bindingHash,
              receipt.outcome == "completed",
              receipt.conversationID == approval.conversationID,
              receipt.projectID == approval.projectID,
              receipt.approvalRequestID == approval.id,
              receipt.approvalBindingHash == approval.bindingHash,
              receipt.idempotencyKey == idempotencyKey,
              receipt.outputReference == state.artifact.id.uuidString else {
            throw AppDatabaseError.idempotencyConflict
        }
    }

    private func finish(run: AgentRunSnapshot, status: AgentRunStatus, stage: String, now: Date) throws {
        try database.saveAgentRun(
            AgentRunSnapshot(
                id: run.id, projectID: run.projectID,
                kind: run.kind, status: status, idempotencyKey: run.idempotencyKey,
                currentStage: stage, startedAt: run.startedAt, updatedAt: now
            ),
            conversationID: conversation.id
        )
    }

    private static func chapterStatusMessage(_ snapshot: ChapterRuntimeSnapshot) -> String {
        switch snapshot.stage {
        case .notStarted:
            return "Chapter 1 has not started."
        case .reviewingV1, .reviewingV2:
            return "Chapter 1 revision \(snapshot.activeVersion.revision) is waiting for your review."
        case .diagnosing:
            return "Chapter 1 is in diagnosis question \(snapshot.nextDiagnosisQuestionIndex + 1) of \(ChapterDiagnosisProtocol.orderedQuestionIDs.count)."
        case .awaitingRewriteConfirmation:
            return "The diagnosis is complete and the exact rewrite scope is waiting for confirmation."
        case .rewriting:
            return "The confirmed Chapter 1 rewrite is resumable from its idempotent tool binding."
        case .approvedFrozen:
            return "Chapter 1 revision \(snapshot.activeVersion.revision) is approved and frozen."
        }
    }

    private static func chapterStatusLabel(_ stage: ChapterCalibrationStage) -> String {
        "Chapter 1: " + stage.rawValue
    }

    private static func approvalIdempotencyKey(requestID: UUID, bindingHash: String) -> String {
        ["artifact.openingPlan.approve", requestID.uuidString, bindingHash].joined(separator: ".")
    }

    private static func approvalMessageIdempotencyKey(requestID: UUID, bindingHash: String) -> String {
        ["approval-message", requestID.uuidString, bindingHash].joined(separator: ".")
    }

    private static func isProjectCreationIntent(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains("create")
            || text.localizedCaseInsensitiveContains("novel")
            || text.contains("\u{521B}\u{5EFA}")
            || text.contains("\u{5C0F}\u{8BF4}")
    }

    private static func makeOpeningPlan(answers: [String]) -> String {
        let safe = answers + Array(repeating: "Not yet confirmed", count: max(0, 3 - answers.count))
        return """
        Opening plan

        Hook: \(safe[0])

        Protagonist and immediate desire: \(safe[1])

        First victory cost or danger: \(safe[2])

        Chapter 1 promise: reveal the protagonist's immediate desire, establish the first pressure, and end on an irreversible question.

        Guardrails: preserve confirmed premises; do not add unapproved genre contamination or character knowledge.
        """
    }
}
