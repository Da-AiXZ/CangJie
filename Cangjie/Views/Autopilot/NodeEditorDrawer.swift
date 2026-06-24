//
//  NodeEditorDrawer.swift
//  Cangjie
//
//  DAG 节点运行参数配置抽屉（.sheet 呈现）。
//  对齐 NodeEditorDrawer.vue:1-296（18条功能点）。
//  决策8：原版组件未被 import，iOS 版必须实现并接入。
//  决策5：getCpmsKey + "在广场编辑"按钮（NavigationLink 或提示）。
//

import SwiftUI

/// DAG 节点配置抽屉 — 对齐 NodeEditorDrawer.vue:1-296
struct NodeEditorDrawer: View {

    // MARK: - Props

    let novelId: String
    let nodeId: String

    @EnvironmentObject var dagStore: DAGStore
    @Environment(\.dismiss) private var dismiss

    // MARK: - 本地配置状态（对齐 NodeEditorDrawer.vue:122-128 localConfig）

    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int? = nil
    @State private var maxTokensText: String = ""
    @State private var timeoutSeconds: Int = 60
    @State private var maxRetries: Int = 1
    @State private var modelOverride: String = ""

    // MARK: - UI 状态

    @State private var cpmsNodeKey: String? = nil
    @State private var showPlazaHint: Bool = false
    @State private var saveSuccess: Bool = false

    // MARK: - 计算属性

    /// 抽屉标题 — 对齐 NodeEditorDrawer.vue:138-143 drawerTitle
    private var drawerTitle: String {
        if let key = cpmsNodeKey, !key.isEmpty {
            return "节点配置 — \(key)"
        }
        return "节点配置"
    }

