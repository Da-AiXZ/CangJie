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

@MainActor
final class AppViewModel: ObservableObject {
    @Published var draft = "" {
        didSet {
            persistDraftChange()
        }
    }
    @Published private(set) var businessStatus = "正在准备…"
    @Published private(set) var transientNotice: TransientNotice?
    @Published private(set) var diagnosticNoticeMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var diagnosticErrorMessage: String?
    @Published var apiKeyInput = ""
    @Published private(set) var hasStoredKey = false
    @Published private(set) var keychainProbeDigest: String?
    @Published private(set) var isolationCanaryDigest: String?
    @Published private(set) var isolationCanaryPresent = false
    @Published var streamURL = ""
    @Published var streamOutput = ""
    @Published var isStreaming = false
    @Published private(set) var projects: [NovelProject] = []
    @Published private(set) var novelProgressByProjectID: [UUID: String] = [:]
    @Published var isArtifactDrawerPresented = false
    @Published var conversationMessages: [String] = []
    @Published private(set) var hasEarlierConversationMessages = false
    @Published private(set) var conversations: [AgentConversation] = []
    @Published private(set) var selectedConversationID: UUID?
    @Published private(set) var readableContent: S1ReadableContentProjection?
    @Published var isAgentWorking = false
    @Published private(set) var interviewQuestion = AgentRuntime.interviewQuestions[0]
    @Published private(set) var planBody = ""
    @Published private(set) var planAwaitingApproval = false
    @Published private(set) var openingPlanApproval: ApprovalRequest?
    @Published private(set) var interviewStep = 0
    @Published private(set) var lastToolReceipt: ToolReceipt?
    @Published private(set) var latestAgentRun: AgentRunSnapshot?
    @Published private(set) var chapter: ChapterRuntimeSnapshot?
    @Published private(set) var buildActivationMessage = "Checking executable identity..."
    @Published private(set) var buildIdentity: BuildIdentity

    private enum ErrorDomain: CaseIterable {
        case persistent
        case composer
    }

    private var errorMessagesByDomain: [ErrorDomain: String] = [:]

    var status: String { errorMessage ?? businessStatus }
    var isAgentExecutionAllowed: Bool { buildIdentity.isAgentExecutionAllowed }
    var isComposerAvailable: Bool {
        database != nil && lifecyclePermitsMutations && isAgentExecutionAllowed
    }
    var hasReadableContent: Bool { readableContent != nil }
    var chapterNeedsReview: Bool {
        chapter?.stage == .reviewingV1 || chapter?.stage == .reviewingV2
    }
    var chapterNeedsRewriteScopeApproval: Bool {
        chapter?.stage == .awaitingRewriteConfirmation
    }
    var chapterParagraphs: [String] {
        chapter.map { ChapterContentIntegrity.paragraphs(in: $0.activeVersion.body) } ?? []
    }
    private static let maximumStreamOutputBytes = 256 * 1_024
    private static let maximumProbeSecretBytes = 4_096
    private static let probeAccount = "m0-probe"
    private let database: AppDatabase?
    private var runtime: AgentRuntime?
    private let keychain: any SecretRepository
    private let isolationCanaryRepository: any IsolationCanaryRepository
    private let buildActivationStore: any BuildActivationStore
    private let compiledBuildStamp: BuildIdentityStamp
    private let bundleIdentityLoader: any BundleBuildIdentityLoading
    private let executionAuthorizer: BuildActivationAgentAuthorizer
    private let taskID: UUID
    private var streamTask: Task<Void, Never>?
    private var streamGeneration: UUID?
    private var noticeDismissTask: Task<Void, Never>?
    private var projectedBusinessMilestone: AgentBusinessMilestone?
    private var lifecyclePermitsMutations = true
    private var isDraftAutosaveSuppressed = false
    private let draftAutosaveDelayNanoseconds: UInt64
    private var draftAutosaveTask: Task<Void, Never>?
    private var pendingDraftAutosave: S1DraftAutosaveContract.Request?
    private var draftAutosaveGeneration: UInt64 = 0

