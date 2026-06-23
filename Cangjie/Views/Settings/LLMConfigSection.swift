//
//  LLMConfigSection.swift
//  Cangjie
//
//  模型引擎：端点列表 CRUD + 新建/编辑/测试/拉取模型 + 设为默认。
//  对齐 Vue3 LLM 控制面板的交互。
//

import SwiftUI

/// LLM 配置设置分区
struct LLMConfigSection: View {

    @StateObject private var llmStore = LLMControlStore()

    @State private var showEditSheet = false
    @State private var editingProfile: LLMProfile?
    @State private var showFetchModels = false

    var body: some View {
        // 端点列表
        ForEach(llmStore.profiles) { profile in
            profileRow(profile)
        }

        // 新建端点
        Button {
            editingProfile = nil
            showEditSheet = true
        } label: {
            Label("新建端点", systemImage: "plus.circle.fill")
        }

        // Mock 状态警告
        if llmStore.isUsingMock {
            Label("当前使用 Mock 模式，请在下方配置真实端点", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(Theme.warning)
        }

        // 运行时信息
        if let runtime = llmStore.panelData?.runtime {
            VStack(alignment: .leading, spacing: 2) {
                if let model = runtime.model {
                    Text("当前模型：\(model)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                if let baseUrl = runtime.baseUrl {
                    Text("端点：\(baseUrl)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    .task {
        await llmStore.loadPanelData()
    }
    .sheet(isPresented: $showEditSheet) {
        editProfileSheet
    }
    .sheet(isPresented: $showFetchModels) {
        fetchModelsSheet
    }

    // MARK: - 端点行

    private func profileRow(_ profile: LLMProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(profile.name)
                    .font(.system(size: 14, weight: .medium))
                if profile.id == llmStore.activeProfile?.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.success)
                }
            }
            Text(profile.model)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
            Text(profile.baseUrl)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
                .lineLimit(1)
        }
        .swipeActions {
            Button {
                Task {
                    // 设为默认
                }
            } label: {
                Label("默认", systemImage: "star.fill")
            }
            .tint(.yellow)

            Button(role: .destructive) {
                // 删除
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                Task { await llmStore.testConnection(profileId: profile.id) }
            } label: {
                Label("测试连通性", systemImage: "antenna.radiowaves.left.and.right")
            }

            Button {
                editingProfile = profile
                showEditSheet = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }

            Button {
                showFetchModels = true
            } label: {
                Label("拉取模型列表", systemImage: "arrow.down.circle")
            }
        }
    }

    // MARK: - 编辑 Sheet

    private var editProfileSheet: some View {
        NavigationStack {
            LLMProfileEditView(profile: editingProfile, store: llmStore) {
                showEditSheet = false
                Task { await llmStore.loadPanelData() }
            }
        }
    }

    // MARK: - 拉取模型 Sheet

    private var fetchModelsSheet: some View {
        NavigationStack {
            VStack {
                if llmStore.isFetchingModels {
                    VStack(spacing: Theme.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在拉取模型列表…")
                            .font(Theme.bodyFont())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxHeight: .infinity)
                } else if !llmStore.modelList.isEmpty {
                    List(llmStore.modelList) { model in
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(Theme.primary)
                            VStack(alignment: .leading) {
                                Text(model.name)
                                    .font(Theme.bodyFont())
                                Text(model.ownedBy)
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                    }
                } else {
                    Text("暂无模型，请先配置端点并测试连通性")
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("模型列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showFetchModels = false }
                }
            }
        }
    }
}

// MARK: - LLM Profile 编辑视图

/// LLM 端点编辑视图
struct LLMProfileEditView: View {

    let profile: LLMProfile?
    @ObservedObject var store: LLMControlStore
    var onSaved: () -> Void

    @State private var name: String = ""
    @State private var baseUrl: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 16000
    @State private var timeoutSeconds: Int = 300
    @State private var protocolType: String = "openai"

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("名称", text: $name)
                TextField("Base URL", text: $baseUrl)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                SecureField("API Key", text: $apiKey)
                TextField("模型名", text: $model)
                    .autocapitalization(.none)
                Picker("协议", selection: $protocolType) {
                    Text("OpenAI").tag("openai")
                    Text("Anthropic").tag("anthropic")
                    Text("Custom").tag("custom")
                }
            }

            Section("参数") {
                VStack(alignment: .leading) {
                    Text("Temperature：\(String(format: "%.1f", temperature))")
                    Slider(value: $temperature, in: 0...2, step: 0.1)
                }
                Stepper("Max Tokens：\(maxTokens)", value: $maxTokens, in: 100...128000, step: 1000)
                Stepper("超时：\(timeoutSeconds)s", value: $timeoutSeconds, in: 30...600, step: 30)
            }

            Section("操作") {
                Button("测试连通性") {
                    Task { await store.testConnection(profileId: profile?.id) }
                }
                .disabled(name.isEmpty || baseUrl.isEmpty)
            }

            // 测试结果
            if let result = store.testResult {
                Section("测试结果") {
                    HStack {
                        Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.ok ? Theme.success : Theme.error)
                        Text(result.ok ? "成功" : "失败")
                            .font(Theme.bodyFont())
                    }
                    if result.ok {
                        Text("延迟：\(result.latencyMs)ms")
                            .font(.system(size: 12))
                        Text("预览：\(result.preview.prefix(100))")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    } else if let error = result.error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.error)
                    }
                }
            }
        }
        .navigationTitle(profile == nil ? "新建端点" : "编辑端点")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") { onSaved() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    // 保存逻辑（简化版）
                    onSaved()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            if let profile = profile {
                name = profile.name
                baseUrl = profile.baseUrl
                apiKey = profile.apiKey
                model = profile.model
                temperature = profile.temperature
                maxTokens = profile.maxTokens
                timeoutSeconds = profile.timeoutSeconds
                protocolType = profile.protocol
            }
        }
    }
}
