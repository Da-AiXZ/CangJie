//
//  AutopilotControlPanel.swift
//  Cangjie
//
//  控制面板：目标章数/每章字数/最大自动章数 + 启动/停止/恢复 + 当前状态卡片。
//  对齐 Vue3 AutopilotPanel.vue 的状态卡片 + 操作按钮 + 启动配置弹窗。
//
//  【修复】启动失败 409（宏观结构未生成）时弹出引导提示，
//  指引用户去工作台点击「宏观规划」按钮生成并确认故事骨架。
//

import SwiftUI

/// 自动驾驶控制面板
struct AutopilotControlPanel: View {

    let novelId: String

    @EnvironmentObject var autopilotStore: AutopilotStore

    // 启动配置
    @State private var targetChapters: Int = 100
    @State private var targetWordsPerChapter: Int = 2500
    @State private var maxAutoChapters: Int = 9999
    @State private var autoApproveMode: Bool = false
    @State private var showStartSheet: Bool = false
    @State private var showMacroGuidance: Bool = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 状态卡片
            statusCard

            // KPI 网格
            if let status = autopilotStore.status {
                kpiGrid(status)
            }

            // 操作按钮
            actionButtons
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
        .alert("无法启动自动驾驶", isPresented: $showMacroGuidance) {
            Button("知道了", role: .cancel) {
                autopilotStore.errorMessage = nil
            }
        } message: {
            Text("请先在工作台点击「宏观规划」按钮，生成并确认故事骨架（部/卷/幕）后再启动自动驾驶。")
        }
    }

    // MARK: - 状态卡片

    private var statusCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            // 运行状态点
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("守护进程")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

                Text(statusLabel)
                    .font(Theme.headlineFont())
            }

            Spacer()

            // 进度
            if let status = autopilotStore.status {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", status.progressPct))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(autopilotStore.isRunning ? Theme.primary : Theme.textSecondary)
                    Text("全书进度")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
    }

    // MARK: - KPI 网格

    private func kpiGrid(_ status: AutopilotStatus) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: Theme.Spacing.sm) {
            kpiItem(label: "完稿/书稿/目标", value: "\(status.completedChapters)/\(status.manuscriptChapters)/\(status.targetChapters)")
            kpiItem(label: "总字数", value: formatWords(status.totalWords))
            kpiItem(label: "上章张力", value: "\(status.lastChapterTension)")
        }
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 审阅恢复
            if autopilotStore.needsReview {
                Button {
                    Task { await autopilotStore.resumeAutopilot(novelId: novelId) }
                } label: {
                    Label("确认·继续", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.warning)
                .controlSize(.large)
                .disabled(autopilotStore.isControlling)
            }

            // 启动
            if !autopilotStore.isRunning && !autopilotStore.needsReview {
                Button {
                    showStartSheet = true
                } label: {
                    Label("启动全托管", systemImage: "rocket.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(autopilotStore.isControlling)
            }

            // 停止
            if autopilotStore.isRunning {
                Button(role: .destructive) {
                    Task { await autopilotStore.stopAutopilot(novelId: novelId) }
                } label: {
                    Label("停止", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(autopilotStore.isControlling)
            }
        }
        .sheet(isPresented: $showStartSheet) {
            startConfigSheet
        }
    }

    // MARK: - 启动配置 Sheet

    private var startConfigSheet: some View {
        NavigationStack {
            Form {
                Section("启动参数") {
                    Stepper("目标章数：\(targetChapters)", value: $targetChapters, in: 1...9999, step: 10)
                    Stepper("每章字数：\(targetWordsPerChapter)", value: $targetWordsPerChapter, in: 500...20000, step: 500)
                    Stepper("保护上限：\(maxAutoChapters) 章", value: $maxAutoChapters, in: targetChapters...9999, step: 10)
                }

                Section("全自动模式") {
                    Toggle("跳过所有人工审阅", isOn: $autoApproveMode)

                    if autoApproveMode {
                        Text("系统将跳过所有审阅环节，自动运行直到写完")
                            .font(Theme.captionFont())
                            .foregroundColor(Theme.warning)
                    }
                }
            }
            .navigationTitle("启动全托管")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { showStartSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("启动") {
                        Task {
                            await autopilotStore.startAutopilot(
                                novelId: novelId,
                                targetChapters: targetChapters,
                                targetWordsPerChapter: targetWordsPerChapter
                            )
                            showStartSheet = false
                            // 检查是否因宏观结构未生成而启动失败（HTTP 409）
                            // 【修复 F2】先清 errorMessage 再设 showMacroGuidance，
                            // 避免 AutopilotConsoleView 的通用 alert 抢同一个 errorMessage 状态
                            if let msg = autopilotStore.errorMessage,
                               msg.contains("宏观结构") || msg.contains("409") {
                                autopilotStore.errorMessage = nil
                                showMacroGuidance = true
                            }
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - 辅助

    private var statusColor: Color {
        guard let status = autopilotStore.status else { return Theme.textTertiary }
        switch status.autopilotStatus {
        case "running": return Theme.statusRunning
        case "paused", "paused_for_review": return Theme.statusWarning
        case "error": return Theme.statusError
        case "stopped": return Theme.statusIdle
        default: return Theme.textSecondary
        }
    }

    private var statusLabel: String {
        guard let status = autopilotStore.status else { return "未连接" }
        switch status.autopilotStatus {
        case "running": return "运行中"
        case "paused", "paused_for_review": return "等待审阅"
        case "error": return "异常挂起"
        case "stopped": return "已停止"
        default: return status.autopilotStatus
        }
    }

    private func kpiItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.small)
    }

    private func formatWords(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f万", Double(count) / 10000)
        }
        return "\(count)"
    }
}
