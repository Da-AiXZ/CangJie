//
//  AutopilotConsoleView.swift
//  Cangjie
//
//  自动驾驶控制台主页（上半：控制面板+熔断器 / 下半：日志流+DAG 画布）。
//  T04 已填充 DAG Canvas。
//  对齐 Vue3 AutopilotPanel.vue + AutopilotTerminalLog.vue + DAGCanvas.vue 的布局。
//

import SwiftUI

/// 自动驾驶控制台
struct AutopilotConsoleView: View {

    let novelId: String

    @StateObject private var autopilotStore = AutopilotStore()
    @StateObject private var dagStore = DAGStore()
    @StateObject private var workbenchStore = WorkbenchStore()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // 上半：控制面板
                AutopilotControlPanel(novelId: novelId)
                    .environmentObject(autopilotStore)
                    .environmentObject(workbenchStore)

                // 熔断器卡片
                CircuitBreakerCard(novelId: novelId)
                    .environmentObject(autopilotStore)

                // StoryPipeline 可观测性 — 对齐 StoryPipelineObservability.vue
                StoryPipelineObservabilityView(status: autopilotStore.status)

                // 章节写作流 — 对齐 ChapterWriterStream.vue
                ChapterWriterStreamView(
                    novelId: novelId,
                    isWriting: autopilotStore.status?.autopilotStatus == "running"
                )
                .environmentObject(autopilotStore)

                // 伏笔雷达 — 对齐 ForeshadowLedger.vue (autopilot只读版)
                ForeshadowRadarView(novelId: novelId)

                // DAG 画布 — T04 传递 novelId（NodeDetailPanel/NodeContextMenu 需要）
                DAGCanvasView(novelId: novelId)
                    .environmentObject(dagStore)
                    .frame(minHeight: 400)

                // 下半：日志流
                AutopilotLogStream(novelId: novelId)
                    .environmentObject(autopilotStore)
                    .frame(minHeight: 300)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("自动驾驶")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await autopilotStore.refreshStatus(novelId: novelId)
            await autopilotStore.refreshCircuitBreaker(novelId: novelId)
            autopilotStore.startSSEStreams(novelId: novelId)

            // P0-4 集成遗留：DAGRunStore ← → DAGStore 注入
            dagStore.setDAGRunStore(workbenchStore.dagRunStore)
            workbenchStore.dagRunStore.setDAGStore(dagStore)

            // 加载 DAG — T04 改用 hydrateDagForNovel（并行加载 DAG + 注册表 + linkage）
            await dagStore.hydrateDagForNovel(novelId: novelId)
            await dagStore.loadDAGStatus(novelId: novelId)
            dagStore.startDAGEvents(novelId: novelId)
        }
        .onDisappear {
            autopilotStore.stopSSEStreams(novelId: novelId)
            dagStore.stopDAGEvents(novelId: novelId)
        }
        .alert("错误", isPresented: .constant(autopilotStore.errorMessage != nil)) {
            Button("确定") { autopilotStore.errorMessage = nil }
        } message: {
            Text(autopilotStore.errorMessage ?? "")
        }
    }
}
