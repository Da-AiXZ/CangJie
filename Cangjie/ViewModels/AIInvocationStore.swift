//
//  AIInvocationStore.swift
//  Cangjie
//
//  AI Invocation 审批状态机 + 9 API方法 + 2000ms轮询 + 监听。
//  对齐原版 aiInvocationStore.ts:1-527 全量方法。
//  机制4：每个方法标注原版文件+行号。
//
//  主理人决策执行：
//  - Q1: 不实现 advanceHeadlessSession/scheduleHeadlessAdvance
//  - Q2: 轮询间隔 2000ms 硬编码
//  - Q8: showDebugPanel() 无条件 visible=true，shouldKeepPanelVisible() 无条件 true
//  - 疑问2: 包含 title 计算属性
//

import Foundation
import Combine

/// AI Invocation 审批 Store — aiInvocationStore.ts:1-527
@MainActor
final class AIInvocationStore: ObservableObject {

    // MARK: - 内部数据结构（非 @Published）

    /// session 更新监听器字典 — aiInvocationStore.ts:24
    /// 使用 UUID 标识每个 listener，便于取消订阅
    private var sessionListeners: [String: [(UUID, (InvocationResponseDTO) -> Void)]] = [:]

    /// 轮询定时器字典 — aiInvocationStore.ts:25
    private var sessionPollTimers: [String: Task<Void, Never>] = [:]

    /// 活跃轮询 session 集合 — aiInvocationStore.ts:26
    private var activeGenerationPollSessions: Set<String> = []

    /// 正在请求中的 session 集合 — aiInvocationStore.ts:27
    private var sessionPollInFlight: Set<String> = []

    // MARK: - 状态字段（@Published） — aiInvocationStore.ts:29-45

    /// 控制审批面板显示 — aiInvocationStore.ts:29
    @Published var visible: Bool = false

    /// 全局加载遮罩 — aiInvocationStore.ts:30
    @Published var loading: Bool = false

    /// 操作按钮 loading — aiInvocationStore.ts:31
    @Published var actionLoading: Bool = false

    /// 错误提示 — aiInvocationStore.ts:32
    @Published var error: String = ""

    /// 当前会话 — aiInvocationStore.ts:33
    @Published var session: InvocationSessionDTO? = nil

    /// 当前尝试 — aiInvocationStore.ts:34
    @Published var attempt: InvocationAttemptDTO? = nil

    /// 当前决策 — aiInvocationStore.ts:35
    @Published var decision: AdoptionDecisionDTO? = nil

    /// 当前提交 — aiInvocationStore.ts:36
    @Published var commit: AdoptionCommitDTO? = nil

    /// 下一步提示 — aiInvocationStore.ts:37
    @Published var nextAction: String = ""

    /// 系统词草稿（编辑中） — aiInvocationStore.ts:38
    @Published var promptDraftSystem: String = ""

    /// 用户词草稿（编辑中） — aiInvocationStore.ts:39
    @Published var promptDraftUser: String = ""

    /// 已保存系统词 — aiInvocationStore.ts:40
    @Published var promptDraftSavedSystem: String = ""

    /// 已保存用户词 — aiInvocationStore.ts:41
    @Published var promptDraftSavedUser: String = ""

    /// 预览结果 — aiInvocationStore.ts:42
    @Published var promptDraftPreview: InvocationPromptDraftPreviewDTO? = nil

    /// 预览 loading — aiInvocationStore.ts:43
    @Published var promptDraftLoading: Bool = false

    /// 实时输出内容 — aiInvocationStore.ts:44
    @Published var liveAttemptContent: String = ""

    /// 轮询 loading — aiInvocationStore.ts:45
    @Published var liveAttemptLoading: Bool = false

    // MARK: - 计算属性（16个） — aiInvocationStore.ts:47-102

