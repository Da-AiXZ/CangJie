//
//  EngineMatrixView.swift
//  Cangjie
//
//  多 provider 端点网格 + 推理折叠配置。
//  对齐原版 LLM Control 面板中的 Engine Matrix 区域。
//

import SwiftUI

/// 引擎端点矩阵视图
///
/// 显示多 provider 端点网格 + 推理折叠配置。
struct EngineMatrixView: View {
    @State private var panelData: LLMControlPanelData?
    @State private var loading: Bool = false
    @State private var expandedProfile: String? = nil

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Label("引擎端点矩阵", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.primary)
                Spacer()
                if loading {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Button {
                        Task { await loadPanel() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 端点网格
            if let panel = panelData {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        // 活跃配置
                        if let activeId = panel.config.activeProfileId {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(Theme.success)
                                Text("活跃配置")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(activeId)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.success.opacity(0.08))
                            .cornerRadius(6)
                        }

                        // Provider 网格
                        Text("Provider 端点")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.top, 4)

                        ForEach(panel.config.profiles) { profile in
                            profileCard(profile)
                        }

                        // 推理折叠配置
                        if !panel.config.profiles.isEmpty {
                            Divider().padding(.vertical, 4)
                            Text("推理折叠")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                                .padding(.horizontal, 12)

                            ForEach(panel.config.profiles) { profile in
                                reasoningCollapseRow(profile)
                            }
                        }
                    }
                    .padding(8)
                }
            } else if loading {
                ProgressView("加载引擎配置…")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text("暂无引擎配置数据")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .background(Theme.background)
        .task {
            if panelData == nil {
                await loadPanel()
            }
        }
    }

    // MARK: - Provider 卡片

    @ViewBuilder
    private func profileCard(_ profile: LLMProfile) -> some View {
        let isExpanded = expandedProfile == profile.id
        let isActive = panelData?.config.activeProfileId == profile.id

        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedProfile = isExpanded ? nil : profile.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Text(profile.protocol)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    if isActive {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Theme.success)
                            .font(.system(size: 8))
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isActive ? Theme.primary.opacity(0.05) : Theme.secondaryBackground)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    detailRow("模型", profile.model)
                    detailRow("Base URL", profile.baseUrl)
                    if profile.maxTokens > 0 {
                        detailRow("最大 Token", "\(profile.maxTokens)")
                    }
                    if profile.temperature > 0 {
                        detailRow("温度", String(format: "%.1f", profile.temperature))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.tertiaryBackground)
                .cornerRadius(6)
            }
        }
    }

    // MARK: - 推理折叠行

    @ViewBuilder
    private func reasoningCollapseRow(_ profile: LLMProfile) -> some View {
        HStack {
            Text(profile.name)
                .font(.system(size: 11))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(profile.protocol)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
            if profile.protocol.lowercased().contains("openai") {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(Theme.primary)
                    .font(.system(size: 10))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Theme.secondaryBackground)
        .cornerRadius(4)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - 数据加载

    private func loadPanel() async {
        loading = true
        do {
            panelData = try await apiClient.request(APIEndpoint.LLMControl.panel)
        } catch {
            panelData = nil
        }
        loading = false
    }
}