    init(
        database: AppDatabase? = nil,
        databaseFactory: () throws -> AppDatabase = { try AppDatabase.makeDefault() },
        keychain: any SecretRepository = KeychainSecretRepository(),
        isolationCanaryRepository: any IsolationCanaryRepository = KeychainIsolationCanaryRepository(),
        bundleInfo: [String: Any]? = BuildIdentityStamp.generated.infoDictionary,
        compiledBuildStamp: BuildIdentityStamp = .generated,
        buildActivationStore: any BuildActivationStore = UserDefaultsBuildActivationStore(),
        bundleIdentityLoader: (any BundleBuildIdentityLoading)? = nil,
        taskID suppliedTaskID: UUID? = nil,
        draftAutosaveDelayNanoseconds: UInt64 = 350_000_000
    ) {
        self.keychain = keychain
        self.isolationCanaryRepository = isolationCanaryRepository
        self.buildActivationStore = buildActivationStore
        self.compiledBuildStamp = compiledBuildStamp
        self.draftAutosaveDelayNanoseconds = draftAutosaveDelayNanoseconds
        let resolvedLoader = bundleIdentityLoader
            ?? StaticBundleBuildIdentityLoader(infoDictionary: bundleInfo)
        self.bundleIdentityLoader = resolvedLoader
        let initialIdentity = BuildIdentity(
            infoDictionary: resolvedLoader.loadInfoDictionary(),
            compiled: compiledBuildStamp
        )
        buildIdentity = initialIdentity
        let authorizer = BuildActivationAgentAuthorizer(
            compiledBuildStamp: compiledBuildStamp,
            bundleIdentityLoader: resolvedLoader,
            allowed: initialIdentity.isAgentExecutionAllowed
        )
        executionAuthorizer = authorizer

        if let suppliedTaskID {
            taskID = suppliedTaskID
        } else {
            let defaultsKey = "m0TaskID"
            if let stored = UserDefaults.standard.string(forKey: defaultsKey),
               let id = UUID(uuidString: stored) {
                taskID = id
            } else {
                let id = UUID()
                taskID = id
                UserDefaults.standard.set(id.uuidString, forKey: defaultsKey)
            }
        }

        let emptyWorkspace = S1ConversationWorkspaceSnapshot(
            selectedConversation: nil,
            conversations: [],
            draft: "",
            messageWindow: S1PreviewMessageWindow(messages: [], hasEarlierMessages: false)
        )
        let databaseState: (
            database: AppDatabase?,
            workspace: S1ConversationWorkspaceSnapshot,
            projects: [NovelProject],
            novelProgressByProjectID: [UUID: String],
            readableContent: S1ReadableContentProjection?,
            notice: String?,
            error: String?
        )
        if !initialIdentity.isAgentExecutionAllowed {
            databaseState = (nil, emptyWorkspace, [], [:], nil, nil, nil)
        } else {
            do {
                let resolved = try database ?? databaseFactory()
                let workspace = try resolved.restoreS1ConversationWorkspace()
                let projects = try resolved.listProjects()
                let progressResult: ([UUID: String], String?)
                do {
                    progressResult = (
                        Self.progressDescriptions(from: try resolved.loadS1NovelProgressFacts()),
                        nil
                    )
                } catch {
                    progressResult = ([:], "Novel progress restore failed (DB-NOVEL-PROGRESS)")
                }
                let readableContent = try resolved.restoreS1ReadableContent(
                    selectedConversationID: workspace.selectedConversation?.id
                )
                let restoredNotice: String
                if let checkpoint = try resolved.latestS1ConversationCheckpoint(
                    taskID: taskID,
                    selectedConversationID: workspace.selectedConversation?.id
                ) {
                    restoredNotice = Self.payloadHash(for: workspace.draft) == checkpoint.payloadHash
                        ? "Restored checkpoint #\(checkpoint.sequence)"
                        : "Draft is newer than the latest checkpoint"
                } else {
                    restoredNotice = "SQLite ready; no checkpoint yet"
                }
                databaseState = (
                    resolved,
                    workspace,
                    projects,
                    progressResult.0,
                    readableContent,
                    restoredNotice,
                    progressResult.1
                )
            } catch {
                databaseState = (nil, emptyWorkspace, [], [:], nil, nil, "SQLite initialization failed (DB-INIT)")
            }
        }

        self.database = databaseState.database
        runtime = nil
        selectedConversationID = databaseState.workspace.selectedConversation?.id
        conversations = databaseState.workspace.conversations
        draft = databaseState.workspace.draft
        conversationMessages = databaseState.workspace.messageWindow.messages.map(\.displayText)
        hasEarlierConversationMessages = databaseState.workspace.messageWindow.hasEarlierMessages
        projects = databaseState.projects
        novelProgressByProjectID = databaseState.novelProgressByProjectID
        readableContent = databaseState.readableContent
        diagnosticErrorMessage = databaseState.error
        errorMessage = databaseState.error.map { S1OrdinarySurfaceContract.errorDescription(for: $0) }
        if let databaseError = databaseState.error {
            errorMessagesByDomain[.persistent] = databaseError
        }

        if buildIdentity.isAgentExecutionAllowed {
            let token = compiledBuildStamp.activationToken
            let wasAlreadyActivated = buildActivationStore.loadActivatedToken() == token
            buildActivationStore.saveActivatedToken(token)
            buildActivationMessage = wasAlreadyActivated
                ? "Executable identity verified."
                : "New executable activated: Build \(compiledBuildStamp.build), commit \(compiledBuildStamp.commit)."
        } else {
            buildActivationMessage = buildIdentity.diagnosticText
        }

        if databaseState.database != nil {
            businessStatus = "当前只验证界面、导航和本地保存，尚未接入真正的模型任务"
        } else {
            businessStatus = buildIdentity.isAgentExecutionAllowed
                ? "暂时无法打开对话"
                : "这个版本还没有完全启用，暂时不能改动内容"
        }

        if let notice = databaseState.notice {
            publishTransientNotice(kind: .storage, message: notice)
        }

        if buildIdentity.isAgentExecutionAllowed {
            refreshProbeState(publishSuccess: false)
            refreshIsolationCanary(publishSuccess: false)
        }
    }

