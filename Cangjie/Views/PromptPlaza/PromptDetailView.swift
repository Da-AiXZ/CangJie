//
//  PromptDetailView.swift
//  Cangjie
//
//  模板详情：系统提示+用户模板+变量+版本历史+渲染测试+调试。
//  对齐原版 llmControl.ts:162-194 PromptNodeDetail + llmControl.ts:223-239 DebugResult。
//

import SwiftUI

/// 提示词详情视图
struct PromptDetailView: View {

    let node: PromptNode

    @EnvironmentObject var store: PromptPlazaStore

    @State private var systemContent: String = ""
    @State private var userTemplateContent: String = ""
    @State private var showVersionCompare = false
    @State private var renderInput: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // 标题区
                headerSection

                // 内容编辑（从 currentNodeDetail 获取完整内容）
                contentSection

                // 变量（llmControl.ts:149 variables: [PromptVariable]）
                if !node.variables.isEmpty {
                    variablesSection(node.variables)
                }

                // 渲染测试
                renderSection

                // 调试结果（llmControl.ts:223-239 DebugResult）
                if let debug = store.debugResult {
                    debugSection(debug)
                }

                // 版本历史
                if !store.versions.isEmpty {
                    versionsSection
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
        .navigationTitle(node.name.isEmpty ? node.nodeKey : node.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    Task {
                        // llmControl.ts:319-326 PromptUpdatePayload
                        await store.updateNode(
                            nodeKey: node.nodeKey,
                            payload: PromptUpdatePayload(
                                system: systemContent,
                                userTemplate: userTemplateContent
                            )
                        )
                    }
                }
            }
        }
        .task {
            // 加载节点详情获取完整内容
            await store.loadNodeDetail(nodeKey: node.nodeKey)
            systemContent = store.currentNodeDetail?.system ?? node.systemPreview
            userTemplateContent = store.currentNodeDetail?.userTemplate ?? node.userTemplatePreview
            await store.loadVersions(nodeKey: node.nodeKey)
        }
        .sheet(isPresented: $showVersionCompare) {
            PromptVersionCompareView(
                versions: store.versions,
                onCompare: { v1Id, v2Id in
                    Task { await store.compareVersions(v1Id: v1Id, v2Id: v2Id) }
                },
                comparison: store.comparison
            )
        }
    }

    // MARK: - 标题区

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                if !node.category.isEmpty {
                    Text(node.category)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.primary.opacity(0.2))
                        .cornerRadius(4)
                }

                // llmControl.ts:152 is_builtin（原 enabled→is_builtin，内置标记）
                if node.isBuiltin {
                    Text("内置")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.info.opacity(0.2))
                        .cornerRadius(4)
                }

                // llmControl.ts:158 has_user_edit
                if node.hasUserEdit {
                    Text("已编辑")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.warning.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if !node.description.isEmpty {
                Text(node.description)
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    // MARK: - 内容编辑

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("系统提示")
                .font(Theme.headlineFont())

            TextEditor(text: $systemContent)
                .font(.system(size: 13, design: .monospaced))
                .frame(minHeight: 120)
                .padding(Theme.Spacing.sm)
                .background(Theme.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .scrollContentBackground(.hidden)

            Text("用户模板")
                .font(Theme.headlineFont())

            TextEditor(text: $userTemplateContent)
                .font(.system(size: 13, design: .monospaced))
                .frame(minHeight: 120)
                .padding(Theme.Spacing.sm)
                .background(Theme.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .scrollContentBackground(.hidden)
        }
        .cardStyle()
    }

    // MARK: - 变量（llmControl.ts:129-135 PromptVariable）

    private func variablesSection(_ variables: [PromptVariable]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("变量")
                .font(Theme.headlineFont())

            ForEach(variables, id: \.name) { variable in
                HStack {
                    Image(systemName: "curlybraces")
                        .foregroundColor(Theme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("{{\(variable.name)}}")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                            Text("(\(variable.type))")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                            if variable.required == true {
                                Text("必填")
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.error)
                            }
                        }
                        if !variable.desc.isEmpty {
                            Text(variable.desc)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 渲染测试

    private var renderSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("渲染测试")
                .font(Theme.headlineFont())

            TextField("输入变量 JSON（可选）", text: $renderInput, axis: .vertical)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 60)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("渲染") {
                    Task {
                        // llmControl.ts:428 renderPrompt — payload: { variables: Record<string, unknown> }
                        await store.renderPrompt(nodeKey: node.nodeKey, variables: parseVariables())
                    }
                }
                .buttonStyle(.bordered)

                Button("调试") {
                    Task {
                        // llmControl.ts:450 debugNode — 请求体含 validate_schemas=true
                        await store.debugNode(nodeKey: node.nodeKey, variables: parseVariables())
                    }
                }
                .buttonStyle(.bordered)
            }

            // llmControl.ts:217-220 RenderResult — system + user
            if let result = store.renderResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("渲染结果")
                        .font(.system(size: 12, weight: .medium))
                    Text("System:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                    Text(result.system)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.tertiaryBackground)
                        .cornerRadius(Theme.CornerRadius.small)
                    Text("User:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                    Text(result.user)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.tertiaryBackground)
                        .cornerRadius(Theme.CornerRadius.small)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 调试结果（llmControl.ts:223-239 DebugResult + DebugDiagnostics）

    private func debugSection(_ debug: DebugResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("调试结果")
                .font(Theme.headlineFont())

            // llmControl.ts:224 success
            HStack {
                Image(systemName: debug.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(debug.success ? Theme.success : Theme.error)
                Text(debug.success ? "成功" : "失败")
                    .font(.system(size: 12, weight: .medium))
            }

            // llmControl.ts:227-233 diagnostics
            let diag = debug.diagnostics
            if !diag.errors.isEmpty {
                diagnosticsList(title: "错误", items: diag.errors, color: Theme.error)
            }
            if !diag.warnings.isEmpty {
                diagnosticsList(title: "警告", items: diag.warnings, color: Theme.warning)
            }
            if !diag.missingVariables.isEmpty {
                diagnosticsList(title: "缺失变量", items: diag.missingVariables, color: Theme.warning)
            }
            if !diag.missingRequired.isEmpty {
                diagnosticsList(title: "缺失必填", items: diag.missingRequired, color: Theme.error)
            }
            if !diag.renderedVariables.isEmpty {
                diagnosticsList(title: "已渲染变量", items: diag.renderedVariables, color: Theme.success)
            }

            // llmControl.ts:234-237 nodeKey/nodeName/variablesProvided/elapsedMs
            HStack(spacing: Theme.Spacing.lg) {
                Label("\(debug.variablesProvided.count)", systemImage: "curlybraces")
                    .font(.system(size: 11))
                Label("\(debug.elapsedMs)ms", systemImage: "clock")
                    .font(.system(size: 11))
            }
            .foregroundColor(Theme.textTertiary)

            // llmControl.ts:238 error
            if let error = debug.error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.error)
            }
        }
        .cardStyle()
    }

    // MARK: - 版本历史

    private var versionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("版本历史")
                    .font(Theme.headlineFont())
                Spacer()
                Button("版本对比") {
                    showVersionCompare = true
                }
                .font(.system(size: 12))
            }

            ForEach(store.versions) { version in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("v\(version.versionNumber)")
                            .font(.system(size: 13, weight: .semibold))
                        // llmControl.ts:183 change_summary（原 changeLog→changeSummary）
                        if !version.changeSummary.isEmpty {
                            Text(version.changeSummary)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        // llmControl.ts:185 created_at
                        Text(version.createdAt)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }

                    Spacer()

                    Button("回滚") {
                        Task { await store.rollbackNode(nodeKey: node.nodeKey, versionId: version.id) }
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .cardStyle()
    }

    // MARK: - 辅助

    private func parseVariables() -> [String: AnyCodable] {
        guard let data = renderInput.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict.mapValues { AnyCodable($0) }
    }

    private func diagnosticsList(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(title) (\(items.count))")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
            ForEach(items, id: \.self) { item in
                Text("  · \(item)")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}