    /// 是否有配置变更 — 对齐 NodeEditorDrawer.vue:145-153 hasConfigChanges
    private var hasConfigChanges: Bool {
        temperature != 0.7 ||
        maxTokens != nil ||
        timeoutSeconds != 60 ||
        maxRetries != 1 ||
        !modelOverride.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // 对齐 NodeEditorDrawer.vue:11-25 CPMS 关联信息 + 跳转广场
                if let key = cpmsNodeKey, !key.isEmpty {
                    Section {
                        cpmsSection(key: key)
                    }
                }

                // 对齐 NodeEditorDrawer.vue:27-90 运行参数
                Section("运行参数") {
                    // 对齐 NodeEditorDrawer.vue:29-45 温度
                    HStack {
                        Text("温度")
                            .frame(width: 100, alignment: .leading)
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.1f", temperature))
                            .frame(width: 50)
                            .font(.system(size: 12, design: .monospaced))
                    }

                    // 对齐 NodeEditorDrawer.vue:47-57 最大 Tokens
                    HStack {
                        Text("最大 Tokens")
                            .frame(width: 100, alignment: .leading)
                        TextField("默认", text: $maxTokensText)
                            .keyboardType(.numberPad)
                            .frame(width: 160)
                    }

                    // 对齐 NodeEditorDrawer.vue:59-69 超时时间
                    HStack {
                        Text("超时时间")
                            .frame(width: 100, alignment: .leading)
                        TextField("60", value: $timeoutSeconds, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 160)
                        Text("秒")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }

                    // 对齐 NodeEditorDrawer.vue:71-79 最大重试
                    HStack {
                        Text("最大重试")
                            .frame(width: 100, alignment: .leading)
                        Stepper("\(maxRetries)", value: $maxRetries, in: 0...5)
                    }

                    // 对齐 NodeEditorDrawer.vue:81-89 模型覆盖
                    HStack {
                        Text("模型覆盖")
                            .frame(width: 100, alignment: .leading)
                        TextField("留空使用默认模型", text: $modelOverride)
                    }
                }

                if saveSuccess {
                    Section {
                        Label("节点参数保存成功", systemImage: "checkmark.circle.fill")
                            .foregroundColor(Theme.statusSuccess)
                    }
                }
            }
            .navigationTitle(drawerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                // 对齐 NodeEditorDrawer.vue:97-103 保存按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        handleSaveConfig()
                    } label: {
                        Text("保存参数")
                            .fontWeight(.semibold)
                    }
                    .disabled(!hasConfigChanges)
                }
            }
            .alert("提示词广场", isPresented: $showPlazaHint) {
                Button("确定", role: .cancel) {}
            } message: {
                if let key = cpmsNodeKey, !key.isEmpty {
                    Text("请在提示词广场中搜索: \(key)")
                } else {
                    Text("请在提示词广场中查找该节点关联的提示词")
                }
            }
        }
        .onAppear {
            loadConfig()
        }
    }

    // MARK: - CPMS 关联信息区（对齐 NodeEditorDrawer.vue:11-25）

    @ViewBuilder
    private func cpmsSection(key: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // 对齐 NodeEditorDrawer.vue:13 cpms-icon
                Text("🏪")
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("关联提示词")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    // 对齐 NodeEditorDrawer.vue:16 cpms-key
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                // 对齐 NodeEditorDrawer.vue:18-20 在广场编辑按钮
                // 决策5：PromptPlazaStore 无跳转方法，先实现为提示
                Button("在广场编辑") {
                    showPlazaHint = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            // 对齐 NodeEditorDrawer.vue:22-24 cpms-hint
            Text("点击「在广场编辑」打开提示词广场，支持编辑、版本管理、回滚。")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
    }

    // MARK: - 加载本地配置（对齐 NodeEditorDrawer.vue:170-179 loadLocalConfig）

    private func loadConfig() {
        // 对齐 NodeEditorDrawer.vue:157-168 open → 获取 cpmsNodeKey + loadLocalConfig
        guard let dag = dagStore.dagDefinition else { return }
        guard let node = dag.nodes.first(where: { $0.id == nodeId }) else { return }

        // 决策5：getCpmsKey — 从 nodeTypeRegistry 或 registryLinkage 取
        cpmsNodeKey = getCpmsKey(nodeType: node.type)

        // 对齐 NodeEditorDrawer.vue:172-178 loadLocalConfig
        let config = node.config
        temperature = config?.temperature ?? 0.7
        maxTokens = config?.maxTokens
        maxTokensText = maxTokens.map { String($0) } ?? ""
        timeoutSeconds = config?.timeoutSeconds ?? 60
        maxRetries = config?.maxRetries ?? 1
        modelOverride = config?.modelOverride ?? ""
    }

    // MARK: - getCpmsKey（决策5）

    /// 从 nodeTypeRegistry 或 registryLinkage 获取 CPMS Key — 决策5
    private func getCpmsKey(nodeType: String) -> String? {
        // 优先从 nodeTypeRegistry 取
        if let key = dagStore.nodeTypeRegistry[nodeType]?.cpmsNodeKey, !key.isEmpty {
            return key
        }
        // 回退从 registryLinkage 取
        if let entry = dagStore.registryLinkage?.registryCpmsByType[nodeType], !entry.cpmsNodeKey.isEmpty {
            return entry.cpmsNodeKey
        }
        return nil
    }

    // MARK: - 保存配置（对齐 NodeEditorDrawer.vue:183-204 handleSaveConfig）

    private func handleSaveConfig() {
        // 对齐 NodeEditorDrawer.vue:184-185
        guard !nodeId.isEmpty, dagStore.dagDefinition != nil else { return }

        // 对齐 NodeEditorDrawer.vue:187-197 构建 config 字典
        var config: [String: Any] = [
            "temperature": temperature,
            "timeout_seconds": timeoutSeconds,
            "max_retries": maxRetries,
        ]
        // 对齐 NodeEditorDrawer.vue:192-193 if maxTokens !== null
        if let maxTokens = maxTokens {
            config["max_tokens"] = maxTokens
        }
        // 对齐 NodeEditorDrawer.vue:195-196 if modelOverride
        if !modelOverride.isEmpty {
            config["model_override"] = modelOverride
        }

        // 对齐 NodeEditorDrawer.vue:199 dagStore.updateNodeConfig（内存更新）
        dagStore.updateNodeConfig(novelId: novelId, nodeId: nodeId, config: config)

        // 对齐 NodeEditorDrawer.vue:200 message.success
        saveSuccess = true
        // 2秒后清除成功提示
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                saveSuccess = false
            }
        }
    }
}
