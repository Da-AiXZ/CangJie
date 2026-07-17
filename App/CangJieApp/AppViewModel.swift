import CangJieCore
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

private struct AgentBusinessMilestone: Equatable {
    let projectIDs: [UUID]
    let focusedProjectID: UUID?
    let interviewStep: Int
    let interviewAnswerCount: Int
    let currentQuestion: String
    let approvalID: UUID?
    let approvalStatus: String?
    let approvalBindingHash: String?
    let chapterLogicalID: UUID?
    let chapterStage: String?
    let chapterVersionID: UUID?
    let chapterVersionHash: String?
    let chapterRevision: Int?
}

struct BuildIdentity: Equatable {
    let version: String
    let build: String
    let commit: String

    var displayText: String {
        "Version \(version) | Build \(build) | Commit \(commit)"
    }

    init(infoDictionary: [String: Any]?) {
        version = Self.nonEmptyString(
            forKeys: ["CFBundleShortVersionString"],
            in: infoDictionary
        ) ?? "unavailable"
        build = Self.nonEmptyString(
            forKeys: ["CFBundleVersion"],
            in: infoDictionary
        ) ?? "unavailable"
        let fullCommit = Self.nonEmptyString(
            forKeys: ["CangJieGitCommit"],
            in: infoDictionary
        )
        commit = fullCommit.map { String($0.prefix(12)) } ?? "unavailable"
    }

