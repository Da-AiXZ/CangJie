//
//  CheckpointTimelineView.swift
//  Cangjie
//
//  检查点时间线：垂直 TimelineView 显示所有快照，点击查看详情，支持回滚确认弹窗。
//  调 SnapshotStore。
//

import SwiftUI

struct CheckpointTimelineView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = SnapshotStore()

    @State private var selectedCheckpoint: CheckpointDTO?
    @State private var showRollbackAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 分段选择：快照/检查点
            Picker("类型", selection: $viewMode) {
                Text("快照").tag(0)
                Text("检查点").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(Theme.Spacing.sm)

            // 时间线
            ScrollView {
                if viewMode == 0 {
                    snapshotsTimeline
                } else {
                    checkpointsTimeline
                }
            }
        }
        .background(Theme.background)
        .navigationTitle("检查点")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .sheet(item: $selectedCheckpoint) { cp in
            checkpointDetailSheet(cp)
        }
        .alert("回滚确认", isPresented: $showRollbackAlert) {
            Button("取消", role: .cancel) {}
            Button("确认回滚", role: .destructive) {
                Task {
                    if let novelId = appState.currentNovelId,
                       let cpId = selectedCheckpoint?.id {
                        await store.rollbackCheckpoint(novelId: novelId, checkpointId: cpId)
                        await loadData()
                    }
                }
            }
        } message: {
            Text("确定回滚到「\(selectedCheckpoint?.triggerReason ?? "")」吗？此操作不可撤销。")
        }
    }

    @State private var viewMode = 1  // 0=快照, 1=检查点

    // MARK: - 快照时间线

    private var snapshotsTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.snapshots.isEmpty {
                emptyState("暂无快照")
            } else {
                ForEach(store.snapshots) { snap in
                    timelineRow(
                        title: snap.name,
                        subtitle: "\(snap.triggerType) · 第\(snap.chapterPointers.first ?? "?")章",
                        date: snap.createdAt,
                        icon: "camera.fill",
                        color: triggerTypeColor(snap.triggerType),
                        isLast: snap.id == store.snapshots.last?.id
                    )
                }
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - 检查点时间线

    private var checkpointsTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.checkpoints.isEmpty {
                emptyState("暂无检查点")
            } else {
                ForEach(store.checkpoints) { cp in
                    Button {
                        selectedCheckpoint = cp
                    } label: {
                        timelineRow(
                            title: cp.triggerReason,
                            subtitle: cp.triggerType + (cp.chapterNumber != nil ? " · 第\(cp.chapterNumber!)章" : ""),
                            date: cp.createdAt,
                            icon: "flag.fill",
                            color: cp.isHead ? Theme.primary : triggerTypeColor(cp.triggerType),
                            isLast: cp.id == store.checkpoints.last?.id
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { selectedCheckpoint = cp } label: {
                            Label("查看详情", systemImage: "info.circle")
                        }
                        Button(role: .destructive) {
                            selectedCheckpoint = cp
                            showRollbackAlert = true
                        } label: {
                            Label("回滚", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - 时间线行

    private func timelineRow(title: String, subtitle: String, date: String, icon: String, color: Color, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // 时间线视觉
            VStack(spacing: 0) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                if !isLast {
                    Rectangle()
                        .fill(Theme.textTertiary.opacity(0.3))
                        .frame(width: 2)
                }
            }
            .frame(width: 12)

            // 内容
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundColor(color)
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)

                if !date.isEmpty {
                    Text(formatDate(date))
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(.bottom, isLast ? 0 : Theme.Spacing.md)

            Spacer()
        }
    }

    // MARK: - 检查点详情 Sheet

    private func checkpointDetailSheet(_ cp: CheckpointDTO) -> some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    LabeledContent("ID", value: String(cp.id.prefix(12)))
                    LabeledContent("类型", value: cp.triggerType)
                    LabeledContent("原因", value: cp.triggerReason)
                    if let ch = cp.chapterNumber { LabeledContent("章节", value: "第\(ch)章") }
                    LabeledContent("创建时间", value: formatDate(cp.createdAt))
                    LabeledContent("HEAD", value: cp.isHead ? "是" : "否")
                }
                if let parentId = cp.parentId { Section("父节点") { Text(parentId) } }

                Section("操作") {
                    Button(role: .destructive) {
                        showRollbackAlert = true
                    } label: {
                        Label("回滚到此检查点", systemImage: "arrow.uturn.backward")
                    }
                }
            }
            .navigationTitle("检查点详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { selectedCheckpoint = nil } } }
        }
    }

    // MARK: - 辅助

    private func loadData() async {
        guard let novelId = appState.currentNovelId else { return }
        await store.loadSnapshots(novelId: novelId)
        await store.loadCheckpoints(novelId: novelId)
    }

    private func emptyState(_ msg: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "clock.badge.questionmark").font(.system(size: 40)).foregroundColor(Theme.textTertiary)
            Text(msg).font(Theme.bodyFont()).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Theme.Spacing.xxl)
    }

    private func triggerTypeColor(_ type: String) -> Color {
        switch type {
        case "CHAPTER": return Theme.primary
        case "ACT": return Theme.warning
        case "MILESTONE": return Theme.success
        case "MANUAL": return Theme.info
        case "AUTO": return Theme.statusBypassed
        default: return Theme.textSecondary
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        if dateStr.count >= 19 { return String(dateStr.prefix(19)).replacingOccurrences(of: "T", with: " ") }
        return dateStr
    }
}
