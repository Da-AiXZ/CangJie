//
//  AIInvocationReviewPanel.swift
//  Cangjie
//
//  AI Invocation 审批面板（Sheet），15个UI区块。
//  对齐原版 AIInvocationReviewPanel.vue:1-901。
//  机制4：每个区块标注原版文件+行号。
//
//  主理人决策：
//  - Q8: variableCenterDebugPanels=true 硬编码（面板始终显示）
//  - 疑问5: 复用 InvocationOutput.swift，不重复实现 pickPath 等
//

import SwiftUI

/// AI Invocation 审批面板 — AIInvocationReviewPanel.vue:1-901
struct AIInvocationReviewPanel: View {

    @ObservedObject var store: AIInvocationStore

    /// 本地系统词编辑副本 — AIInvocationReviewPanel.vue:10
    @State private var promptDraftSystem: String = ""
    /// 本地用户词编辑副本 — AIInvocationReviewPanel.vue:11
    @State private var promptDraftUser: String = ""
    /// 防抖定时器 — AIInvocationReviewPanel.vue:12
    @State private var previewDebounceTask: Task<Void, Never>?
    /// 展开的变量组 — AIInvocationReviewPanel.vue:29
    @State private var expandedVariableGroups: Set<String> = []
    /// 展开的提示词组 — AIInvocationReviewPanel.vue:30
    @State private var expandedPromptGroups: Set<String> = ["system", "user"]
    /// 缺失变量输入草稿 — AIInvocationReviewPanel.vue:51
    @State private var missingVariableDrafts: [String: String] = [:]

    // Q8: variableCenterDebugPanels=true 硬编码
    private let showVariableCenterDebug = true

