import CryptoKit
import Foundation
import SwiftUI

struct TransientNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        case lifecycle
        case projectRefresh
        case storage
        case network
    }

    let id: UUID
    let kind: Kind
    let message: String
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var draft = ""
    @Published private(set) var businessStatus = "Initializing..."
    @Published private(set) var transientNotice: TransientNotice?
    @Published private(set) var errorMessage: String?
    @Published var apiKeyInput = ""
    @Published var hasStoredKey = false
    @Published var streamURL = ""
    @Published var streamOutput = ""
    @Published var isStreaming = false
    @Published private(set) var projects: [NovelProject] = []
    @Published var isLeftPagePresented = false
    @Published var isArtifactDrawerPresented = false
    @Published var conversationMessages: [String] = []
    @Published var isAgentWorking = false
    @Published private(set) var interviewQuestion = AgentRuntime.interviewQuestions[0]
    @Published private(set) var planBody = ""
    @Published private(set) var planAwaitingApproval = false
    @Published private(set) var openingPlanApproval: ApprovalRequest?
    @Published private(set) var interviewStep = 0
    @Published private(set) var lastToolReceipt: ToolReceipt?
    @Published private(set) var latestAgentRun: AgentRunSnapshot?

    var status: String { errorMessage ?? businessStatus }

    private static let maximumStreamOutputBytes = 256 * 1_024
    private let database: AppDatabase?
    private let runtime: AgentRuntime?
    private let keychain: any SecretRepository
    private let taskID: UUID
    private var streamTask: Task<Void, Never>?
    private var streamGeneration: UUID?
    private var noticeDismissTask: Task<Void, Never>?

    init(
        database: AppDatabase? = nil,
        databaseFactory: () throws -> AppDatabase = { try AppDatabase.makeDefault() },
        keychain: any SecretRepository = KeychainSecretRepository()
    ) {
        self.keychain = keychain
        let defaultsKey = "m0TaskID"
        if let stored = UserDefaults.standard.string(forKey: defaultsKey),
           let id = UUID(uuidString: stored) {
            taskID = id
        } else {
            let id = UUID()
            taskID = id
            UserDefaults.standard.set(id.uuidString, forKey: defaultsKey)
        }

        let databaseState: (database: AppDatabase?, draft: String, notice: String?, error: String?)
        do {
            let resolved = try database ?? databaseFactory()
            let restoredDraft = try resolved.loadDraft()?.content ?? ""
            let restoredNotice: String
            if let checkpoint = try resolved.latestCheckpoint(taskID: taskID) {
                restoredNotice = Self.payloadHash(for: restoredDraft) == checkpoint.payloadHash
                    ? "Restored checkpoint #\(checkpoint.sequence)"
                    : "Draft is newer than the latest checkpoint"
            } else {
                restoredNotice = "SQLite ready; no checkpoint yet"
            }
            databaseState = (resolved, restoredDraft, restoredNotice, nil)
        } catch {
            databaseState = (nil, "", nil, "SQLite initialization failed (DB-INIT)")
        }

        self.database = databaseState.database
        if let resolvedDatabase = databaseState.database {
            runtime = try? AgentRuntime(database: resolvedDatabase)
        } else {
            runtime = nil
        }
        draft = databaseState.draft
        errorMessage = databaseState.error

        if let runtime {
            do {
                let snapshot = try runtime.restore()
                apply(runtimeSnapshot: snapshot)
                businessStatus = Self.businessStatus(for: snapshot)
            } catch {
                businessStatus = "Agent unavailable"
                publishError("Agent restore failed (AGENT-RESTORE)")
            }
        } else {
            businessStatus = "Agent unavailable"
        }

        if let notice = databaseState.notice {
            publishTransientNotice(kind: .storage, message: notice)
        }

        do {
            hasStoredKey = try keychain.contains(account: "m0-probe")
        } catch {
            publishError("Keychain unavailable (KEY-READ)")
        }
    }

    func reloadProjects() {
        guard let database else {
            publishError("Project list failed (DB-PROJECT-LIST)")
            return
        }
        do {
            let refreshedProjects = try database.listProjects()
            projects = refreshedProjects
            let noun = refreshedProjects.count == 1 ? "project" : "projects"
            publishTransientNotice(
                kind: .projectRefresh,
                message: "Projects refreshed ? \(refreshedProjects.count) \(noun) ? \(Date().formatted(date: .omitted, time: .standard))"
            )
        } catch {
            publishError("Project list failed (DB-PROJECT-LIST)")
        }
    }

    func approveOpeningPlan(requestID: UUID, displayedBindingHash: String) {
        guard let runtime,
              let displayed = openingPlanApproval,
              displayed.id == requestID,
              displayed.bindingHash == displayedBindingHash,
              displayed.status == .pending,
              !planBody.isEmpty else {
            businessStatus = "Opening plan changed; review the latest approval card"
            publishError("Displayed approval is no longer current (AGENT-APPROVAL-STALE)")
            return
        }
        isAgentWorking = true
        defer { isAgentWorking = false }
        do {
            let result = try runtime.approveOpeningPlan(
                approvalRequestID: requestID,
                displayedBindingHash: displayedBindingHash
            )
            apply(runtimeSnapshot: result.snapshot)
            businessStatus = result.status
        } catch let error as AppDatabaseError {
            switch error {
            case .approvalRequiresReapproval:
                businessStatus = "Opening plan changed; review and approve the latest revision"
                publishError("Displayed approval is stale (AGENT-APPROVAL-STALE)")
            case .approvalExpired:
                businessStatus = "Opening plan approval expired; review the renewed approval card"
                publishError("Plan approval expired (AGENT-APPROVAL-EXPIRED)")
            case .approvalBudgetExceeded:
                businessStatus = "Opening plan approval paused by the budget gate"
                publishError("Plan approval exceeds budget (AGENT-APPROVAL-BUDGET)")
            default:
                publishError("Plan approval failed (AGENT-APPROVAL)")
            }
            if let snapshot = try? runtime.restore() {
                apply(runtimeSnapshot: snapshot)
            }
        } catch {
            publishError("Plan approval failed (AGENT-APPROVAL)")
        }
    }

    func sendAgentMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let runtime else {
            conversationMessages.append("You: " + text)
            conversationMessages.append("Agent: Database unavailable; no tool was executed.")
            draft = ""
            publishError("Agent runtime unavailable")
            return
        }

        draft = ""
        isAgentWorking = true
        defer { isAgentWorking = false }
        do {
            let result = try runtime.handleUserMessage(text)
            apply(runtimeSnapshot: result.snapshot)
            businessStatus = result.status
        } catch {
            publishError("Agent turn failed (AGENT-TURN)")
        }
    }

    private func apply(runtimeSnapshot snapshot: AgentRuntimeSnapshot) {
        conversationMessages = snapshot.messages.map(\.displayText)
        projects = snapshot.projects
        interviewQuestion = snapshot.session.currentQuestion.isEmpty
            ? AgentRuntime.interviewQuestions[0]
            : snapshot.session.currentQuestion
        interviewStep = snapshot.session.interviewStep
        planBody = snapshot.openingPlan?.body ?? ""
        openingPlanApproval = snapshot.openingPlanApproval
        planAwaitingApproval = snapshot.openingPlanApproval?.status == .pending
        lastToolReceipt = snapshot.lastReceipt
        latestAgentRun = snapshot.latestRun
    }

    func saveDraft() {
        guard let database else {
            publishError("Draft save failed (DB-WRITE)")
            return
        }
        do {
            try database.saveDraft(draft)
            publishTransientNotice(
                kind: .storage,
                message: "Draft saved ? \(Date().formatted(date: .omitted, time: .standard))"
            )
        } catch {
            publishError("Draft save failed (DB-WRITE)")
        }
    }

    func createCheckpoint(reason: String) {
        guard let database else {
            publishError("Checkpoint write failed (DB-CHECKPOINT)")
            return
        }
        do {
            let checkpoint = try database.checkpointDraft(
                content: draft,
                taskID: taskID,
                reason: reason,
                payloadHash: Self.payloadHash(for: draft)
            )
            publishTransientNotice(
                kind: .lifecycle,
                message: "Draft protected by checkpoint #\(checkpoint.sequence) (\(reason))"
            )
        } catch {
            publishError("Checkpoint write failed (DB-CHECKPOINT)")
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive:
            createCheckpoint(reason: "sceneInactive")
        case .background:
            createCheckpoint(reason: "sceneBackground")
        case .active:
            break
        @unknown default:
            createCheckpoint(reason: "sceneUnknown")
        }
    }

    func saveProbeKey() {
        guard !apiKeyInput.isEmpty else {
            publishError("Keychain test value cannot be empty")
            return
        }
        do {
            try keychain.save(apiKeyInput, account: "m0-probe")
            apiKeyInput = ""
            hasStoredKey = true
            publishTransientNotice(kind: .storage, message: "Saved test value in ThisDeviceOnly Keychain")
        } catch {
            publishError("Keychain write failed (KEY-WRITE)")
        }
    }

    func deleteProbeKey() {
        do {
            try keychain.delete(account: "m0-probe")
            apiKeyInput = ""
            hasStoredKey = false
            publishTransientNotice(kind: .storage, message: "Keychain test value deleted")
        } catch {
            publishError("Keychain delete failed (KEY-DELETE)")
        }
    }

    func startStreamingProbe() {
        streamTask?.cancel()
        let generation = UUID()
        streamGeneration = generation
        streamOutput = ""
        isStreaming = true
        publishTransientNotice(kind: .network, message: "Connecting to HTTPS SSE...")

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in StreamingHTTPClient().stream(urlText: self.streamURL) {
                    try Task.checkCancellation()
                    guard self.streamGeneration == generation else { return }
                    let appended = self.streamOutput + event.data + "\n"
                    guard appended.utf8.count <= Self.maximumStreamOutputBytes else {
                        throw StreamingHTTPError.outputLimitExceeded
                    }
                    self.streamOutput = appended
                }
                try Task.checkCancellation()
                guard self.streamGeneration == generation else { return }
                self.publishTransientNotice(kind: .network, message: "Streaming probe completed")
            } catch is CancellationError {
                guard self.streamGeneration == generation else { return }
                self.publishTransientNotice(kind: .network, message: "Streaming probe cancelled")
            } catch let error as StreamingHTTPError {
                guard self.streamGeneration == generation else { return }
                self.publishError(error.errorDescription ?? "Streaming probe failed (NET-SSE)")
            } catch {
                guard self.streamGeneration == generation else { return }
                self.publishError("Streaming probe failed (NET-SSE)")
            }

            guard self.streamGeneration == generation else { return }
            self.streamGeneration = nil
            self.streamTask = nil
            self.isStreaming = false
        }
    }

    func cancelStreamingProbe() {
        streamGeneration = nil
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        publishTransientNotice(kind: .network, message: "Streaming probe cancelled")
    }

    private func publishTransientNotice(kind: TransientNotice.Kind, message: String) {
        noticeDismissTask?.cancel()
        let notice = TransientNotice(id: UUID(), kind: kind, message: message)
        transientNotice = notice
        noticeDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled, self?.transientNotice?.id == notice.id else { return }
            self?.transientNotice = nil
        }
    }

    private func publishError(_ message: String) {
        if let current = errorMessage, current != message {
            errorMessage = current + "; " + message
        } else {
            errorMessage = message
        }
    }

    private static func businessStatus(for snapshot: AgentRuntimeSnapshot) -> String {
        if let approval = snapshot.openingPlanApproval {
            switch approval.status {
            case .pending:
                return "Waiting for opening plan approval"
            case .approved:
                return "Opening plan approved; chapter planning pending"
            case .invalidated:
                return "Opening plan changed; re-approval required"
            case .expired:
                return "Opening plan approval expired; re-approval required"
            }
        }

        if let stage = snapshot.latestRun?.currentStage {
            if stage.hasPrefix("openingPlan.approval") {
                return "Waiting for opening plan approval"
            }
            if stage.hasPrefix("openingPlan.approved") {
                return "Opening plan approved; chapter planning pending"
            }
            if stage.hasPrefix("strategicInterview") {
                return "Strategic interview in progress"
            }
            if stage == "awaitingProjectIntent" {
                return "Waiting for a novel idea"
            }
        }

        if snapshot.session.focusedProjectID != nil || !snapshot.projects.isEmpty {
            return "Strategic interview in progress"
        }
        return "Waiting for a novel idea"
    }

    private static func payloadHash(for text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