    func reloadProjects() {
        guard let database else {
            publishError("Project list failed (DB-PROJECT-LIST)")
            return
        }
        do {
            let refreshedProjects = try database.listProjects()
            let refreshedProgress = Self.progressDescriptions(
                from: try database.loadS1NovelProgressFacts()
            )
            projects = refreshedProjects
            novelProgressByProjectID = refreshedProgress
            publishTransientNotice(
                kind: .projectRefresh,
                message: "书架已刷新 | \(refreshedProjects.count) 本小说 | \(Date().formatted(date: .omitted, time: .standard))"
            )
        } catch {
            publishError("Project list failed (DB-PROJECT-LIST)")
        }
    }

    func readableContentForBrowsing(
        projectID: UUID
    ) -> S1ReadableContentProjection? {
        guard let database else {
            publishError("Project reader failed (DB-PROJECT-READER)")
            return nil
        }
        do {
            return try database.loadS1ReadableContent(projectID: projectID)
        } catch {
            publishError("Project reader failed (DB-PROJECT-READER)")
            return nil
        }
    }

    @discardableResult
    func approveOpeningPlan(requestID: UUID, displayedBindingHash: String) -> Bool {
        guard requireActiveBuildForAgentMutation() else { return false }
        guard let runtime,
              let displayed = openingPlanApproval,
              displayed.id == requestID,
              displayed.bindingHash == displayedBindingHash,
              displayed.status == .pending,
              !planBody.isEmpty else {
            businessStatus = S1OrdinarySurfaceContract.progressDescription(.openingPlanChanged)
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
            businessStatus = Self.businessStatus(for: result.snapshot)
            return openingPlanApproval?.id == requestID
                && openingPlanApproval?.bindingHash == displayedBindingHash
                && openingPlanApproval?.status == .approved
        } catch let error as AppDatabaseError {
            switch error {
            case .approvalRequiresReapproval:
                businessStatus = S1OrdinarySurfaceContract.progressDescription(.openingPlanChanged)
                publishError("Displayed approval is stale (AGENT-APPROVAL-STALE)")
            case .approvalExpired:
                businessStatus = S1OrdinarySurfaceContract.progressDescription(.openingPlanExpired)
                publishError("Plan approval expired (AGENT-APPROVAL-EXPIRED)")
            case .approvalBudgetExceeded:
                businessStatus = "本次操作已暂停，请先检查费用设置"
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
        guard requireActiveBuildForAgentMutation() else { return }
        do {
            try executionAuthorizer.authorize(.chapterParagraphLock)
        } catch {
            publishError("Running executable identity is not active (BUILD-ACTIVATION)")
            return
        }
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
        guard requireActiveBuildForAgentMutation() else { return false }
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
        guard requireActiveBuildForAgentMutation() else { return false }
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
        guard requireActiveBuildForAgentMutation() else { return false }
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
        guard requireActiveBuildForAgentMutation() else { return }
        guard ensureRuntimeAvailable(), let runtime else { return }

        draft = ""
        isAgentWorking = true
        defer { isAgentWorking = false }
        do {
            let result = try runtime.handleUserMessage(text)
            apply(runtimeSnapshot: result.snapshot)
            businessStatus = Self.businessStatus(for: result.snapshot)
        } catch {
            publishError("Agent turn failed (AGENT-TURN)")
        }
    }

    func sendS1PreviewMessage() {
        let turn: S1ConversationPreviewTurn
        do {
            turn = try S1ConversationPreview.makeTurn(from: draft)
        } catch S1ConversationPreviewError.emptyInput {
            return
        } catch S1ConversationPreviewError.inputTooLarge {
            publishError("消息太长，尚未发送（S1-INPUT-LIMIT）", domain: .composer)
            return
        } catch S1ConversationPreviewError.unsafeDirectionalControl {
            publishError("消息包含会改变文字显示方向的控制字符，尚未发送（S1-INPUT-DIRECTION）", domain: .composer)
            return
        } catch {
            publishError("消息无法保存（S1-INPUT）", domain: .composer)
            return
        }

        guard requireActiveBuildForAgentMutation() else { return }
        guard flushPendingDraftAutosave() else { return }
        guard let database else {
            publishError("消息无法保存（DB-WRITE）", domain: .composer)
            return
        }

        isAgentWorking = true
        defer { isAgentWorking = false }
        do {
            let result = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: selectedConversationID,
                turn: turn
            )
            guard let workspace = result.workspace else {
                throw AppDatabaseError.invalidAgentSession
            }
            applyS1ConversationWorkspace(workspace)
            clearErrors(in: .composer)
            businessStatus = S1ConversationPreview.systemReceipt
        } catch {
            publishError("消息无法保存（S1-SAVE）", domain: .composer)
        }
    }

    func startNewS1Conversation() {
        guard requireActiveBuildForMutation(.durableMutation) else { return }
        guard flushPendingDraftAutosave() else { return }
        guard let database else {
            publishError("Conversation selection failed (S1-SELECT)")
            return
        }
        do {
            applyS1ConversationWorkspace(try database.selectNewS1Conversation())
        } catch {
            publishError("Conversation selection failed (S1-SELECT)")
        }
    }

    func selectS1Conversation(_ conversationID: UUID) {
        guard requireActiveBuildForMutation(.durableMutation) else { return }
        guard flushPendingDraftAutosave() else { return }
        guard let database else {
            publishError("Conversation selection failed (S1-SELECT)")
            return
        }
        do {
            applyS1ConversationWorkspace(try database.selectS1Conversation(conversationID))
        } catch {
            publishError("Conversation selection failed (S1-SELECT)")
        }
    }

    private func applyS1ConversationWorkspace(_ workspace: S1ConversationWorkspaceSnapshot) {
        selectedConversationID = workspace.selectedConversation?.id
        conversations = workspace.conversations
        conversationMessages = workspace.messageWindow.messages.map(\.displayText)
        hasEarlierConversationMessages = workspace.messageWindow.hasEarlierMessages
        setDraftWithoutAutosave(workspace.draft)
        refreshS1ReadableContent()
    }

    private static func progressDescriptions(
        from factsByProjectID: [UUID: S1NovelProgressFacts]
    ) -> [UUID: String] {
        factsByProjectID.mapValues(S1NovelProgressProjection.description(for:))
    }

    private func refreshS1NovelProgress() {
        guard let database else {
            novelProgressByProjectID = [:]
            return
        }
        do {
            novelProgressByProjectID = Self.progressDescriptions(
                from: try database.loadS1NovelProgressFacts()
            )
        } catch {
            novelProgressByProjectID = [:]
            publishError("Novel progress restore failed (DB-NOVEL-PROGRESS)")
        }
    }

    private func refreshS1ReadableContent() {
        guard let database else {
            readableContent = nil
            return
        }
        do {
            readableContent = try database.restoreS1ReadableContent(
                selectedConversationID: selectedConversationID
            )
        } catch {
            readableContent = nil
            publishError("Readable chapter restore failed (DB-CHAPTER-READ)")
        }
    }

    private func requireActiveBuildForMutation(
        _ operation: GovernedAgentOperation = .durableMutation
    ) -> Bool {
        guard lifecyclePermitsMutations else { return false }
        guard revalidateBuildActivation() else { return false }
        do {
            try executionAuthorizer.authorize(operation)
            return true
        } catch {
            _ = revalidateBuildActivation()
            return false
        }
    }

    private func requireActiveBuildForAgentMutation() -> Bool {
        requireActiveBuildForMutation(.agentTurn)
    }

    private func apply(runtimeSnapshot snapshot: AgentRuntimeSnapshot) {
        conversationMessages = snapshot.messages.map(\.displayText)
        projects = snapshot.projects
        refreshS1NovelProgress()
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

    private func persistDraftChange() {
        guard !isDraftAutosaveSuppressed, lifecyclePermitsMutations, database != nil else { return }
        guard draft.utf8.count <= S1ConversationPreview.maximumDraftUTF8Bytes else {
            invalidatePendingDraftAutosave()
            publishError("草稿太长，当前修改尚未自动保存（S1-DRAFT-LIMIT）", domain: .composer)
            return
        }
        cancelDraftAutosaveTimer()
        let request = S1DraftAutosaveContract.makeRequest(
            content: draft,
            selectedConversationID: selectedConversationID,
            after: draftAutosaveGeneration
        )
        draftAutosaveGeneration = request.generation
        pendingDraftAutosave = request
        guard revalidateBuildActivation() else { return }
        let delay = draftAutosaveDelayNanoseconds
        draftAutosaveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            self.draftAutosaveTask = nil
            _ = self.persistDraftAutosave(request)
        }
    }

    @discardableResult
    private func persistDraftAutosave(
        _ request: S1DraftAutosaveContract.Request,
        failureMessage: String = "Draft autosave failed (DB-DRAFT-AUTOSAVE)"
    ) -> Bool {
        guard let database, pendingDraftAutosave == request else { return false }
        guard S1DraftAutosaveContract.canPersist(
            request,
            currentContent: draft,
            currentSelectedConversationID: selectedConversationID,
            currentGeneration: draftAutosaveGeneration,
            lifecyclePermitsMutations: lifecyclePermitsMutations,
            buildIsActive: buildIdentity.isAgentExecutionAllowed
        ) else { return false }
        guard revalidateBuildActivation() else { return false }
        guard S1DraftAutosaveContract.canPersist(
            request,
            currentContent: draft,
            currentSelectedConversationID: selectedConversationID,
            currentGeneration: draftAutosaveGeneration,
            lifecyclePermitsMutations: lifecyclePermitsMutations,
            buildIsActive: buildIdentity.isAgentExecutionAllowed
        ) else { return false }

        do {
            try executionAuthorizer.performAuthorized(.durableMutation) {
                try database.saveS1ConversationDraft(
                    request.content,
                    selectedConversationID: request.selectedConversationID
                )
            }
            if pendingDraftAutosave == request {
                pendingDraftAutosave = nil
                cancelDraftAutosaveTimer()
            }
            return true
        } catch AppDatabaseError.draftInputLimitExceeded {
            publishError("草稿太长，当前修改尚未自动保存（S1-DRAFT-LIMIT）", domain: .composer)
        } catch AgentExecutionAuthorizationError.buildNotActive {
            _ = revalidateBuildActivation()
        } catch {
            publishError(failureMessage)
        }
        return false
    }

    @discardableResult
    private func flushPendingDraftAutosave() -> Bool {
        cancelDraftAutosaveTimer()
        guard let request = pendingDraftAutosave else { return true }
        return persistDraftAutosave(request)
    }

    private func stageCurrentDraftForImmediateSave() -> S1DraftAutosaveContract.Request? {
        guard draft.utf8.count <= S1ConversationPreview.maximumDraftUTF8Bytes else {
            invalidatePendingDraftAutosave()
            publishError("草稿太长，当前修改尚未自动保存（S1-DRAFT-LIMIT）", domain: .composer)
            return nil
        }
        cancelDraftAutosaveTimer()
        let request = S1DraftAutosaveContract.makeRequest(
            content: draft,
            selectedConversationID: selectedConversationID,
            after: draftAutosaveGeneration
        )
        draftAutosaveGeneration = request.generation
        pendingDraftAutosave = request
        return request
    }

    private func cancelDraftAutosaveTimer() {
        draftAutosaveTask?.cancel()
        draftAutosaveTask = nil
    }

    private func invalidatePendingDraftAutosave() {
        cancelDraftAutosaveTimer()
        pendingDraftAutosave = nil
        draftAutosaveGeneration &+= 1
    }

    private func setDraftWithoutAutosave(_ value: String) {
        invalidatePendingDraftAutosave()
        isDraftAutosaveSuppressed = true
        defer { isDraftAutosaveSuppressed = false }
        draft = value
    }

    func saveDraft() {
        guard requireActiveBuildForMutation(.durableMutation) else { return }
        guard database != nil else {
            publishError("Draft save failed (DB-WRITE)")
            return
        }
        guard let request = stageCurrentDraftForImmediateSave() else { return }
        guard persistDraftAutosave(
            request,
            failureMessage: "Draft save failed (DB-WRITE)"
        ) else { return }
        publishTransientNotice(
            kind: .storage,
            message: "Draft saved | \(Date().formatted(date: .omitted, time: .standard))"
        )
    }

    func createCheckpoint(reason: String) {
        guard requireActiveBuildForMutation(.durableMutation) else { return }
        cancelDraftAutosaveTimer()
        guard let database else {
            publishError("Checkpoint write failed (DB-CHECKPOINT)")
            return
        }
        do {
            let checkpoint = try database.checkpointS1ConversationDraft(
                content: draft,
                selectedConversationID: selectedConversationID,
                taskID: taskID,
                reason: reason,
                payloadHash: Self.payloadHash(for: draft)
            )
            invalidatePendingDraftAutosave()
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
            suspendGovernedWork(reason: "sceneInactive")
        case .background:
            suspendGovernedWork(reason: "sceneBackground")
        case .active:
            lifecyclePermitsMutations = true
            guard revalidateBuildActivation() else { return }
            guard flushPendingDraftAutosave() else { return }
            restoreS1PreviewProjection()
            refreshProbeState(publishSuccess: false)
            refreshIsolationCanary(publishSuccess: false)
        @unknown default:
            suspendGovernedWork(reason: "sceneUnknown")
        }
    }

    private func suspendGovernedWork(reason: String) {
        pauseGovernedWork()
        cancelDraftAutosaveTimer()
        guard lifecyclePermitsMutations else {
            executionAuthorizer.update(allowed: false)
            return
        }
        defer {
            lifecyclePermitsMutations = false
            executionAuthorizer.update(allowed: false)
        }
        guard revalidateBuildActivation() else { return }
        createCheckpoint(reason: reason)
    }

    private func pauseGovernedWork() {
        cancelDraftAutosaveTimer()
        streamGeneration = nil
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        isAgentWorking = false
    }

    @discardableResult
    private func revalidateBuildActivation() -> Bool {
        let refreshed = BuildIdentity(
            infoDictionary: bundleIdentityLoader.loadInfoDictionary(),
            compiled: compiledBuildStamp
        )
        buildIdentity = refreshed
        executionAuthorizer.update(
            allowed: refreshed.isAgentExecutionAllowed && lifecyclePermitsMutations
        )
        guard refreshed.isAgentExecutionAllowed else {
            pauseGovernedWork()
            clearCachedSecurityEvidence()
            buildActivationMessage = refreshed.diagnosticText
            businessStatus = "这个版本还没有完全启用，暂时不能改动内容"
            publishError("Running executable identity does not match the installed bundle (BUILD-ACTIVATION)")
            return false
        }

        let token = compiledBuildStamp.activationToken
        if buildActivationStore.loadActivatedToken() != token {
            buildActivationStore.saveActivatedToken(token)
            buildActivationMessage = "New executable activated: Build \(compiledBuildStamp.build), commit \(compiledBuildStamp.commit)."
        } else {
            buildActivationMessage = "Executable identity verified."
        }
        return true
    }


    private func restoreS1PreviewProjection() {
        guard let database else { return }
        do {
            let workspace = try database.restoreS1ConversationWorkspace()
            applyS1ConversationWorkspace(workspace)
            projects = try database.listProjects()
            refreshS1NovelProgress()
            planBody = ""
            planAwaitingApproval = false
            openingPlanApproval = nil
            interviewStep = 0
            lastToolReceipt = nil
            latestAgentRun = nil
            chapter = nil
            projectedBusinessMilestone = nil
            businessStatus = "对话和草稿已恢复。当前只验证界面、导航和本地保存，尚未接入真正的模型任务"
        } catch {
            publishError("Conversation restore failed (S1-RESTORE)")
        }
    }

    private func ensureRuntimeAvailable() -> Bool {
        if runtime != nil { return true }
        guard let database else {
            publishError("Agent runtime unavailable (AGENT-INIT)")
            return false
        }
        do {
            runtime = try AgentRuntime(database: database, authorizer: executionAuthorizer)
            return true
        } catch {
            runtime = nil
            _ = revalidateBuildActivation()
            publishError("Agent runtime initialization failed (AGENT-INIT)")
            return false
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
        guard requireActiveBuildForMutation(.diagnosticsKeychainMutation) else { return }
        let candidate = apiKeyInput
        guard !candidate.isEmpty else {
            publishError("Keychain test value cannot be empty")
            return
        }
        guard candidate.utf8.count <= Self.maximumProbeSecretBytes else {
            publishError("Keychain test value exceeds 4096 UTF-8 bytes")
            return
        }
        do {
            try keychain.save(candidate, account: Self.probeAccount)
            guard try keychain.read(account: Self.probeAccount) == candidate else {
                publishError("Keychain read-after-write verification failed (KEY-VERIFY)")
                return
            }
            apiKeyInput = ""
            hasStoredKey = true
            keychainProbeDigest = Self.probeDigest(for: candidate)
            publishTransientNotice(
                kind: .storage,
                message: "Keychain create/update and read-back verified"
            )
        } catch {
            publishError("Keychain write failed (KEY-WRITE)")
        }
    }

    func readProbeKey() {
        guard requireActiveBuildForMutation(.diagnosticsKeychainMutation) else { return }
        refreshProbeState(publishSuccess: true)
    }

    func deleteProbeKey() {
        guard requireActiveBuildForMutation(.diagnosticsKeychainMutation) else { return }
        do {
            try keychain.delete(account: Self.probeAccount)
            guard try keychain.read(account: Self.probeAccount) == nil else {
                publishError("Keychain delete verification failed (KEY-VERIFY)")
                return
            }
            apiKeyInput = ""
            hasStoredKey = false
            keychainProbeDigest = nil
            publishTransientNotice(kind: .storage, message: "Keychain delete verified")
        } catch {
            publishError("Keychain delete failed (KEY-DELETE)")
        }
    }

    private func clearCachedSecurityEvidence() {
        hasStoredKey = false
        keychainProbeDigest = nil
        isolationCanaryPresent = false
        isolationCanaryDigest = nil
    }
    private func refreshProbeState(publishSuccess: Bool) {
        do {
            let value = try keychain.read(account: Self.probeAccount)
            hasStoredKey = value != nil
            keychainProbeDigest = value.map { Self.probeDigest(for: $0) }
            if publishSuccess {
                publishTransientNotice(
                    kind: .storage,
                    message: value == nil ? "Keychain absence verified" : "Keychain read verified"
                )
            }
        } catch {
            hasStoredKey = false
            keychainProbeDigest = nil
            publishError("Keychain unavailable (KEY-READ)")
        }
    }


    func prepareIsolationCanary() {
        guard requireActiveBuildForMutation(.diagnosticsCanaryPrepare) else { return }
        do {
            isolationCanaryDigest = try isolationCanaryRepository.prepare()
            isolationCanaryPresent = true
            publishTransientNotice(kind: .storage, message: "Isolation canary prepared; install and run the paired Probe IPA")
        } catch {
            publishError("Isolation canary preparation failed (KEY-ISOLATION-PREPARE)")
        }
    }

    func verifyIsolationCanary() {
        guard requireActiveBuildForMutation(.diagnosticsCanaryVerify) else { return }
        refreshIsolationCanary(publishSuccess: true)
    }

    func deleteIsolationCanary() {
        guard requireActiveBuildForMutation(.diagnosticsCanaryDelete) else { return }
        do {
            try isolationCanaryRepository.delete()
            isolationCanaryDigest = nil
            isolationCanaryPresent = false
            publishTransientNotice(kind: .storage, message: "Isolation canary deletion verified")
        } catch {
            publishError("Isolation canary deletion failed (KEY-ISOLATION-DELETE)")
        }
    }

    private func refreshIsolationCanary(publishSuccess: Bool) {
        do {
            let digest = try isolationCanaryRepository.currentDigest()
            isolationCanaryDigest = digest
            isolationCanaryPresent = digest != nil
            if publishSuccess {
                publishTransientNotice(
                    kind: .storage,
                    message: digest == nil ? "Isolation canary is absent" : "Isolation canary remains unchanged"
                )
            }
        } catch {
            isolationCanaryDigest = nil
            isolationCanaryPresent = false
            if publishSuccess {
                publishError("Isolation canary verification failed (KEY-ISOLATION-VERIFY)")
            }
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
            businessStatus = Self.businessStatus(for: result.snapshot)
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
        diagnosticNoticeMessage = message
        let notice = TransientNotice(
            id: UUID(),
            kind: kind,
            message: S1OrdinarySurfaceContract.noticeDescription(for: message)
        )
        transientNotice = notice
        noticeDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled, self?.transientNotice?.id == notice.id else { return }
            self?.transientNotice = nil
        }
    }

    private func publishError(_ message: String, domain: ErrorDomain = .persistent) {
        if let current = errorMessagesByDomain[domain], current != message {
            errorMessagesByDomain[domain] = current + "; " + message
        } else {
            errorMessagesByDomain[domain] = message
        }
        refreshPublishedErrorMessage()
    }

    private func clearErrors(in domain: ErrorDomain) {
        errorMessagesByDomain[domain] = nil
        refreshPublishedErrorMessage()
    }

    private func refreshPublishedErrorMessage() {
        let diagnostics = ErrorDomain.allCases.compactMap { errorMessagesByDomain[$0] }
        diagnosticErrorMessage = diagnostics.isEmpty ? nil : diagnostics.joined(separator: "; ")
        let messages = diagnostics.map { S1OrdinarySurfaceContract.errorDescription(for: $0) }
        errorMessage = messages.isEmpty ? nil : messages.joined(separator: "；")
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
            let progress: S1OrdinaryProgress
            switch chapter.stage {
            case .notStarted:
                progress = .chapterReady
            case .reviewingV1, .reviewingV2:
                progress = .reviewingChapter
            case .diagnosing:
                progress = .understandingChapterFeedback
            case .awaitingRewriteConfirmation:
                progress = .waitingForRewritePlan
            case .rewriting:
                progress = .rewritingChapter
            case .approvedFrozen:
                progress = .chapterApproved
            }
            return S1OrdinarySurfaceContract.progressDescription(progress)
        }

        if let approval = snapshot.openingPlanApproval {
            let progress: S1OrdinaryProgress
            switch approval.status {
            case .pending:
                progress = .waitingForOpeningPlan
            case .approved:
                progress = .openingPlanApproved
            case .invalidated:
                progress = .openingPlanChanged
            case .expired:
                progress = .openingPlanExpired
            }
            return S1OrdinarySurfaceContract.progressDescription(progress)
        }

        if let stage = snapshot.latestRun?.currentStage {
            if stage.hasPrefix("openingPlan.approval") {
                return S1OrdinarySurfaceContract.progressDescription(.waitingForOpeningPlan)
            }
            if stage.hasPrefix("openingPlan.approved") {
                return S1OrdinarySurfaceContract.progressDescription(.openingPlanApproved)
            }
            if stage.hasPrefix("strategicInterview") {
                return S1OrdinarySurfaceContract.progressDescription(.understandingIdea)
            }
            if stage == "awaitingProjectIntent" {
                return S1OrdinarySurfaceContract.progressDescription(.waitingForIdea)
            }
        }

        let progress: S1OrdinaryProgress = snapshot.session.focusedProjectID != nil || !snapshot.projects.isEmpty
            ? .understandingIdea
            : .waitingForIdea
        return S1OrdinarySurfaceContract.progressDescription(progress)
    }

    private static func probeDigest(for text: String) -> String {
        String(payloadHash(for: text).prefix(12))
    }

    private static func payloadHash(for text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
