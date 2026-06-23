//
//  ContextPanelTabView.swift
//  Cangjie
//
//  右栏：TabView 切换上下文面板。
//  T04 已填充全部 Panel 组件（伏笔/角色心理/质量护栏/世界观/道具/上下文装配 + 章节结构）。
//

import SwiftUI

/// 上下文面板 TabView
struct ContextPanelTabView: View {

    @EnvironmentObject var novelStore: NovelStore
    @EnvironmentObject var workbenchStore: WorkbenchStore

    var body: some View {
        TabView {
            // 章节结构分析
            ChapterStructurePanel()
                .environmentObject(workbenchStore)
                .tabItem {
                    Label("结构", systemImage: "chart.bar.fill")
                }

            // 伏笔手账
            ForeshadowLedgerPanel()
                .tabItem {
                    Label("伏笔", systemImage: "lightbulb.fill")
                }

            // 角色心理
            CharacterPsychePanel()
                .tabItem {
                    Label("角色心理", systemImage: "brain.head.profile")
                }

            // 质量护栏
            QualityGuardrailPanel()
                .tabItem {
                    Label("质量护栏", systemImage: "shield.checkered")
                }

            // 世界观
            WorldbuildingPanel()
                .tabItem {
                    Label("世界观", systemImage: "globe.asia.australia.fill")
                }

            // 道具
            PropManagerPanel()
                .tabItem {
                    Label("道具", systemImage: "shippingbox.fill")
                }

            // 上下文装配
            ContextAssemblyPanel()
                .environmentObject(novelStore)
                .tabItem {
                    Label("上下文", systemImage: "rectangle.stack.fill")
                }

            // 章节元素
            ChapterElementPanel()
                .environmentObject(novelStore)
                .tabItem {
                    Label("元素", systemImage: "square.grid.2x2.fill")
                }

            // 故事线
            StorylinePanel()
                .tabItem {
                    Label("故事线", systemImage: "lineweight")
                }

            // 故事阶段
            StoryPhasePanel()
                .tabItem {
                    Label("阶段", systemImage: "flag.fill")
                }

            // 文风金库
            VoiceVaultPanel()
                .tabItem {
                    Label("文风", systemImage: "waveform")
                }

            // Anti-AI 防御
            AntiAIPanel()
                .environmentObject(workbenchStore)
                .tabItem {
                    Label("Anti-AI", systemImage: "sparkles.magnifyingglass")
                }

            // 对话沙盒
            DialogueSandboxPanel()
                .tabItem {
                    Label("对话", systemImage: "text.bubble.fill")
                }

            // 故事演化
            StoryEvolutionPanel()
                .tabItem {
                    Label("演化", systemImage: "clock.arrow.circlepath")
                }

            // 编年史
            ChroniclesPanel()
                .tabItem {
                    Label("编年史", systemImage: "book.fill")
                }

            // 一致性报告
            ConsistencyReportPanel()
                .tabItem {
                    Label("一致性", systemImage: "checkmark.seal.fill")
                }
        }
        .tabViewStyle(.automatic)
    }
}
