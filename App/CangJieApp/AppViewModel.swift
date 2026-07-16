import CryptoKit
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var draft = ""
    @Published var status = "Initializing..."
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
    @Published private(set) var interviewStep = 0
    @Published private(set) var lastToolReceipt: ToolReceipt?
    @Published private(set) var latestAgentRun: AgentRunSnapshot?

    private static let maximumStreamOutputBytes = 256 * 1_024
    private let database: AppDatabase?
    private let runtime: AgentRuntime?
    private let keychain: any SecretRepository
    private let taskID: UUID
    private var streamTask: Task<Void, Never>?
    private var streamGeneration: UUID?

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

        let databaseState: (database: AppDatabase?, draft: String, status: String)
        do {
            let resolved = try database ?? databaseFactory()
            let restoredDraft = try resolved.loadDraft()?.content ?? ""
            let restoredStatus: String
            if let checkpoint = try resolved.latestCheckpoint(taskID: taskID) {
                restoredStatus = Self.payloadHash(for: restoredDraft) == checkpoint.payloadHash
                    ? "Restored checkpoint #\(checkpoint.sequence)"
                    : "Draft is newer than the latest checkpoint"
            } else {
                restoredStatus = "SQLite ready; no checkpoint yet"
            }
            databaseState = (resolved, restoredDraft, restoredStatus)
        } catch {
            databaseState = (nil, "", "SQLite initialization failed (DB-INIT)")
        }

        self.database = databaseState.database
        if let resolvedDatabase = databaseState.database {
            self.runtime = try? AgentRuntime(database: resolvedDatabase)
        } else {
            self.runtime = nil
        }
        draft = databaseState.draft
        status = databaseState.status

        if let runtime {
            do {
                apply(runtimeSnapshot: try runtime.restore())
            } catch {
                status = "\(status); Agent restore failed (AGENT-RESTORE)"
            }
        }

        do {
            hasStoredKey = try keychain.contains(account: "m0-probe")
        } catch {
            status = "\(status); Keychain unavailable (KEY-READ)"
        }
    }

    func reloadProjects() {
        guard let database else { projects = []; return }
        do { projects = try database.listProjects() }
        catch { status = "Project list failed (DB-PROJECT-LIST)" }
    }

    func approveOpeningPlan() {
        guard let runtime, !planBody.isEmpty else { return }
        isAgentWorking = true
        defer { isAgentWorking = false }
        do {
            let result = try runtime.approveOpeningPlan()
            apply(runtimeSnapshot: result.snapshot)
            status = result.status
        } catch {
            status = "Plan approval failed (AGENT-APPROVAL)"
        }
    }

    func sendAgentMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let runtime else {
            conversationMessages.append("You: " + text)
            conversationMessages.append("Agent: Database unavailable; no tool was executed.")
            draft = ""
            status = "Agent runtime unavailable"
            return
        }

        draft = ""
        isAgentWorking = true
        defer { isAgentWorking = false }
        do {
            let result = try runtime.handleUserMessage(text)
            apply(runtimeSnapshot: result.snapshot)
            status = result.status
        } catch {
            status = "Agent turn failed (AGENT-TURN)"
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
        planAwaitingApproval = snapshot.openingPlan?.status == "waitingApproval"
        lastToolReceipt = snapshot.lastReceipt
        latestAgentRun = snapshot.latestRun
    }

    func saveDraft() {
        guard let database else { return }
        do {
            try database.saveDraft(draft)
            status = "Draft saved: \(Date().formatted(date: .omitted, time: .standard))"
        } catch {
            status = "Draft save failed (DB-WRITE)"
        }
    }

    func createCheckpoint(reason: String) {
        guard let database else { return }
        do {
            let checkpoint = try database.checkpointDraft(
                content: draft,
                taskID: taskID,
                reason: reason,
                payloadHash: Self.payloadHash(for: draft)
            )
            status = "Saved checkpoint #\(checkpoint.sequence) (\(reason))"
        } catch {
            status = "Checkpoint write failed (DB-CHECKPOINT)"
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
            status = "Keychain test value cannot be empty"
            return
        }
        do {
            try keychain.save(apiKeyInput, account: "m0-probe")
            apiKeyInput = ""
            hasStoredKey = true
            status = "Saved test value in ThisDeviceOnly Keychain"
        } catch {
            status = "Keychain write failed (KEY-WRITE)"
        }
    }

    func deleteProbeKey() {
        do {
            try keychain.delete(account: "m0-probe")
            apiKeyInput = ""
            hasStoredKey = false
            status = "Keychain test value deleted"
        } catch {
            status = "Keychain delete failed (KEY-DELETE)"
        }
    }

    func startStreamingProbe() {
        streamTask?.cancel()
        let generation = UUID()
        streamGeneration = generation
        streamOutput = ""
        isStreaming = true
        status = "Connecting to HTTPS SSE..."

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
                self.status = "Streaming probe completed"
            } catch is CancellationError {
                guard self.streamGeneration == generation else { return }
                self.status = "Streaming probe cancelled"
            } catch let error as StreamingHTTPError {
                guard self.streamGeneration == generation else { return }
                self.status = error.errorDescription ?? "Streaming probe failed (NET-SSE)"
            } catch {
                guard self.streamGeneration == generation else { return }
                self.status = "Streaming probe failed (NET-SSE)"
            }

            guard self.streamGeneration == generation else { return }
            self.streamGeneration = nil
            self.streamTask = nil
            self.isStreaming = false
        }
    }

    private static func payloadHash(for text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func cancelStreamingProbe() {
        streamGeneration = nil
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        status = "Streaming probe cancelled"
    }
}
