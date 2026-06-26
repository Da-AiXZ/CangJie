//
//  AutopilotWorkspaceView.swift
//  Cangjie
//
//  托管撰稿主工作区视图，4 Tab 导航 + operations 子视图切换。
//  对齐原版 AutopilotWorkspace 组件 + autopilotWorkspaceStore.ts。
//

import SwiftUI

/// 托管撰稿主工作区视图
struct AutopilotWorkspaceView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var workspaceStore = AutopilotWorkspaceStore()

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏 Tab 切换
            tabBar

            Divider()

            // Tab 内容
            tabContent
        }
        .navigationTitle("托管撰稿")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // B-3/Q4：进入工作区 → 连接 cockpit SSE（常驻）
            if let novelId = appState.currentNovelId {
                workspaceStore.enterWorkspace(novelId: novelId)
            }
        }
        .onDisappear {
            // B-3/Q4：离开工作区 → 断开全部 SSE
            workspaceStore.leaveWorkspace()
        }
    }

    // MARK: - Tab 栏

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(AutopilotWorkspaceTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Theme.secondaryBackground)
    }

    @ViewBuilder
    private func tabButton(_ tab: AutopilotWorkspaceTab) -> some View {
        let isActive = workspaceStore.activeTab == tab
        Button {
            workspaceStore.setTab(tab)
        } label: {
            VStack(spacing: 2) {
                Text(tab.shortLabel)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Theme.primary : Theme.textSecondary)
                if isActive {
                    Rectangle()
                        .fill(Theme.primary)
                        .frame(width: 24, height: 2)
                        .cornerRadius(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 内容

    @ViewBuilder
    private var tabContent: some View {
        switch workspaceStore.activeTab {
        case .cockpit:
            cockpitTab
        case .governance:
            governanceTab
        case .dashboard:
            dashboardTab
        case .operations:
            operationsTab
        }
    }

    // MARK: - 驾驶舱 Tab

    private var cockpitTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("全托管驾驶")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("启动、暂停与写作进度")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

                // 嵌入自动驾驶控制面板
                AutopilotControlPanel()
            }
            .padding(12)
        }
        .background(Theme.background)
    }

    // MARK: - 总编辑 Tab

    private var governanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("总编辑驾驶舱")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("叙事契约、故事线与治理报告")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

                // 治理面板占位（已有 GovernanceView 在其他位置）
                Text("请从侧边栏「叙事治理」进入完整治理面板")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .padding()
            }
            .padding(12)
        }
        .background(Theme.background)
    }

    // MARK: - 仪表盘 Tab

    private var dashboardTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("仪表盘")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("张力曲线与质量指标")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

                // 统计面板
                StatsTopBarView()
            }
            .padding(12)
        }
        .background(Theme.background)
    }

    // MARK: - 工作流 Tab（监控 + DAG）

    private var operationsTab: some View {
        VStack(spacing: 0) {
            // 子视图切换
            HStack(spacing: 8) {
                subViewButton(.monitor, label: "监控", icon: "chart.line.uptrend.xyaxis")
                subViewButton(.dag, label: "DAG", icon: "flowchart.fill")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // 子视图内容
            switch workspaceStore.operationsSubview {
            case .monitor:
                monitorSubview
            case .dag:
                dagSubview
            }
        }
    }

    @ViewBuilder
    private func subViewButton(_ sub: AutopilotOperationsSubview, label: String, icon: String) -> some View {
        let isActive = workspaceStore.operationsSubview == sub
        Button {
            workspaceStore.setOperationsSubview(sub)
        } label: {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? Theme.primary : Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? Theme.primary.opacity(0.1) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var monitorSubview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("实时监控")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                // 嵌入自动驾驶日志流
                AutopilotLogStream()
            }
            .padding(12)
        }
        .background(Theme.background)
    }

    private var dagSubview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("DAG 工作流画布")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text("请从侧边栏选择对应功能进入 DAG 视图")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .padding()
            }
            .padding(12)
        }
        .background(Theme.background)
    }
}