    private static func nonEmptyString(
        forKeys keys: [String],
        in infoDictionary: [String: Any]?
    ) -> String? {
        guard let infoDictionary else { return nil }
        for key in keys {
            guard let rawValue = infoDictionary[key] else { continue }
            let value = String(describing: rawValue)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }
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
    @Published private(set) var chapter: ChapterRuntimeSnapshot?

    var status: String { errorMessage ?? businessStatus }
    var chapterNeedsReview: Bool {
        chapter?.stage == .reviewingV1 || chapter?.stage == .reviewingV2
    }
    var chapterNeedsRewriteScopeApproval: Bool {
        chapter?.stage == .awaitingRewriteConfirmation
    }
    var chapterParagraphs: [String] {
        chapter.map { ChapterContentIntegrity.paragraphs(in: $0.activeVersion.body) } ?? []
    }
    let buildIdentity: BuildIdentity

    private static let maximumStreamOutputBytes = 256 * 1_024
    private let database: AppDatabase?
    private let runtime: AgentRuntime?
    private let keychain: any SecretRepository
    private let taskID: UUID
    private var streamTask: Task<Void, Never>?
    private var streamGeneration: UUID?
    private var noticeDismissTask: Task<Void, Never>?
    private var projectedBusinessMilestone: AgentBusinessMilestone?

    init(
        database: AppDatabase? = nil,
        databaseFactory: () throws -> AppDatabase = { try AppDatabase.makeDefault() },
        keychain: any SecretRepository = KeychainSecretRepository(),
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) {
        self.keychain = keychain
        buildIdentity = BuildIdentity(infoDictionary: bundleInfo)
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
                message: "Projects refreshed | \(refreshedProjects.count) \(noun) | \(Date().formatted(date: .omitted, time: .standard))"
            )
        } catch {
            publishError("Project list failed (DB-PROJECT-LIST)")
        }
    }

    @discardableResult
    func approveOpeningPlan(requestID: UUID, displayedBindingHash: String) -> Bool {
        guard let runtime,
              let displayed = openingPlanApproval,
              displayed.id == requestID,
              displayed.bindingHash == displayedBindingHash,
              displayed.status == .pending,
              !planBody.isEmpty else {
            businessStatus = "Opening plan changed; review the latest approval card"
            publishError("Displayed approval is no longer current (AGENT-APPROVAL-STALE)")
            return false
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
            return openingPlanApproval?.id == requestID
                && openingPlanApproval?.bindingHash == displayedBindingHash
                && openingPlanApproval?.status == .approved
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
            return false
        } catch {
            publishError("Plan approval failed (AGENT-APPROVAL)")
            return false
        }
    }

    func setChapterParagraphLocked(
        _ paragraphIndex: Int,
        locked: Bool,
        versionID: UUID,
        displayedContentHash: String
    ) {
        guard let database,
              let runtime,
              let current = exactDisplayedChapter(
                versionID: versionID,
                displayedContentHash: displayedContentHash,
                allowedStages: [.reviewingV1, .reviewingV2]
              ) else { return }
        guard chapterParagraphs.indices.contains(paragraphIndex) else {
            publishError("Chapter paragraph is no longer available (CHAPTER-PARAGRAPH)")
            return
        }

        let sourceIndexes = current.calibration.lockedParagraphIndexes
        var target = Set(sourceIndexes)
        if locked {
            target.insert(paragraphIndex)
        } else {
            target.remove(paragraphIndex)
        }
        let targetIndexes = target.sorted()
        guard targetIndexes != sourceIndexes else { return }

        let transitionBinding = Self.payloadHash(
            for: [
                versionID.uuidString,
                displayedContentHash,
                sourceIndexes.map(String.init).joined(separator: ","),
                targetIndexes.map(String.init).joined(separator: ",")
            ].joined(separator: "|")
        )
        let idempotencyKey = [
            "chapter.lockParagraph.set",
            versionID.uuidString,
            transitionBinding
        ].joined(separator: ".")

        isAgentWorking = true
        defer { isAgentWorking = false }
        do {
            _ = try database.executeChapterLockParagraphSetTool(
                conversationID: current.calibration.conversationID,
                projectID: current.calibration.projectID,
                versionID: versionID,
                displayedContentHash: displayedContentHash,
                lockedParagraphIndexes: targetIndexes,
                idempotencyKey: idempotencyKey
            )
            let snapshot = try runtime.restore()
            apply(runtimeSnapshot: snapshot)
            businessStatus = locked
                ? "Chapter 1 paragraph \(paragraphIndex + 1) locked"
                : "Chapter 1 paragraph \(paragraphIndex + 1) unlocked"
        } catch let error as AppDatabaseError {
            handleChapterError(error, operation: "lock paragraph")
            restoreRuntimeProjection()
        } catch {
            publishError("Chapter paragraph lock failed (CHAPTER-LOCK)")
            restoreRuntimeProjection()
        }
    }

    @discardableResult
    func acceptChapter(versionID: UUID, displayedContentHash: String) -> Bool {
        guard exactDisplayedChapter(
            versionID: versionID,
            displayedContentHash: displayedContentHash,
            allowedStages: [.reviewingV1, .reviewingV2]
        ) != nil else { return false }
        guard let snapshot = performChapterAgentCommand("accept and freeze"),
              let projected = snapshot.chapter,
              projected.activeVersion.id == versionID,
              projected.activeVersion.contentHash == displayedContentHash,
              projected.stage == .approvedFrozen,
              projected.calibration.acceptedVersionID == versionID else {
            publishError("Chapter acceptance was not confirmed by the persisted projection (CHAPTER-PROJECTION)")
            restoreRuntimeProjection()
            return false
        }
        return true
    }

    @discardableResult
    func rejectChapter(
        reason: String,
        versionID: UUID,
        displayedContentHash: String
    ) -> Bool {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            publishError("A concrete rejection reason is required (CHAPTER-REJECT-REASON)")
            return false
        }
        guard exactDisplayedChapter(
            versionID: versionID,
            displayedContentHash: displayedContentHash,
            allowedStages: [.reviewingV1]
        ) != nil else { return false }
        guard let snapshot = performChapterAgentCommand("reject: " + trimmedReason),
              let projected = snapshot.chapter,
              projected.activeVersion.id == versionID,
              projected.activeVersion.contentHash == displayedContentHash,
              projected.stage == .diagnosing,
              projected.calibration.rejectionHistory.last?.versionID == versionID,
              projected.calibration.rejectionHistory.last?.versionHash == displayedContentHash else {
            publishError("Chapter rejection was not confirmed by the persisted projection (CHAPTER-PROJECTION)")
            restoreRuntimeProjection()
            return false
        }
        return true
    }

    @discardableResult
    func confirmChapterRewrite(
        sourceVersionID: UUID,
        displayedSourceHash: String,
        rewriteScopeHash: String
    ) -> Bool {
        guard let current = exactDisplayedChapter(
            versionID: sourceVersionID,
            displayedContentHash: displayedSourceHash,
            allowedStages: [.awaitingRewriteConfirmation]
        ), current.calibration.rewriteScopeHash == rewriteScopeHash else {
            publishError("Displayed rewrite scope is no longer current (CHAPTER-STALE)")
            restoreRuntimeProjection()
            return false
        }
        guard let snapshot = performChapterAgentCommand("confirm rewrite"),
              let projected = snapshot.chapter,
              projected.stage == .reviewingV2,
              projected.activeVersion.parentVersionID == sourceVersionID,
              projected.activeVersion.revision == current.activeVersion.revision + 1 else {
            publishError("Chapter rewrite was not confirmed by the persisted projection (CHAPTER-PROJECTION)")
            restoreRuntimeProjection()
            return false
        }
        return true
    }

    func sendAgentMessage() {
        guard draft.utf8.count < AgentRuntime.maximumInputUTF8Bytes else {
            publishError("Agent input is too large (AGENT-INPUT-LIMIT)")
            return
        }
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
        chapter = snapshot.chapter
        projectedBusinessMilestone = Self.businessMilestone(for: snapshot)
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
                message: "Draft saved | \(Date().formatted(date: .omitted, time: .standard))"
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
            restoreRuntimeProjection()
        @unknown default:
            createCheckpoint(reason: "sceneUnknown")
        }
    }

    private func restoreRuntimeProjection() {
        guard let runtime else { return }
        do {
            let snapshot = try runtime.restore()
            let restoredMilestone = Self.businessMilestone(for: snapshot)
            let milestoneChanged = projectedBusinessMilestone != restoredMilestone
            apply(runtimeSnapshot: snapshot)
            if milestoneChanged {
                businessStatus = Self.businessStatus(for: snapshot)
            }
        } catch {
#if DEBUG
            print("Agent runtime projection restore failed:", error)
#endif
            publishError("Agent restore failed (AGENT-RESTORE)")
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

    private func exactDisplayedChapter(
        versionID: UUID,
        displayedContentHash: String,
        allowedStages: [ChapterCalibrationStage]
    ) -> ChapterRuntimeSnapshot? {
        guard let current = chapter,
              current.activeVersion.id == versionID,
              current.activeVersion.contentHash == displayedContentHash,
              allowedStages.contains(current.stage) else {
            publishError("Displayed chapter revision is no longer current (CHAPTER-STALE)")
            restoreRuntimeProjection()
            return nil
        }
        return current
    }

    private func performChapterAgentCommand(_ command: String) -> AgentRuntimeSnapshot? {
        guard let runtime else {
            publishError("Agent runtime unavailable")
            return nil
        }
        isAgentWorking = true
        defer { isAgentWorking = false }
        do {
            let result = try runtime.handleUserMessage(command)
            apply(runtimeSnapshot: result.snapshot)
            businessStatus = result.status
            return result.snapshot
        } catch let error as AppDatabaseError {
#if DEBUG
            print("Chapter operation failed [chapter command]:", error)
#endif
            handleChapterError(error, operation: "chapter command")
            restoreRuntimeProjection()
            return nil
        } catch {
#if DEBUG
            print("Chapter operation failed [chapter command]:", error)
#endif
            publishError("Chapter command failed (CHAPTER-COMMAND)")
            restoreRuntimeProjection()
            return nil
        }
    }

    private func handleChapterError(_ error: AppDatabaseError, operation: String) {
        switch error {
        case .chapterBindingMismatch, .idempotencyConflict:
            publishError("Displayed chapter revision is stale (CHAPTER-STALE)")
        case .invalidChapterParagraphIndex:
            publishError("Chapter paragraph index is invalid (CHAPTER-PARAGRAPH)")
        case .chapterOperationNotAllowed:
            publishError("Chapter operation is not allowed in the current stage (CHAPTER-STAGE)")
        case .chapterLockedContentChanged:
            publishError("Locked chapter content changed; rewrite stopped (CHAPTER-LOCK-INTEGRITY)")
        default:
            publishError("Failed to \(operation) (CHAPTER-TOOL)")
        }
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

    private static func businessMilestone(for snapshot: AgentRuntimeSnapshot) -> AgentBusinessMilestone {
        AgentBusinessMilestone(
            projectIDs: snapshot.projects.map { $0.id },
            focusedProjectID: snapshot.session.focusedProjectID,
            interviewStep: snapshot.session.interviewStep,
            interviewAnswerCount: snapshot.session.interviewAnswers.count,
            currentQuestion: snapshot.session.currentQuestion,
            approvalID: snapshot.openingPlanApproval?.id,
            approvalStatus: snapshot.openingPlanApproval?.status.rawValue,
            approvalBindingHash: snapshot.openingPlanApproval?.bindingHash,
            chapterLogicalID: snapshot.chapter?.calibration.chapterLogicalID,
            chapterStage: snapshot.chapter?.stage.rawValue,
            chapterVersionID: snapshot.chapter?.activeVersion.id,
            chapterVersionHash: snapshot.chapter?.activeVersion.contentHash,
            chapterRevision: snapshot.chapter?.activeVersion.revision
        )
    }

    private static func businessStatus(for snapshot: AgentRuntimeSnapshot) -> String {
        if let chapter = snapshot.chapter {
            switch chapter.stage {
            case .notStarted:
                return "Opening plan approved; Chapter 1 generation ready"
            case .reviewingV1, .reviewingV2:
                return "Chapter 1 revision \(chapter.activeVersion.revision) awaiting review"
            case .diagnosing:
                return "Chapter 1 diagnosis in progress"
            case .awaitingRewriteConfirmation:
                return "Waiting for exact rewrite-scope confirmation"
            case .rewriting:
                return "Chapter 1 rewrite in progress"
            case .approvedFrozen:
                return "Chapter 1 approved and frozen"
            }
        }

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