    /// attempt.id 非空 — aiInvocationStore.ts:47
    var hasAttempt: Bool {
        return !(attempt?.id.isEmpty ?? true)
    }

    /// 可否采纳 — aiInvocationStore.ts:48-54
    var canAccept: Bool {
        guard let session = session,
              let attempt = attempt,
              decision == nil || (decision?.id.isEmpty ?? true) else { return false }
        return !session.id.isEmpty
            && session.status == "awaiting_acceptance"
            && !attempt.id.isEmpty
            && attempt.status == "succeeded"
    }

    /// 可否提交 — aiInvocationStore.ts:55
    var canCommit: Bool {
        guard let session = session,
              let decision = decision else { return false }
        return !session.id.isEmpty && !decision.id.isEmpty && (commit == nil || commit?.id.isEmpty == true)
    }

    /// 可否重试 — aiInvocationStore.ts:56-60
    var canRetry: Bool {
        guard let session = session, let attempt = attempt else { return false }
        let retryableStatuses: Set<String> = ["awaiting_pre_call_review", "awaiting_acceptance", "awaiting_commit", "cancelled", "failed"]
        return !session.id.isEmpty && !attempt.id.isEmpty && retryableStatuses.contains(session.status)
    }

    /// 是否正在生成 — aiInvocationStore.ts:61
    var isGenerating: Bool {
        return session?.status == "generating"
    }

    /// 实时输出显示文本 — aiInvocationStore.ts:62
    var liveAttemptDisplay: String {
        if !liveAttemptContent.isEmpty { return liveAttemptContent }
        return attempt?.content ?? ""
    }

    /// 标题 — aiInvocationStore.ts:63-66（疑问2：PRD漏列，iOS包含）
    var title: String {
        guard let session = session else { return "AI 生成审阅" }
        return "\(session.operation) / \(session.nodeKey)"
    }

    /// 系统词模板 — aiInvocationStore.ts:67-69
    var draftSystemTemplate: String {
        return session?.promptSnapshot?.templatePrompt?.system ?? ""
    }

    /// 系统词编辑值 — aiInvocationStore.ts:70-72
    var draftSystemEdited: String {
        if !promptDraftSystem.isEmpty { return promptDraftSystem }
        if !promptDraftSavedSystem.isEmpty { return promptDraftSavedSystem }
        return draftSystemTemplate
    }

    /// 用户词模板 — aiInvocationStore.ts:73-75
    var draftUserTemplate: String {
        return session?.promptSnapshot?.templatePrompt?.user ?? ""
    }

    /// 用户词编辑值 — aiInvocationStore.ts:76-78
    var draftUserEdited: String {
        if !promptDraftUser.isEmpty { return promptDraftUser }
        if !promptDraftSavedUser.isEmpty { return promptDraftSavedUser }
        return draftUserTemplate
    }

    /// 运行时系统词 — aiInvocationStore.ts:79-83
    var draftRuntimeSystem: String {
        return promptDraftPreview?.promptSnapshot.prompt?.system
            ?? session?.promptSnapshot?.prompt?.system
            ?? ""
    }

    /// 运行时用户词 — aiInvocationStore.ts:84-88
    var draftRuntimeUser: String {
        return promptDraftPreview?.promptSnapshot.prompt?.user
            ?? session?.promptSnapshot?.prompt?.user
            ?? ""
    }

    /// 诊断信息 — aiInvocationStore.ts:89-93
    var draftDiagnostics: [String] {
        return promptDraftPreview?.promptSnapshot.diagnostics
            ?? session?.promptSnapshot?.diagnostics
            ?? []
    }

    /// 缺失变量 — aiInvocationStore.ts:94-98
    var draftMissingVariables: [String] {
        return promptDraftPreview?.promptSnapshot.missingVariables
            ?? session?.promptSnapshot?.missingVariables
            ?? []
    }

