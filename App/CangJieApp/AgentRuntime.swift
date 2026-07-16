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

    func restore() throws -> AgentRuntimeSnapshot {
        AgentRuntimeSnapshot(
            conversation: conversation,
            messages: try database.listAgentMessages(conversationID: conversation.id),
            projects: try database.listProjects(),
            session: try database.loadAgentSession(conversationID: conversation.id) ?? .empty(),
            openingPlan: try database.latestArtifact(kind: "openingPlan", conversationID: conversation.id),
            lastReceipt: try database.latestToolReceipt(conversationID: conversation.id),
            latestRun: try database.latestAgentRun(conversationID: conversation.id)
        )
    }

    func handleUserMessage(_ rawText: String, now: Date = Date()) throws -> AgentTurnResult {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return AgentTurnResult(snapshot: try restore(), status: "Ready") }

        let userMessage = try database.appendAgentMessage(conversationID: conversation.id, role: .user, content: text, now: now)
        let run = AgentRunSnapshot(
            id: UUID(), kind: "agentTurn", status: .running,
            idempotencyKey: "agent.turn." + userMessage.id.uuidString,
            currentStage: "interpret", startedAt: now, updatedAt: now
        )
        try database.saveAgentRun(run, conversationID: conversation.id)

        let projects = try database.listProjects()
        if projects.isEmpty && Self.isProjectCreationIntent(text) {
            let tool = try database.executeProjectCreateTool(
                conversationID: conversation.id,
                title: "Untitled Novel", premise: text,
                idempotencyKey: "project.create." + userMessage.id.uuidString, now: now
            )
            _ = try database.appendAgentMessage(conversationID: conversation.id, role: .assistant, content: "Project created: " + tool.project.title, now: now)
            _ = try database.appendAgentMessage(conversationID: conversation.id, role: .assistant, content: Self.interviewQuestions[0], now: now)
            try database.saveAgentSession(AgentSessionState(
                focusedProjectID: tool.project.id, interviewStep: 0,
                currentQuestion: Self.interviewQuestions[0], interviewAnswers: [], updatedAt: now
            ), conversationID: conversation.id)
            try finish(run: run, status: .waitingUser, stage: "strategicInterview.question.1", now: now)
            return AgentTurnResult(snapshot: try restore(), status: "Verified: project.create")
        }

        guard !projects.isEmpty else {
            _ = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .assistant,
                content: "Tell me the idea or ask me to create a novel, and I will lead the next step.",
                now: now
            )
            try finish(run: run, status: .waitingUser, stage: "awaitingProjectIntent", now: now)
            return AgentTurnResult(snapshot: try restore(), status: "Waiting for a novel idea")
        }

        if let openingPlan = try database.latestArtifact(kind: "openingPlan", conversationID: conversation.id) {
            if openingPlan.status == "waitingApproval" {
                _ = try database.appendAgentMessage(
                    conversationID: conversation.id,
                    role: .assistant,
                    content: "The opening plan is waiting for your approval. Review the plan card before we continue.",
                    now: now
                )
                try finish(run: run, status: .waitingUser, stage: "openingPlan.approval", now: now)
                return AgentTurnResult(snapshot: try restore(), status: "Waiting for opening plan approval")
            }
            if openingPlan.status == "approved" {
                _ = try database.appendAgentMessage(
                    conversationID: conversation.id,
                    role: .assistant,
                    content: "The opening plan is approved. Chapter planning is the next governed step.",
                    now: now
                )
                try finish(run: run, status: .completed, stage: "openingPlan.approved", now: now)
                return AgentTurnResult(snapshot: try restore(), status: "Opening plan approved; chapter planning pending")
            }
        }

        let current = try database.loadAgentSession(conversationID: conversation.id) ?? AgentSessionState(
            focusedProjectID: projects.first?.id, interviewStep: 0,
            currentQuestion: Self.interviewQuestions[0], interviewAnswers: [], updatedAt: now
        )
        var answers = current.interviewAnswers
        answers.append(text)
        let step = answers.count

        if step < Self.interviewQuestions.count {
            let question = Self.interviewQuestions[step]
            try database.saveAgentSession(AgentSessionState(
                focusedProjectID: current.focusedProjectID ?? projects.first?.id,
                interviewStep: step, currentQuestion: question,
                interviewAnswers: answers, updatedAt: now
            ), conversationID: conversation.id)
            _ = try database.appendAgentMessage(conversationID: conversation.id, role: .assistant, content: question, now: now)
            try finish(run: run, status: .waitingUser, stage: "strategicInterview.question.\(step + 1)", now: now)
            return AgentTurnResult(snapshot: try restore(), status: "Strategic interview in progress")
        }

        let planBody = Self.makeOpeningPlan(answers: answers)
        _ = try database.executeArtifactTool(
            conversationID: conversation.id,
            projectID: current.focusedProjectID ?? projects.first?.id,
            toolID: "artifact.openingPlan.save", kind: "openingPlan", title: "Opening plan",
            body: planBody, status: "waitingApproval",
            idempotencyKey: "artifact.openingPlan.save." + userMessage.id.uuidString, now: now
        )
        try database.saveAgentSession(AgentSessionState(
            focusedProjectID: current.focusedProjectID ?? projects.first?.id,
            interviewStep: Self.interviewQuestions.count, currentQuestion: "",
            interviewAnswers: Array(answers.prefix(Self.interviewQuestions.count)), updatedAt: now
        ), conversationID: conversation.id)
        _ = try database.appendAgentMessage(
            conversationID: conversation.id,
            role: .assistant,
            content: "I have compiled the opening plan. Review it in the artifact drawer and approve it before chapter planning.",
            now: now
        )
        try finish(run: run, status: .waitingUser, stage: "openingPlan.approval", now: now)
        return AgentTurnResult(snapshot: try restore(), status: "Waiting for opening plan approval")
    }

    func approveOpeningPlan(now: Date = Date()) throws -> AgentTurnResult {
        guard let plan = try database.latestArtifact(kind: "openingPlan", conversationID: conversation.id), !plan.body.isEmpty else {
            return AgentTurnResult(snapshot: try restore(), status: "No opening plan to approve")
        }
        if plan.status == "approved" {
            if let receipt = try database.latestToolReceipt(conversationID: conversation.id),
               receipt.toolID == "artifact.openingPlan.approve",
               let approvalKey = receipt.idempotencyKey,
               let pendingRun = try database.agentRun(idempotencyKey: approvalKey),
               pendingRun.status != .completed {
                try finish(run: pendingRun, status: .completed, stage: "openingPlan.approved", now: now)
            }
            return AgentTurnResult(snapshot: try restore(), status: "Verified: opening plan approved")
        }

        let approvalKey = "artifact.openingPlan.approve." + plan.id.uuidString
        let run = AgentRunSnapshot(
            id: UUID(), kind: "approval", status: .running,
            idempotencyKey: approvalKey,
            currentStage: "openingPlan.approve", startedAt: now, updatedAt: now
        )
        try database.saveAgentRun(run, conversationID: conversation.id)
        _ = try database.executeArtifactTool(
            conversationID: conversation.id,
            projectID: plan.projectID,
            toolID: "artifact.openingPlan.approve", kind: plan.kind, title: plan.title,
            body: plan.body, status: "approved",
            idempotencyKey: approvalKey, now: now
        )
        _ = try database.appendAgentMessage(
            conversationID: conversation.id,
            role: .assistant,
            content: "Opening plan approved and persisted. Chapter planning is now unlocked.", now: now
        )
        try finish(run: run, status: .completed, stage: "openingPlan.approved", now: now)
        return AgentTurnResult(snapshot: try restore(), status: "Verified: opening plan approved")
    }

    private func finish(run: AgentRunSnapshot, status: AgentRunStatus, stage: String, now: Date) throws {
        try database.saveAgentRun(AgentRunSnapshot(
            id: run.id, kind: run.kind, status: status, idempotencyKey: run.idempotencyKey,
            currentStage: stage, startedAt: run.startedAt, updatedAt: now
        ), conversationID: conversation.id)
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
