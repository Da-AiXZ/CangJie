import Foundation

final class AgentRuntime {
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
        let exactApprovalReceipt = try reconcileApprovedOpeningPlan(
            approvalState,
            now: now
        )
        let lastReceipt: ToolReceipt?
        if approvalState?.approval.status == .approved {
            lastReceipt = exactApprovalReceipt
        } else {
            lastReceipt = try database.latestToolReceipt(conversationID: conversation.id)
        }

        return AgentRuntimeSnapshot(
            conversation: conversation,
            messages: try database.listAgentMessages(conversationID: conversation.id),
            projects: try database.listProjects(),
            session: session,
            openingPlan: approvalState?.artifact,
            openingPlanApproval: approvalState?.approval,
            lastReceipt: lastReceipt,
            latestRun: try database.latestAgentRun(conversationID: conversation.id)
        )
    }

    func handleUserMessage(_ rawText: String, now: Date = Date()) throws -> AgentTurnResult {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return AgentTurnResult(snapshot: try restore(now: now), status: "Ready") }

        let userMessage = try database.appendAgentMessage(
            conversationID: conversation.id,
            role: .user,
            content: text,
            now: now
        )
        let run = AgentRunSnapshot(
            id: UUID(),
            kind: "agentTurn",
            status: .running,
            idempotencyKey: "agent.turn." + userMessage.id.uuidString,
            currentStage: "interpret",
            startedAt: now,
            updatedAt: now
        )
        try database.saveAgentRun(run, conversationID: conversation.id)

        let projects = try database.listProjects()
        if projects.isEmpty && Self.isProjectCreationIntent(text) {
            let tool = try database.executeProjectCreateTool(
                conversationID: conversation.id,
                title: "Untitled Novel",
                premise: text,
                idempotencyKey: "project.create." + userMessage.id.uuidString,
                now: now
            )
            _ = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .assistant,
                content: "Project created: " + tool.project.title,
                now: now
            )
            _ = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .assistant,
                content: Self.interviewQuestions[0],
                now: now
            )
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
            _ = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .assistant,
                content: "Tell me the idea or ask me to create a novel, and I will lead the next step.",
                now: now
            )
            try finish(run: run, status: .waitingUser, stage: "awaitingProjectIntent", now: now)
            return AgentTurnResult(snapshot: try restore(now: now), status: "Waiting for a novel idea")
        }

        let current = try database.loadAgentSession(conversationID: conversation.id) ?? AgentSessionState(
            focusedProjectID: projects.first?.id,
            interviewStep: 0,
            currentQuestion: Self.interviewQuestions[0],
            interviewAnswers: [],
            updatedAt: now
        )
        if let approval = try database.ensureOpeningPlanApprovalRequest(
            conversationID: conversation.id,
            focusedProjectID: current.focusedProjectID,
            now: now
        ) {
            switch approval.status {
            case .pending:
                _ = try database.appendAgentMessage(
                    conversationID: conversation.id,
                    role: .assistant,
                    content: "The opening plan is waiting for your exact approval. Review the bound revision, budget, expiration, and expected change before we continue.",
                    now: now
                )
                try finish(run: run, status: .waitingUser, stage: "openingPlan.approval", now: now)
                return AgentTurnResult(snapshot: try restore(now: now), status: "Waiting for opening plan approval")
            case .approved:
                _ = try database.appendAgentMessage(
                    conversationID: conversation.id,
                    role: .assistant,
                    content: "The opening plan is approved. Chapter planning is the next governed step.",
                    now: now
                )
                try finish(run: run, status: .completed, stage: "openingPlan.approved", now: now)
                return AgentTurnResult(
                    snapshot: try restore(now: now),
                    status: "Opening plan approved; chapter planning pending"
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
            _ = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .assistant,
                content: question,
                now: now
            )
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
        _ = try database.appendAgentMessage(
            conversationID: conversation.id,
            role: .assistant,
            content: "I have compiled the opening plan. Review its exact approval card before chapter planning.",
            now: now
        )
        try finish(run: run, status: .waitingUser, stage: "openingPlan.approval", now: now)
        return AgentTurnResult(snapshot: try restore(now: now), status: "Waiting for opening plan approval")
    }

    func approveOpeningPlan(
        approvalRequestID: UUID,
        displayedBindingHash: String,
        now: Date = Date()
    ) throws -> AgentTurnResult {
        guard !displayedBindingHash.isEmpty else {
            throw AppDatabaseError.invalidApprovalRequest
        }
        let approvalKey = Self.approvalIdempotencyKey(
            requestID: approvalRequestID,
            bindingHash: displayedBindingHash
        )
        let existingRun = try database.agentRun(idempotencyKey: approvalKey)
        let run = existingRun ?? AgentRunSnapshot(
            id: UUID(),
            kind: "approval",
            status: .running,
            idempotencyKey: approvalKey,
            currentStage: "openingPlan.approve",
            startedAt: now,
            updatedAt: now
        )
        try database.saveAgentRun(
            AgentRunSnapshot(
                id: run.id,
                kind: run.kind,
                status: .running,
                idempotencyKey: run.idempotencyKey,
                currentStage: "openingPlan.approve",
                startedAt: run.startedAt,
                updatedAt: now
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
                state: OpeningPlanApprovalState(
                    artifact: result.artifact,
                    approval: result.approval
                ),
                idempotencyKey: approvalKey
            )
            try appendApprovalSuccessMessage(for: result.approval, now: now)
            try finish(run: run, status: .completed, stage: "openingPlan.approved", now: now)
            return AgentTurnResult(
                snapshot: try restore(now: now),
                status: result.isReplay
                    ? "Verified: opening plan approval replayed safely"
                    : "Verified: opening plan approved"
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

    private func reconcileApprovedOpeningPlan(
        _ state: OpeningPlanApprovalState?,
        now: Date
    ) throws -> ToolReceipt? {
        guard let state, state.approval.status == .approved else { return nil }

        let approvalKey = Self.approvalIdempotencyKey(
            requestID: state.approval.id,
            bindingHash: state.approval.bindingHash
        )
        guard let receipt = try database.toolReceipt(idempotencyKey: approvalKey) else {
            throw AppDatabaseError.invalidToolReceiptReference
        }
        try Self.validateExactApprovalReceipt(
            receipt,
            state: state,
            idempotencyKey: approvalKey
        )
        try appendApprovalSuccessMessage(for: state.approval, now: now)

        if let interruptedRun = try database.agentRun(idempotencyKey: approvalKey),
           interruptedRun.status.canReconcileSuccessfulApproval {
            try finish(
                run: interruptedRun,
                status: .completed,
                stage: "openingPlan.approved",
                now: now
            )
        }
        return receipt
    }

    private func appendApprovalSuccessMessage(for approval: ApprovalRequest, now: Date) throws {
        _ = try database.appendAgentMessage(
            conversationID: conversation.id,
            role: .assistant,
            content: "Opening plan approved and persisted. Chapter planning is now unlocked.",
            idempotencyKey: Self.approvalMessageIdempotencyKey(
                requestID: approval.id,
                bindingHash: approval.bindingHash
            ),
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
                id: run.id,
                kind: run.kind,
                status: status,
                idempotencyKey: run.idempotencyKey,
                currentStage: stage,
                startedAt: run.startedAt,
                updatedAt: now
            ),
            conversationID: conversation.id
        )
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