    /// 变量快照分组 — aiInvocationStore.ts:99-102
    var variableSnapshotGroups: [InvocationVariableSnapshotGroup] {
        let plan = promptDraftPreview?.variablePlan ?? session?.variablePlan
        return plan?.snapshotGroups ?? []
    }

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - featureFlag 相关（Q8决策）

    /// Q8决策：iOS 无条件设 visible=true — aiInvocationStore.ts:105-109（改写）
    func showDebugPanel() {
        visible = true
    }

    /// Q8决策：iOS 无条件返回 true — aiInvocationStore.ts:111-113（改写）
    func shouldKeepPanelVisible() -> Bool {
        return true
    }

    // MARK: - shouldCommitPromptVersion — aiInvocationStore.ts:122-129

    /// 判断是否需要提交提示词版本 — aiInvocationStore.ts:122-129
    func shouldCommitPromptVersion() -> Bool {
        guard let snapshot = session?.promptSnapshot else { return false }
        let draft = snapshot.draftPrompt
        let template = snapshot.templatePrompt
        guard draft != nil else { return false }
        guard template != nil else { return true }
        return draft?.system != template?.system || draft?.user != template?.user
    }

    // MARK: - applyResponse — aiInvocationStore.ts:131-163

    /// 应用响应（内部核心方法） — aiInvocationStore.ts:131-163
    /// Q1决策：移除末尾 scheduleHeadlessAdvance() 调用
    func applyResponse(_ payload: InvocationResponseDTO) {
        let previousSessionId = session?.id
        let nextSessionId = payload.session.id
        let sameSession = previousSessionId != nil && previousSessionId == nextSessionId

        session = payload.session
        attempt = payload.attempt ?? (sameSession ? attempt : nil)
        decision = payload.decision ?? (sameSession ? decision : nil)
        commit = payload.commit ?? (sameSession ? commit : nil)
        nextAction = payload.nextAction ?? ""

        // 更新 promptDraftSaved — aiInvocationStore.ts:141-148
        promptDraftSavedSystem = payload.session.promptSnapshot?.draftPrompt?.system
            ?? payload.session.promptSnapshot?.templatePrompt?.system
            ?? ""
        promptDraftSavedUser = payload.session.promptSnapshot?.draftPrompt?.user
            ?? payload.session.promptSnapshot?.templatePrompt?.user
            ?? ""
        promptDraftSystem = promptDraftSavedSystem
        promptDraftUser = promptDraftSavedUser
        promptDraftPreview = nil

        // 更新 liveAttemptContent — aiInvocationStore.ts:150-154
        if let content = payload.attempt?.content, !content.isEmpty {
            liveAttemptContent = content
        } else if !sameSession {
            liveAttemptContent = ""
        }

        syncGenerationPolling()

        // 通知 listeners — aiInvocationStore.ts:156-161
        let sessionId = payload.session.id
        if !sessionId.isEmpty {
            let listeners = sessionListeners[sessionId] ?? []
            for (_, listener) in listeners {
                listener(payload)
            }
        }
        // Q1决策：不调用 scheduleHeadlessAdvance()
    }

    // MARK: - openFromResponse — aiInvocationStore.ts:185-198

    /// 从响应打开（不调 API） — aiInvocationStore.ts:185-198
    func openFromResponse(_ payload: InvocationResponseDTO, showPanel: Bool = true) {
        if !payload.session.id.isEmpty && payload.session.id != session?.id {
            attempt = nil
            decision = nil
            commit = nil
            nextAction = ""
            liveAttemptContent = ""
            promptDraftPreview = nil
        }
        applyResponse(payload)
        if showPanel {
            showDebugPanel() // Q8：无条件 visible=true
        }
    }

    // MARK: - clearPromptDraftPreview — aiInvocationStore.ts:200-202

    /// 清除预览 — aiInvocationStore.ts:200-202
    func clearPromptDraftPreview() {
        promptDraftPreview = nil
    }

    // MARK: - open — aiInvocationStore.ts:204-240

