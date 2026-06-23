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

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // 上半：控制面板
                AutopilotControlPanel(novelId: novelId)
                    .environmentObject(autopilotStore)

                // 熔断器卡片
                CircuitBreakerCard(novelId: novelId)
                    .environmentObject(autopilotStore)

                // DAG 画布
                DAGCanvasView()
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
        .task {
            await autopilotStore.refreshStatus(novelId: novelId)
            await autopilotStore.refreshCircuitBreaker(novelId: novelId)
            autopilotStore.startSSEStreams(novelId: novelId)

            // 加载 DAG
            await dagStore.loadDAG(novelId: novelId)
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
