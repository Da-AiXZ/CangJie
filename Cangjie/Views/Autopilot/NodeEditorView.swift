//
//  NodeEditorView.swift
//  Cangjie
//
//  DAG 节点 Prompt 编辑器 UI — 对齐原项目 nodeEditorStore.ts + NodeContextMenu.vue
//  SwiftUI sheet：模板文本编辑器 + 变量键值对列表 + 本地预览/服务端预览切换 + 保存/重置按钮
//

import SwiftUI

/// DAG 节点 Prompt 编辑器视图 — sheet 呈现
struct NodeEditorView: View {

    @ObservedObject private var store = NodeEditorStore.shared

    /// 预览模式
    @State private var previewMode: PreviewMode = .local

    /// 变量列表（用于动态增删 UI）
    @State private var variablePairs: [VariablePair] = []

    /// 新变量键名输入
    @State private var newVarKey: String = ""

    /// 保存错误提示
    @State private var saveError: String?

    /// 预览模式枚举
    enum PreviewMode: String, CaseIterable {
        case local = "本地预览"
        case server = "服务端预览"
    }

    /// 变量键值对（用于动态增删）
    struct VariablePair: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                    // MARK: 模板编辑区
                    templateSection

                    // MARK: 变量区
                    variablesSection

                    // MARK: 预览区
                    previewSection

                    // MARK: 错误提示
                    if let error = saveError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.error)
                            .padding(.horizontal)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.background)
            .navigationTitle("编辑 Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        store.close()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        // 重置按钮 — hasUnsavedChanges 为 false 时禁用
                        Button("重置") {
                            store.resetToDefault()
                            syncVariablePairs()
                        }
                        .disabled(!store.hasUnsavedChanges)

                        // 保存按钮 — hasUnsavedChanges 为 false 时禁用
                        Button("保存") {
                            Task {
                                do {
                                    saveError = nil
                                    syncVariablesToStore()
                                    try await store.save()
                                } catch {
                                    saveError = "保存失败：\(error.localizedDescription)"
                                }
                            }
                        }
                        .disabled(!store.hasUnsavedChanges || store.isSaving)
                    }
                }
            }
            .onChange(of: store.promptTemplate) { _ in
                if previewMode == .local {
                    store.renderLocalPreview()
                }
            }
        }
    }

    // MARK: - 模板编辑区

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Prompt 模板")
                    .font(Theme.headlineFont())
                Spacer()
                if store.hasUnsavedChanges {
                    Text("未保存")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.warning.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            TextEditor(text: $store.promptTemplate)
                .font(.system(size: 13, design: .monospaced))
                .frame(minHeight: 200)
                .padding(Theme.Spacing.sm)
                .background(Theme.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .scrollContentBackground(.hidden)
        }
        .cardStyle()
    }

    // MARK: - 变量区

    private var variablesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("变量")
                .font(Theme.headlineFont())

            // 变量键值对列表（动态增删）
            ForEach($variablePairs) { $pair in
                HStack(spacing: 8) {
                    Text("{{\(pair.key)}}")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 120, alignment: .leading)

                    TextField("值", text: $pair.value)
                        .font(.system(size: 13))
                        .textFieldStyle(.roundedBorder)

                    Button {
                        removeVariable(pair)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(Theme.error)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 添加新变量
            HStack(spacing: 8) {
                TextField("变量名", text: $newVarKey)
                    .font(.system(size: 13))
                    .textFieldStyle(.roundedBorder)

                Button {
                    addVariable()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.primary)
                }
                .buttonStyle(.plain)
                .disabled(newVarKey.isEmpty)
            }

            Text("使用 {{变量名}} 在模板中引用变量")
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
        }
        .cardStyle()
    }

    // MARK: - 预览区

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("预览")
                    .font(Theme.headlineFont())
                Spacer()
                Picker("预览模式", selection: $previewMode) {
                    ForEach(PreviewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            if store.isPreviewLoading {
                ProgressView("加载服务端预览…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if store.renderedPrompt.isEmpty {
                Text("点击预览查看渲染结果")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    Text(store.renderedPrompt)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.sm)
                }
                .frame(minHeight: 100, maxHeight: 200)
                .background(Theme.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
            }

            // 本地预览按钮
            if previewMode == .local {
                Button("刷新本地预览") {
                    syncVariablesToStore()
                    store.renderLocalPreview()
                }
                .buttonStyle(.bordered)
            } else {
                Button("加载服务端预览") {
                    syncVariablesToStore()
                    Task { await store.loadPreview() }
                }
                .buttonStyle(.bordered)
            }
        }
        .cardStyle()
    }

    // MARK: - 辅助方法

    /// 添加变量
    private func addVariable() {
        let key = newVarKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        variablePairs.append(VariablePair(key: key, value: ""))
        newVarKey = ""
    }

    /// 删除变量
    private func removeVariable(_ pair: VariablePair) {
        variablePairs.removeAll { $0.id == pair.id }
    }

    /// 同步变量到 store
    private func syncVariablesToStore() {
        var dict: [String: String] = [:]
        for pair in variablePairs {
            dict[pair.key] = pair.value
        }
        store.variables = dict
    }

    /// 从 store 同步变量到 UI
    private func syncVariablePairs() {
        variablePairs = store.variables.map { VariablePair(key: $0.key, value: $0.value) }
    }
}