    /// 打开 session — aiInvocationStore.ts:204-240
    func open(sessionId: String, showPanel: Bool = true) async throws {
        if showPanel {
            showDebugPanel() // Q8：无条件 visible=true
        }
        loading = true
        error = ""
        session = nil
        attempt = nil
        decision = nil
        commit = nil
        nextAction = ""
        promptDraftSystem = ""
        promptDraftUser = ""
        promptDraftSavedSystem = ""
        promptDraftSavedUser = ""
        promptDraftPreview = nil
        liveAttemptContent = ""
        stopGenerationPolling()

        do {
            let payload: InvocationResponseDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.get(sessionId: sessionId)
            )
            promptDraftSavedSystem = payload.session.promptSnapshot?.draftPrompt?.system
                ?? payload.session.promptSnapshot?.templatePrompt?.system
                ?? ""
            promptDraftSavedUser = payload.session.promptSnapshot?.draftPrompt?.user
                ?? payload.session.promptSnapshot?.templatePrompt?.user
                ?? ""
            promptDraftSystem = promptDraftSavedSystem
            promptDraftUser = promptDraftSavedUser
            openFromResponse(payload, showPanel: showPanel)
        } catch {
            self.error = errorText(error)
            throw error
        }
        loading = false
    }

    // MARK: - accept — aiInvocationStore.ts:242-259

    /// 采纳 — aiInvocationStore.ts:242-259
    func accept() async throws {
        guard let sessionId = session?.id, let attemptId = attempt?.id, !sessionId.isEmpty, !attemptId.isEmpty else { return }
        actionLoading = true
        error = ""
        do {
            let payload = InvocationAcceptPayload(
                attemptId: attemptId,
                acceptedBy: "user",
                commitPromptVersion: shouldCommitPromptVersion(),
                commitVariableOutputs: nil,
                commitVariableBindings: nil,
                metadata: nil
            )
            let response: InvocationResponseDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.accept(sessionId: sessionId),
                body: payload
            )
            applyResponse(response)
        } catch {
            self.error = errorText(error)
            throw error
        }
        actionLoading = false
    }

    // MARK: - reject — aiInvocationStore.ts:261-277

    /// 拒绝 — aiInvocationStore.ts:261-277
    func reject() async throws {
        guard let sessionId = session?.id, let attemptId = attempt?.id, !sessionId.isEmpty, !attemptId.isEmpty else { return }
        actionLoading = true
        error = ""
        do {
            let payload = InvocationAcceptPayload(
                attemptId: attemptId,
                acceptedBy: "user"
            )
            let response: InvocationResponseDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.reject(sessionId: sessionId),
                body: payload
            )
            applyResponse(response)
        } catch {
            self.error = errorText(error)
            throw error
        }
        actionLoading = false
    }

    // MARK: - retry — aiInvocationStore.ts:279-300

    /// 重新生成 — aiInvocationStore.ts:279-300
    func retry() async throws {
        guard let sessionId = session?.id, !sessionId.isEmpty else { return }
        actionLoading = true
        error = ""
        do {
            let payload = InvocationResumePayload(resumedBy: "user")
            let response: InvocationResponseDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.retry(sessionId: sessionId),
                body: payload
            )
            applyResponse(response)
            // 清空 decision/commit — aiInvocationStore.ts:288-289
            decision = nil
            commit = nil
            if shouldKeepPanelVisible() {
                showDebugPanel()
            }
            syncGenerationPolling()
        } catch {
            self.error = errorText(error)
            throw error
        }
        actionLoading = false
    }

    // MARK: - resume — aiInvocationStore.ts:302-321

    /// 恢复（批准生成） — aiInvocationStore.ts:302-321
    func resume() async throws {
        guard let sessionId = session?.id, !sessionId.isEmpty else { return }
        actionLoading = true
        error = ""
        do {
            let payload = InvocationResumePayload(resumedBy: "user")
            let response: InvocationResponseDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.resume(sessionId: sessionId),
                body: payload
            )
            applyResponse(response)
            if shouldKeepPanelVisible() {
                showDebugPanel()
            }
            syncGenerationPolling()
        } catch {
            self.error = errorText(error)
            throw error
        }
        actionLoading = false
    }

    // MARK: - previewPromptDraft — aiInvocationStore.ts:323-335

    /// 预览提示词草稿 — aiInvocationStore.ts:323-335
    func previewPromptDraft(system: String, user: String?) async {
        guard let sessionId = session?.id, !sessionId.isEmpty else { return }
        promptDraftLoading = true
        let payload = InvocationPromptDraftPayload(systemTemplate: system, userTemplate: user)
        do {
            let response: InvocationPromptDraftPreviewDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.previewPromptDraft(sessionId: sessionId),
                body: payload
            )
            promptDraftPreview = response
        } catch {
            // 原版无 error 处理，不设 actionLoading
            Logger.engine.error("previewPromptDraft 失败: \(error.localizedDescription)")
        }
        promptDraftLoading = false
    }

    // MARK: - savePromptDraft — aiInvocationStore.ts:337-352

    /// 保存提示词草稿 — aiInvocationStore.ts:337-352
    func savePromptDraft(system: String, user: String?) async {
        guard let sessionId = session?.id, !sessionId.isEmpty else { return }
        promptDraftLoading = true
        let payload = InvocationPromptDraftPayload(systemTemplate: system, userTemplate: user)
        do {
            let response: InvocationResponseDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.savePromptDraft(sessionId: sessionId),
                body: payload
            )
            promptDraftSavedSystem = system
            promptDraftSavedUser = user ?? ""
            promptDraftPreview = nil
            applyResponse(response)
        } catch {
            Logger.engine.error("savePromptDraft 失败: \(error.localizedDescription)")
        }
        promptDraftLoading = false
    }

    // MARK: - updateVariables — aiInvocationStore.ts:354-370

    /// 更新变量 — aiInvocationStore.ts:354-370
    func updateVariables(values: [String: AnyCodable]) async throws {
        guard let sessionId = session?.id, !sessionId.isEmpty else { return }
        actionLoading = true
        error = ""
        do {
            let payload = InvocationVariableUpdatePayload(values: values, updatedBy: "user")
            let response: InvocationResponseDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.updateVariables(sessionId: sessionId),
                body: payload
            )
            applyResponse(response)
        } catch {
            self.error = errorText(error)
            throw error
        }
        actionLoading = false
    }

    // MARK: - runCommit — aiInvocationStore.ts:372-385

    /// 提交 — aiInvocationStore.ts:372-385
    func runCommit() async throws {
        guard let sessionId = session?.id, let decisionId = decision?.id,
              !sessionId.isEmpty, !decisionId.isEmpty else { return }
        actionLoading = true
        error = ""
        do {
            let payload = InvocationCommitPayload(decisionId: decisionId)
            let response: InvocationResponseDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.commit(sessionId: sessionId),
                body: payload
            )
            applyResponse(response)
        } catch {
            self.error = errorText(error)
            throw error
        }
        actionLoading = false
    }

    // MARK: - close — aiInvocationStore.ts:387-390

    /// 关闭面板 — aiInvocationStore.ts:387-390
    func close() {
        visible = false
        stopGenerationPolling()
    }

    // MARK: - 轮询机制 — aiInvocationStore.ts:392-461

    /// 清除轮询定时器 — aiInvocationStore.ts:392-397
    private func clearGenerationPollTimer(sessionId: String) {
        sessionPollTimers[sessionId]?.cancel()
        sessionPollTimers.removeValue(forKey: sessionId)
    }

    /// 刷新轮询 loading 状态 — aiInvocationStore.ts:399-401
    private func refreshLiveAttemptLoading() {
        liveAttemptLoading = !sessionPollTimers.isEmpty || !sessionPollInFlight.isEmpty
    }

    /// 停止轮询 — aiInvocationStore.ts:403-414
    func stopGenerationPolling(sessionId: String? = nil) {
        if let sessionId = sessionId {
            activeGenerationPollSessions.remove(sessionId)
            clearGenerationPollTimer(sessionId: sessionId)
        } else {
            activeGenerationPollSessions.removeAll()
            for key in sessionPollTimers.keys {
                clearGenerationPollTimer(sessionId: key)
            }
        }
        refreshLiveAttemptLoading()
    }

    /// 刷新 session（silent） — aiInvocationStore.ts:416-421
    private func refreshSession(sessionId: String) async {
        do {
            let payload: InvocationResponseDTO = try await apiClient.request(
                APIEndpoint.AIInvocation.get(sessionId: sessionId)
            )
            if let currentSessionId = session?.id, currentSessionId != sessionId { return }
            applyResponse(payload)
        } catch {
            // 原版 .catch(() => {}) 静默处理
        }
    }

    /// 安排轮询 — aiInvocationStore.ts:423-450
    /// Q2决策：间隔 2000ms 硬编码
    private func scheduleGenerationPoll(sessionId: String) {
        guard activeGenerationPollSessions.contains(sessionId) else { return }
        if sessionPollTimers[sessionId] != nil || sessionPollInFlight.contains(sessionId) { return }

        let timer = Task { [weak self] in
            // Q2决策：2000ms 硬编码
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            guard let self = self else { return }
            self.sessionPollTimers.removeValue(forKey: sessionId)

            guard self.activeGenerationPollSessions.contains(sessionId) else {
                self.refreshLiveAttemptLoading()
                return
            }

            self.sessionPollInFlight.insert(sessionId)
            self.refreshLiveAttemptLoading()

            await self.refreshSession(sessionId: sessionId)

            self.sessionPollInFlight.remove(sessionId)

            // 继续轮询条件：仍在 activeSet + session 匹配 + status=generating
            if self.activeGenerationPollSessions.contains(sessionId),
               let currentSession = self.session,
               currentSession.id == sessionId,
               currentSession.status == "generating" {
                self.scheduleGenerationPoll(sessionId: sessionId)
            }
            self.refreshLiveAttemptLoading()
        }
        sessionPollTimers[sessionId] = timer
        refreshLiveAttemptLoading()
    }

    /// 同步轮询状态 — aiInvocationStore.ts:452-461
    private func syncGenerationPolling() {
        guard let sessionId = session?.id, !sessionId.isEmpty else { return }
        if session?.status == "generating" {
            activeGenerationPollSessions.insert(sessionId)
            scheduleGenerationPoll(sessionId: sessionId)
            return
        }
        stopGenerationPolling()
    }

    // MARK: - 监听器 — aiInvocationStore.ts:463-475

    /// 注册 session 更新监听 — aiInvocationStore.ts:463-475
    /// 返回取消订阅闭包
    @discardableResult
    func onSessionUpdate(sessionId: String, listener: @escaping (InvocationResponseDTO) -> Void) -> () -> Void {
        let listenerId = UUID()
        var listeners = sessionListeners[sessionId] ?? []
        listeners.append((listenerId, listener))
        sessionListeners[sessionId] = listeners
        return { [weak self] in
            guard let self = self else { return }
            var current = self.sessionListeners[sessionId] ?? []
            current.removeAll { $0.0 == listenerId }
            self.sessionListeners[sessionId] = current.isEmpty ? nil : current
        }
    }

    // MARK: - 辅助

    /// 错误信息格式化 — aiInvocationStore.ts:17-21
    private func errorText(_ error: Error) -> String {
        let msg = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !msg.isEmpty { return msg }
        return "操作失败，请稍后重试"
    }
}