    var body: some View {
        VStack(spacing: 0) {
            // 区块1: 审批面板容器 — AIInvocationReviewPanel.vue:480-486
            if store.loading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !store.error.isEmpty {
                // 错误提示
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(store.error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        store.error = ""
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let session = store.session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // 区块2: 会话状态卡片 — AIInvocationReviewPanel.vue:488-496
                        sessionStatusCard(session)

                        // 区块3: awaiting_pre_call_review 提示 — AIInvocationReviewPanel.vue:498-504
                        if session.status == "awaiting_pre_call_review" {
                            infoAlert(title: "审批提示", message: "请审阅以下提示词和变量配置，确认后点击「批准生成」", type: .info)
                        }

                        // 区块3a: 本步规则说明 — AIInvocationReviewPanel.vue:505-515
                        if showVariableCenterDebug {
                            rulesCard
                        }

                        // 区块4: awaiting_acceptance 提示 — AIInvocationReviewPanel.vue:516-522
                        if session.status == "awaiting_acceptance" {
                            infoAlert(title: "审阅完成", message: "AI 已完成生成，请审阅输出结果后点击「采纳」", type: .info)
                        }

                        // 区块5: 缺失变量提示+补齐表单 — AIInvocationReviewPanel.vue:524-554
                        if !store.draftMissingVariables.isEmpty && canEditVariables(session: session) {
                            missingVariablesCard
                        }

                        // 区块6: 诊断信息列表 — AIInvocationReviewPanel.vue:556-562
                        if !diagnostics.isEmpty {
                            diagnosticsCard
                        }

                        // 区块7: 提示词对照面板 — AIInvocationReviewPanel.vue:564-640
                        if hasPrompt {
                            promptComparisonCard
                        }

                        // 区块8: 变量快照分组展示 — AIInvocationReviewPanel.vue:642-693
                        if hasVariableSnapshot {
                            variableSnapshotCard
                        }

                        // 区块9: AI实时输出区 — AIInvocationReviewPanel.vue:695-710
                        if store.hasAttempt {
                            liveOutputCard
                        }

                        // 区块10: 变量中心写入预览 — AIInvocationReviewPanel.vue:712-732
                        if showVariableCenterDebug && showOutputPreview {
                            outputPreviewCard
                        }

                        // 区块11: 采纳决策卡片 — AIInvocationReviewPanel.vue:734-739
                        if let decision = store.decision {
                            decisionCard(decision)
                        }

                        // 区块12: 提交步骤时间线 — AIInvocationReviewPanel.vue:741-751
                        if hasCommitSteps, let commit = store.commit {
                            commitStepsCard(commit)
                        }
                    }
                    .padding()
                }

                // 区块13: 底部操作按钮区 — AIInvocationReviewPanel.vue:755-785
                bottomActionBar(session: session)
            } else {
                Text("暂无审批会话")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("关闭") { store.close() }
            }
        }
        // 区块14: handleResume 逻辑 + 区块15: 防抖预览逻辑 — 通过 onChange 触发
        .onChange(of: store.draftSystemEdited) { newValue in
            promptDraftSystem = newValue
        }
        .onChange(of: store.draftUserEdited) { newValue in
            promptDraftUser = newValue
        }
        .onChange(of: store.visible) { isVisible in
            if !isVisible {
                expandedPromptGroups.removeAll()
                expandedVariableGroups.removeAll()
                missingVariableDrafts.removeAll()
            }
        }
        .onChange(of: store.session?.id) { _ in
            expandedPromptGroups.removeAll()
            expandedVariableGroups.removeAll()
            missingVariableDrafts.removeAll()
        }
        .onChange(of: store.draftMissingVariables) { missing in
            for alias in missing {
                if missingVariableDrafts[alias] == nil {
                    missingVariableDrafts[alias] = ""
                }
            }
        }
        .onChange(of: promptDraftSystem) { _ in
            schedulePreviewDebounce()
        }
        .onChange(of: promptDraftUser) { _ in
            schedulePreviewDebounce()
        }
        .onAppear {
            promptDraftSystem = store.draftSystemEdited
            promptDraftUser = store.draftUserEdited
        }
    }

    // MARK: - 计算属性（AIInvocationReviewPanel.vue:14-78）

    /// 状态类型颜色 — AIInvocationReviewPanel.vue:14-20
    private var statusColor: Color {
        guard let status = store.session?.status else { return .gray }
        switch status {
        case "completed": return .green
        case "blocked", "failed": return .red
        case "awaiting_acceptance", "awaiting_commit": return .orange
        default: return .blue
        }
    }

    /// 变量快照是否有数据 — AIInvocationReviewPanel.vue:23-25
    private var hasVariableSnapshot: Bool {
        return store.variableSnapshotGroups.contains { group in
            (group.items?.count ?? 0) > 0
        }
    }

    /// 可见变量快照组 — AIInvocationReviewPanel.vue:26-28
    private var visibleVariableSnapshotGroups: [InvocationVariableSnapshotGroup] {
        return store.variableSnapshotGroups.filter { ($0.items?.count ?? 0) > 0 }
    }

    /// 提示词校验错误 — AIInvocationReviewPanel.vue:31-37
    private var promptDraftValidationErrors: [String] {
        guard isDraftEditable else { return [] }
        var errors: [String] = []
        if promptDraftSystem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("系统提示词不能为空")
        }
        if promptDraftUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("用户提示词不能为空")
        }
        return errors
    }

    /// 合并诊断信息 — AIInvocationReviewPanel.vue:38-45
    private var diagnostics: [String] {
        var result = promptDraftValidationErrors
        if let planDiagnostics = store.session?.variablePlan?.diagnostics {
            result.append(contentsOf: planDiagnostics)
        }
        result.append(contentsOf: store.draftDiagnostics)
        return Array(Set(result)).filter { !$0.isEmpty }
    }

    /// 缺失变量 — AIInvocationReviewPanel.vue:46-50
    private var missingVariables: [String] {
        return store.draftMissingVariables
    }

    /// 可否编辑变量 — AIInvocationReviewPanel.vue:52
    private func canEditVariables(session: InvocationSessionDTO) -> Bool {
        return session.status == "blocked" || session.status == "awaiting_pre_call_review"
    }

    /// 是否有提示词 — AIInvocationReviewPanel.vue:53-58
    private var hasPrompt: Bool {
        return !store.draftSystemTemplate.isEmpty
            || !store.draftUserTemplate.isEmpty
            || !store.draftRuntimeSystem.isEmpty
            || !store.draftRuntimeUser.isEmpty
    }

    /// isPreCallBlocked — AIInvocationReviewPanel.vue:59
    private var isPreCallBlocked: Bool {
        guard let session = store.session else { return false }
        return session.status == "blocked" && store.attempt == nil && store.decision == nil
    }

    /// 可编辑草稿 — AIInvocationReviewPanel.vue:60
    private var isDraftEditable: Bool {
        guard let session = store.session else { return false }
        return session.status == "awaiting_pre_call_review" || isPreCallBlocked
    }

    /// 是否有提交步骤 — AIInvocationReviewPanel.vue:71
    private var hasCommitSteps: Bool {
        return (store.commit?.steps.count ?? 0) > 0
    }

    /// 是否显示输出预览 — AIInvocationReviewPanel.vue:73
    private var showOutputPreview: Bool {
        return store.hasAttempt && !store.isGenerating && !outputPreviewRows.isEmpty
    }

    /// 输出绑定 — AIInvocationReviewPanel.vue:102-112
    private var outputBindings: [InvocationVariableBinding] {
        return (store.session?.outputBindings ?? []).filter { !$0.alias.isEmpty }
    }

    /// 输出预览行 — AIInvocationReviewPanel.vue:469-476
    private var outputPreviewRows: [OutputPreviewRow] {
        let parsedContent = parseAttemptContent(store.attempt?.content ?? "")
        return outputBindings.map { binding in
            let jsonPath = binding.sourcePath ?? binding.alias
            let target = binding.variableKey ?? binding.alias
            let targetDisplayName = binding.targetDisplayName ?? binding.variableKey ?? binding.alias
            let previewSource = binding.previewSource ?? ""
            let value: Any?
            if previewSource == "continuation" {
                value = nil
            } else {
                value = resolveOutputPreviewValue(source: parsedContent, row: OutputPreviewRow(alias: binding.alias, jsonPath: jsonPath, target: target, targetDisplayName: targetDisplayName, previewSource: previewSource))
            }
            return OutputPreviewRow(alias: binding.alias, jsonPath: jsonPath, target: target, targetDisplayName: targetDisplayName, previewSource: previewSource, resolvedValue: value)
        }
    }

    // MARK: - UI 区块实现

    /// 会话状态卡片 — AIInvocationReviewPanel.vue:488-496
    private func sessionStatusCard(_ session: InvocationSessionDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("会话状态")
                    .font(.headline)
                Spacer()
                Text(session.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("策略").font(.caption).foregroundColor(.secondary)
                    Text(session.policy).font(.body)
                }
                if !store.nextAction.isEmpty {
                    VStack(alignment: .leading) {
                        Text("下一步").font(.caption).foregroundColor(.secondary)
                        Text(store.nextAction).font(.body)
                    }
                }
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 本步规则说明卡片 — AIInvocationReviewPanel.vue:505-515
    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本步规则说明")
                .font(.headline)
            Text("AI 生成结果将写入变量中心，已配置的输出绑定将自动填充到对应变量。")
                .font(.body)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("• 审阅提示词和变量配置后点击「批准生成」")
                Text("• 生成完成后审阅输出结果并点击「采纳」")
                Text("• 采纳后点击「提交」将结果写入变量中心")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 缺失变量卡片 — AIInvocationReviewPanel.vue:524-554
    private var missingVariablesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("缺失变量")
                .font(.headline)
            Text("以下变量缺失，请补齐后继续：")
                .font(.caption)
                .foregroundColor(.orange)
            Text(missingVariables.joined(separator: "、"))
                .font(.body)
                .foregroundColor(.orange)
            ForEach(missingVariables, id: \.self) { alias in
                VStack(alignment: .leading) {
                    Text(alias).font(.caption).foregroundColor(.secondary)
                    TextField("输入 \(alias) 的值", text: Binding(
                        get: { missingVariableDrafts[alias] ?? "" },
                        set: { missingVariableDrafts[alias] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
            Button("保存变量") {
                Task { await handleSaveMissingVariables() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 诊断信息卡片 — AIInvocationReviewPanel.vue:556-562
    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("诊断信息")
                .font(.headline)
            ForEach(diagnostics, id: \.self) { item in
                Text("• \(item)")
                    .font(.body)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 提示词对照面板 — AIInvocationReviewPanel.vue:564-640
    private var promptComparisonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提示词对照")
                .font(.headline)

            // 系统提示词对照
            VStack(alignment: .leading, spacing: 4) {
                Text("系统提示词").font(.caption).foregroundColor(.secondary)
                if isDraftEditable {
                    TextEditor(text: $promptDraftSystem)
                        .frame(minHeight: 80)
                        .border(Theme.textTertiary.opacity(0.3))
                } else {
                    Text(store.draftRuntimeSystem.isEmpty ? store.draftSystemEdited : store.draftRuntimeSystem)
                        .font(.body)
                        .padding(8)
                        .background(Theme.background)
                        .cornerRadius(4)
                }
                if !store.draftRuntimeSystem.isEmpty {
                    Text("运行时预览：").font(.caption).foregroundColor(.secondary)
                    Text(store.draftRuntimeSystem).font(.caption).foregroundColor(.secondary)
                }
            }

            // 用户提示词对照
            VStack(alignment: .leading, spacing: 4) {
                Text("用户提示词").font(.caption).foregroundColor(.secondary)
                if isDraftEditable {
                    TextEditor(text: $promptDraftUser)
                        .frame(minHeight: 60)
                        .border(Theme.textTertiary.opacity(0.3))
                } else {
                    Text(store.draftRuntimeUser.isEmpty ? store.draftUserEdited : store.draftRuntimeUser)
                        .font(.body)
                        .padding(8)
                        .background(Theme.background)
                        .cornerRadius(4)
                }
                if !store.draftRuntimeUser.isEmpty {
                    Text("运行时预览：").font(.caption).foregroundColor(.secondary)
                    Text(store.draftRuntimeUser).font(.caption).foregroundColor(.secondary)
                }
            }

            if store.promptDraftLoading {
                ProgressView("预览中...")
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 变量快照卡片 — AIInvocationReviewPanel.vue:642-693
    private var variableSnapshotCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("变量快照")
                .font(.headline)
            ForEach(visibleVariableSnapshotGroups) { group in
                let groupName = group.groupId ?? "\(group.scope ?? "runtime")_\(group.stage ?? "runtime")"
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(snapshotGroupTitle(group))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: expandedVariableGroups.contains(groupName) ? "chevron.down" : "chevron.right")
                            .onTapGesture {
                                if expandedVariableGroups.contains(groupName) {
                                    expandedVariableGroups.remove(groupName)
                                } else {
                                    expandedVariableGroups.insert(groupName)
                                }
                            }
                    }
                    if expandedVariableGroups.contains(groupName) {
                        ForEach(group.items ?? [], id: \.key) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.displayName ?? item.key ?? "")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if let type = item.type { Text("(\(type))").font(.caption2).foregroundColor(.secondary) }
                                    if item.required == true { Text("必填").font(.caption2).foregroundColor(.red) }
                                    Spacer()
                                    if let scope = item.scope { Text(formatScope(scope)).font(.caption2).foregroundColor(.secondary) }
                                }
                                Text(safeJsonPreview(item.value?.value))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// AI 实时输出区 — AIInvocationReviewPanel.vue:695-710
    private var liveOutputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI 实时输出")
                .font(.headline)
            if store.isGenerating {
                Text("生成中，内容会逐步刷新...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let error = store.attempt?.error, !error.isEmpty {
                Text("错误: \(error)")
                    .font(.body)
                    .foregroundColor(.red)
            }
            Text(store.liveAttemptDisplay)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Theme.background)
                .cornerRadius(4)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 变量中心写入预览卡片 — AIInvocationReviewPanel.vue:712-732
    private var outputPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("变量中心写入预览")
                .font(.headline)
            ForEach(outputPreviewRows, id: \.alias) { row in
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text(row.targetDisplayName).font(.caption).fontWeight(.medium)
                        Text(row.jsonPath).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    if row.previewSource == "continuation" {
                        Text("采纳后派生").font(.caption).foregroundColor(.secondary)
                    } else {
                        Text(safeJsonPreview(row.resolvedValue))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                Divider()
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 采纳决策卡片 — AIInvocationReviewPanel.vue:734-739
    private func decisionCard(_ decision: AdoptionDecisionDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("采纳决策")
                .font(.headline)
            HStack {
                Text(decision.decision)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.primary.opacity(0.2))
                    .cornerRadius(4)
                Spacer()
                Text("决策ID: \(decision.id.prefix(8))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 提交步骤时间线 — AIInvocationReviewPanel.vue:741-751
    private func commitStepsCard(_ commit: AdoptionCommitDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提交步骤")
                .font(.headline)
            ForEach(commit.steps) { step in
                HStack {
                    Circle()
                        .fill(stepStatusColor(step.status))
                        .frame(width: 10, height: 10)
                    Text(step.name).font(.body)
                    Spacer()
                    Text(step.status).font(.caption).foregroundColor(.secondary)
                }
                if let error = step.error, !error.isEmpty {
                    Text("错误: \(error)").font(.caption).foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 底部操作按钮区 — AIInvocationReviewPanel.vue:755-785
    private func bottomActionBar(session: InvocationSessionDTO) -> some View {
        HStack(spacing: 12) {
            Spacer()

            // 批准生成 / 保存并继续
            if session.status == "awaiting_pre_call_review" || session.status == "blocked" {
                Button("批准生成") {
                    Task { await handleResume() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.actionLoading)
            }

            // 重新生成
            if store.canRetry {
                Button("重新生成") {
                    Task { try? await store.retry() }
                }
                .buttonStyle(.bordered)
                .disabled(store.actionLoading)
            }

            // 采纳
            if store.canAccept {
                Button("采纳") {
                    Task { try? await store.accept() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.actionLoading)
            }

            // 提交
            if store.canCommit {
                Button("提交") {
                    Task { try? await store.runCommit() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.actionLoading)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
    }

    // MARK: - 方法（AIInvocationReviewPanel.vue:167-256）

    /// handleResume — AIInvocationReviewPanel.vue:227-240
    private func handleResume() async {
        if !promptDraftValidationErrors.isEmpty { return }
        if isDraftEditable {
            await store.savePromptDraft(system: promptDraftSystem, user: promptDraftUser)
        }
        if !missingVariables.isEmpty {
            await handleSaveMissingVariables()
        }
        guard let session = store.session, session.status != "blocked" else { return }
        do {
            try await store.resume()
        } catch {
            // 错误已在 store.error 中
        }
    }

    /// handleSaveMissingVariables — AIInvocationReviewPanel.vue:242-252
    private func handleSaveMissingVariables() async {
        var values: [String: AnyCodable] = [:]
        for alias in missingVariables {
            let value = missingVariableDrafts[alias] ?? ""
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                values[alias] = AnyCodable(value)
            }
        }
        guard !values.isEmpty else { return }
        do {
            try await store.updateVariables(values: values)
        } catch {
            // 错误已在 store.error 中
        }
    }

    /// 防抖预览 — AIInvocationReviewPanel.vue:149-161
    private func schedulePreviewDebounce() {
        previewDebounceTask?.cancel()
        guard let sessionId = store.session?.id, !sessionId.isEmpty, isDraftEditable else { return }
        if promptDraftSystem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || promptDraftUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.clearPromptDraftPreview()
            return
        }
        // 350ms 防抖
        previewDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await store.previewPromptDraft(system: promptDraftSystem, user: promptDraftUser)
        }
    }

    // MARK: - 辅助方法

    private func infoAlert(title: String, message: String, type: AlertType) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: type == .info ? "info.circle" : "exclamationmark.triangle")
                .foregroundColor(type == .info ? .blue : .orange)
            VStack(alignment: .leading) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(message).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(type == .info ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    private enum AlertType { case info, warning }

    private func formatScope(_ scope: String) -> String {
        switch scope {
        case "global": return "全局变量"
        case "novel": return "小说变量"
        case "chapter": return "章节变量"
        case "scene": return "场景变量"
        case "beat": return "节拍变量"
        case "runtime": return "运行时变量"
        default: return scope
        }
    }

    private func snapshotGroupTitle(_ group: InvocationVariableSnapshotGroup) -> String {
        let title = group.title ?? "\(formatScope(group.scope ?? "runtime"))·\(formatStage(group.stage ?? "runtime"))"
        let count = group.items?.count ?? 0
        return count > 0 ? "\(title)（\(count)项）" : title
    }

    private func formatStage(_ stage: String) -> String {
        switch stage {
        case "setup": return "设定"
        case "worldbuilding": return "世界观"
        case "characters": return "人物"
        case "locations": return "地点"
        case "planning": return "规划"
        case "writing": return "写作"
        case "review": return "审阅"
        case "postprocess": return "后处理"
        case "runtime": return "运行时"
        default: return stage
        }
    }

    private func stepStatusColor(_ status: String) -> Color {
        switch status {
        case "succeeded": return .green
        case "failed": return .red
        default: return .blue
        }
    }
}

// MARK: - 输出预览行模型

struct OutputPreviewRow: Identifiable {
    var id: String { alias }
    let alias: String
    let jsonPath: String
    let target: String
    let targetDisplayName: String
    let previewSource: String
    var resolvedValue: Any? = nil
}

/// 解析输出预览值 — AIInvocationReviewPanel.vue:445-456
private func resolveOutputPreviewValue(source: [String: Any]?, row: OutputPreviewRow) -> Any? {
    let candidates = [row.jsonPath, row.alias, row.target]
    for candidate in candidates {
        if candidate.isEmpty { continue }
        let exact = pickExactOrDottedChildren(source: source, key: candidate)
        if exact != nil { return exact }
        let picked = pickPath(source: source, path: candidate)
        if picked != nil { return picked }
    }
    return nil
}
