//
//  ChroniclesPanel.swift
//  Cangjie
//
//  全息编年史（双螺旋布局+时间线编辑+回滚+视图切换），对齐 HolographicChroniclesPanel.vue:1-489。
//

import SwiftUI

struct ChroniclesPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var chronicles: ChroniclesResponse?
    @State private var hcView: String = "helix"
    @State private var hoverChapter: Int? = nil
    @State private var rollbackId: String? = nil
    @State private var showRollbackConfirm = false
    @State private var rollbackSnapshot: ChronicleSnapshot? = nil
    @State private var rollbackMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            viewToggle
            contentArea
        }
        .background(Theme.background)
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: WorkbenchStore.chroniclesTickNotification)) { _ in
            Task { await load() }
        }
        .onChange(of: appState.currentNovelId) { _ in
            Task { await load() }
        }
        .alert("回滚结果", isPresented: .constant(rollbackMessage != nil)) {
            Button("确定") { rollbackMessage = nil }
        } message: {
            Text(rollbackMessage ?? "")
        }
    }

    // MARK: - Header — HolographicChroniclesPanel.vue:3-12
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("全息编年史").font(.system(size: 15, weight: .bold))
                Text("中轴为章进度锚点：左里世界剧情时间，右表世界快照（存档）")
                    .font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                // P2-14修复：显示 chronicles.note — HolographicChroniclesPanel.vue:11-12
                if let note = chronicles?.note, !note.isEmpty {
                    Text(note).font(.system(size: 9)).foregroundColor(Theme.info)
                }
            }
            Spacer()
            Button {
                Task { await load() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - 视图切换 — HolographicChroniclesPanel.vue:18-21
    private var viewToggle: some View {
        HStack(spacing: 8) {
            Picker("视图", selection: $hcView) {
                Text("双螺旋概览").tag("helix")
                Text("剧情时间线·列表编辑(Bible)").tag("timeline")
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    // MARK: - Content
    private var contentArea: some View {
        Group {
            if hcView == "timeline" {
                if let novelId = appState.currentNovelId {
                    TimelinePanel(slug: novelId)
                }
            } else {
                helixView
            }
        }
    }

    // MARK: - 双螺旋布局 — HolographicChroniclesPanel.vue:25-93
    private var helixView: some View {
        ScrollView {
            if let chron = chronicles {
                VStack(spacing: 0) {
                    // 表头 — HolographicChroniclesPanel.vue:34-38
                    HStack {
                        Text("进度").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.textTertiary)
                            .frame(width: 50, alignment: .center)
                        Text("里世界·剧情").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("表世界·快照").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 4)

                    ForEach(chron.rows) { row in
                        helixRow(row, maxChapter: chron.maxChapterInBook)
                    }

                    // Footer — HolographicChroniclesPanel.vue:91-93
                    Text("书目已展开至第 \(chron.maxChapterInBook) 章")
                        .font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                        .padding(.vertical, 8)
                }
            } else {
                VStack(spacing: 8) {
                    Text("🧬").font(.system(size: 36))
                    Text("暂无编年史数据").font(.system(size: 12)).foregroundColor(Theme.textTertiary)
                    Text("切换到列表编辑或创建快照").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 32)
            }
        }
    }

    // MARK: - Helix Row — HolographicChroniclesPanel.vue:46-88
    private func helixRow(_ row: ChronicleRow, maxChapter: Int) -> some View {
        let isHover = hoverChapter == row.chapterIndex
        return HStack(alignment: .top, spacing: 0) {
            // 中轴章节锚点 — HolographicChroniclesPanel.vue:46-49
            VStack(spacing: 2) {
                Circle()
                    .fill(isHover ? Theme.primary : Theme.textTertiary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text("第\(row.chapterIndex)章")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(isHover ? Theme.primary : Theme.textTertiary)
            }
            .frame(width: 50)

            // 里世界·剧情事件 — HolographicChroniclesPanel.vue:51-62
            VStack(alignment: .leading, spacing: 4) {
                ForEach(row.storyEvents) { event in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(event.time)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Theme.success).cornerRadius(3)
                            Text(event.title).font(.system(size: 11, weight: .medium))
                        }
                        if !event.description.isEmpty {
                            Text(event.description).font(.system(size: 9)).foregroundColor(Theme.textTertiary).lineLimit(2)
                        }
                    }
                    .padding(6)
                    .background(Theme.success.opacity(0.06))
                    .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 4)

            // 表世界·快照 — HolographicChroniclesPanel.vue:64-88
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(row.snapshots) { snap in
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(snap.name).font(.system(size: 11, weight: .medium))
                            Text(snap.kind == "MANUAL" ? "🟣 手动" : "🔵 自动")
                                .font(.system(size: 9))
                                .foregroundColor(snap.kind == "MANUAL" ? Theme.warning : Theme.info)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background((snap.kind == "MANUAL" ? Theme.warning : Theme.info).opacity(0.12))
                                .cornerRadius(3)
                        }
                        // 回滚按钮 — HolographicChroniclesPanel.vue:77-85
                        Button {
                            rollbackSnapshot = snap
                            showRollbackConfirm = true
                        } label: {
                            Text("回滚")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.error)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(6)
                    .background(Color.purple.opacity(0.06))
                    .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(isHover ? Theme.primary.opacity(0.04) : Color.clear)
        .confirmationDialog(
            "确认回滚到此快照？此操作不可撤销。",
            isPresented: $showRollbackConfirm,
            presenting: rollbackSnapshot
        ) { snap in
            Button("回滚", role: .destructive) {
                Task { await performRollback(snap) }
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 回滚 — HolographicChroniclesPanel.vue:143-165
    private func performRollback(_ snap: ChronicleSnapshot) async {
        guard let novelId = appState.currentNovelId else { return }
        rollbackId = snap.id
        do {
            let response: SnapshotRollbackResponse = try await APIClient.shared.request(
                APIEndpoint.Chronicles.rollback(novelId: novelId, snapshotId: snap.id)
            )
            rollbackMessage = "已回滚，移除 \(response.deletedCount) 个章节"
            await load()
            workbenchStore.bumpDeskTick()
        } catch {
            rollbackMessage = "回滚失败：\(error.localizedDescription)"
        }
        rollbackId = nil
        rollbackSnapshot = nil
    }

    @EnvironmentObject var workbenchStore: WorkbenchStore

    // MARK: - Load — HolographicChroniclesPanel.vue:167-181
    private func load() async {
        guard let novelId = appState.currentNovelId else { return }
        do {
            chronicles = try await APIClient.shared.request(APIEndpoint.Chronicles.get(novelId: novelId))
        } catch {
            chronicles = nil
        }
    }
}
