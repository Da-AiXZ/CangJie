//
//  PromptDetailView.swift
//  Cangjie
//
//  模板详情：系统提示+用户模板+变量+版本历史+渲染测试+调试。
//  TextEditor 编辑，版本列表，渲染按钮，调试结果区。
//

import SwiftUI

/// 提示词详情视图
struct PromptDetailView: View {

    let node: PromptNode

    @EnvironmentObject var store: PromptPlazaStore

    @State private var content: String = ""
    @State private var showVersionCompare = false
    @State private var renderVariables: [String: String] = [:]
    @State private var renderInput: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // 标题区
                headerSection

                // 内容编辑
                contentSection

                // 变量
                if let variables = node.variables, !variables.isEmpty {
                    variablesSection(variables)
                }

                // 渲染测试
                renderSection

                // 调试结果
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
        .navigationTitle(node.title ?? node.nodeKey)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    Task {
                        await store.updatePrompt(nodeKey: node.nodeKey, content: content, changeLog: nil)
                    }
                }
            }
        }
        .task {
            content = node.content ?? ""
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
                if let category = node.category {
                    Text(category)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.primary.opacity(0.2))
                        .cornerRadius(4)
                }

                if let enabled = node.enabled, !enabled {
                    Text("已禁用")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.textTertiary.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if let desc = node.description, !desc.isEmpty {
                Text(desc)
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    // MARK: - 内容编辑

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("提示词内容")
                .font(Theme.headlineFont())

            TextEditor(text: $content)
                .font(.system(size: 13, design: .monospaced))
                .frame(minHeight: 200)
                .padding(Theme.Spacing.sm)
                .background(Theme.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .scrollContentBackground(.hidden)
        }
        .cardStyle()
    }

    // MARK: - 变量

    private func variablesSection(_ variables: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("变量")
                .font(Theme.headlineFont())

            ForEach(variables, id: \.self) { variable in
                HStack {
                    Image(systemName: "curlybraces")
                        .foregroundColor(Theme.primary)
                    Text("{{\(variable)}}")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
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
                    Task { await store.renderPrompt(nodeKey: node.nodeKey, variables: parseVariables()) }
                }
                .buttonStyle(.bordered)

                Button("调试") {
                    Task { await store.debugPrompt(nodeKey: node.nodeKey, variables: parseVariables()) }
                }
                .buttonStyle(.bordered)
            }

            if let result = store.renderResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("渲染结果")
                        .font(.system(size: 12, weight: .medium))
                    Text(result.rendered)
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

    // MARK: - 调试结果

    private func debugSection(_ debug: PromptDebugResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("调试结果")
                .font(Theme.headlineFont())

            if let response = debug.modelResponse {
                VStack(alignment: .leading, spacing: 4) {
                    Text("模型响应")
                        .font(.system(size: 12, weight: .medium))
                    ScrollView {
                        Text(response)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxHeight: 150)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.tertiaryBackground)
                    .cornerRadius(Theme.CornerRadius.small)
                }
            }

            HStack(spacing: Theme.Spacing.lg) {
                if let input = debug.tokenInput {
                    Label("\(input)", systemImage: "arrow.down")
                        .font(.system(size: 11))
                }
                if let output = debug.tokenOutput {
                    Label("\(output)", systemImage: "arrow.up")
                        .font(.system(size: 11))
                }
                if let latency = debug.latencyMs {
                    Label("\(latency)ms", systemImage: "clock")
                        .font(.system(size: 11))
                }
            }
            .foregroundColor(Theme.textTertiary)

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
                        if let log = version.changeLog, !log.isEmpty {
                            Text(log)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        if let date = version.createdAt {
                            Text(date)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }

                    Spacer()

                    Button("回滚") {
                        Task { await store.rollbackPrompt(nodeKey: node.nodeKey, versionId: version.id) }
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

    private func parseVariables() -> [String: String] {
        guard let data = renderInput.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }
}
