//
//  GlobalLLMEntryButton.swift
//  Cangjie
//
//  全局 LLM 入口按钮（sidebar 变体），对齐原版 GlobalLLMEntryButton.vue:13-21 appearance="sidebar"。
//
//  原版 Vue 行为（GlobalLLMEntryButton.vue）：
//  - sidebar 变体：简洁行内按钮，SVG 图标 + "AI 控制台" 文字（:13-21）
//  - 点击 openPanel()（:494-499）→ showPanel=true，首次初始化 llmPanelInitialized=true
//  - Modal 内容（:43-306）：两个 Tab（LLM 设置 / 嵌入模型），LLM Tab 渲染 LLMControlPanel
//  - Modal 样式（:341-346）：width: 92vw, maxWidth: 1100px, height: 85vh, marginTop: 5vh
//  - Runtime 状态栏（:98-113）：显示当前激活模型 + protocol + profile_name
//
//  iOS 实现：
//  - sidebar 变体：List 行内按钮，图标 + "AI 控制台" 文字
//  - 点击弹出 sheet，内含 Form + LLMConfigSection（已存在的设置页 LLM 配置组件）
//  - sheet 头部显示运行时状态栏（当前模型 + protocol + mock 状态）
//
//  注意：GlobalLLMFloatingButton.vue 和 PromptPlazaFAB.vue 在原版 Vue 中是死代码
//  （全前端无任何 import），按主理人决策B跳过，iOS 同步不实现。
//

import SwiftUI

/// 全局 LLM 入口按钮（sidebar 变体）
///
/// 对齐原版 `components/global/GlobalLLMEntryButton.vue` appearance="sidebar"。
/// 放置在 SidebarView 底部，点击弹出 sheet 显示 LLM 控制台配置。
struct GlobalLLMEntryButton: View {

    // MARK: - 状态

    /// 是否显示 AI 控制台 Sheet
    @State private var showConsoleSheet: Bool = false

    // MARK: - Body

    var body: some View {
        Button {
            // 对齐原版 openPanel() — :494-499
            showConsoleSheet = true
        } label: {
            // 对齐原版 sidebar 变体渲染 — :13-21
            // SVG 图标（齿轮+辐射线）+ "AI 控制台" 文字
            HStack(spacing: 8) {
                // 原版 SVG 图标 — :15-18（circle + 辐射线，用 SF Symbol 替代）
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.primary)
                    .frame(width: 24)

                // 原版标题 — :20 "AI 控制台"
                Text("AI 控制台")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textPrimary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showConsoleSheet) {
            // 对齐原版 Modal — :43-306
            aiConsoleSheet
        }
    }

    // MARK: - AI 控制台 Sheet

    /// AI 控制台 Sheet 内容
    ///
    /// 对齐原版 Modal（:43-306）：
    /// - 头部：图标 + "AI 控制台" 标题 + 运行时状态 Tag（:54-75）
    /// - 内容：LLMConfigSection（对齐 LLM Tab 的 LLMControlPanel）
    private var aiConsoleSheet: some View {
        NavigationStack {
            Form {
                // 对齐原版运行时状态栏 — :98-113
                LLMRuntimeSection()

                // 对齐原版 LLM Tab 内容 — :130-136 LLMControlPanel
                LLMConfigSection()
            }
            .navigationTitle("AI 控制台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showConsoleSheet = false
                    }
                }
            }
        }
    }
}

// MARK: - LLM 运行时状态 Section

/// LLM 运行时状态 Section，对齐原版 GlobalLLMEntryButton.vue:98-113。
///
/// 原版显示：
/// - 当前激活模型（runtimeSummary.model 或 "未配置"）
/// - protocol（runtimeSummary.protocol 或 "mock"）
/// - active_profile_name / reason（runtimeSummary.active_profile_name 或 runtimeSummary.reason）
private struct LLMRuntimeSection: View {

    @StateObject private var llmStore = LLMControlStore()

    var body: some View {
        Section {
            // 对齐原版 :99-100 global-llm-runtime-label
            Text("当前激活模型")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)

            // 对齐原版 :101-103 global-llm-runtime-model
            HStack(spacing: 6) {
                Text(llmStore.panelData?.runtime.model ?? "未配置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                // 对齐原版 :106-108 global-llm-runtime-chip（protocol/mock 标签）
                if llmStore.isUsingMock {
                    Text("Mock")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.warning.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(Theme.warning)
                } else if let proto = llmStore.panelData?.runtime.`protocol` {
                    Text(proto)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.info.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(Theme.info)
                }
            }

            // 对齐原版 :109-111 global-llm-runtime-name
            if let profileName = llmStore.panelData?.runtime.activeProfileName, !profileName.isEmpty {
                Text(profileName)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
        } header: {
            Text("运行时状态")
        }
        .task {
            // 对齐原版 refreshRuntimeSummary() — :348-358
            await llmStore.loadPanelData()
        }
    }
}
