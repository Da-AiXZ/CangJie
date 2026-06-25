//
//  StoryDetailPanelView.swift
//  Cangjie
//
//  故事详情面板（事件详情+快照详情+回滚），对齐 StoryDetailPanel.vue:1-264。
//

import SwiftUI

struct StoryDetailPanelView: View {
    let slug: String
    let selectedItem: StorySelectedItem?
    var onRefresh: (() -> Void)? = nil

    @State private var loadingSnapshot = false
    @State private var rollingBack = false
    @State private var showRollbackConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if let item = selectedItem {
                contentView(item)
            } else {
                emptyState
            }
        }
        .background(Theme.secondaryBackground)
    }

    // MARK: - Header — StoryDetailPanel.vue:3-5
    private var headerBar: some View {
        Text("详情面板")
            .font(.system(size: 14, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("选择时间轴中的事件或快照查看详情")
                .font(.system(size: 11)).foregroundColor(Theme.textTertiary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - 内容 — StoryDetailPanel.vue:13-144
    @ViewBuilder
    private func contentView(_ item: StorySelectedItem) -> some View {
        ScrollView {
            if item.type == "event" {
                eventDetail(item.data)
            } else if item.type == "snapshot" {
                snapshotDetail(item.data)
            }
        }
        .padding(16)
    }

    // MARK: - 事件详情 — StoryDetailPanel.vue:13-38
    private func eventDetail(_ data: AnyCodable) -> some View {
        let dict = data.value as? [String: Any] ?? [:]
        let time = dict["time"] as? String ?? ""
        let title = dict["title"] as? String ?? ""
        let description = dict["description"] as? String ?? ""
        let sourceChapter = dict["source_chapter"] as? Int
        let noteId = dict["note_id"] as? String ?? ""

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(time)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Theme.success).cornerRadius(3)
                Text(title).font(.system(size: 13, weight: .semibold))
            }

            if !description.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("描述").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                    Text(description).font(.system(size: 12))
                }
            }

            if let ch = sourceChapter {
                VStack(alignment: .leading, spacing: 2) {
                    Text("来源章节").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                    Text("第 \(ch) 章").font(.system(size: 12))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Note ID").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                Text(noteId).font(.system(size: 10, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 快照详情 — StoryDetailPanel.vue:42-144
    private func snapshotDetail(_ data: AnyCodable) -> some View {
        let dict = data.value as? [String: Any] ?? [:]
        let kind = dict["kind"] as? String ?? "AUTO"
        let name = dict["name"] as? String ?? ""
        let description = dict["description"] as? String ?? ""
        let createdAt = dict["created_at"] as? String
        let anchorChapter = dict["anchor_chapter"] as? Int
        let snapshotId = dict["id"] as? String ?? ""

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(kind == "MANUAL" ? "🟣 手动" : "🔵 自动")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(kind == "MANUAL" ? Theme.warning : Theme.info)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background((kind == "MANUAL" ? Theme.warning : Theme.info).opacity(0.12))
                    .cornerRadius(3)
                Text(name).font(.system(size: 13, weight: .semibold))
            }

            if !description.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("描述").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                    Text(description).font(.system(size: 12))
                }
            }

            if let createdAt = createdAt {
                VStack(alignment: .leading, spacing: 2) {
                    Text("创建时间").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                    Text(formatTime(createdAt)).font(.system(size: 12))
                }
            }

            if let ch = anchorChapter {
                VStack(alignment: .leading, spacing: 2) {
                    Text("锚定章节").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                    Text("第 \(ch) 章").font(.system(size: 12))
                }
            }

            Divider()

            // 回滚按钮 — StoryDetailPanel.vue:131-140
            Button(role: .destructive) {
                showRollbackConfirm = true
            } label: {
                Label("回滚到此快照", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(rollingBack)
            .confirmationDialog("确认回滚到此快照？此操作不可撤销。", isPresented: $showRollbackConfirm) {
                Button("回滚", role: .destructive) {
                    Task { await performRollback(snapshotId: snapshotId) }
                }
                Button("取消", role: .cancel) {}
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 辅助
    private func formatTime(_ timestamp: String?) -> String {
        guard let ts = timestamp, !ts.isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: ts) {
            let display = DateFormatter()
            display.dateStyle = .short
            display.timeStyle = .short
            return display.string(from: date)
        }
        return ts
    }

    private func performRollback(snapshotId: String) async {
        rollingBack = true
        do {
            let response: SnapshotRollbackResponse = try await APIClient.shared.request(
                APIEndpoint.Chronicles.rollback(novelId: slug, snapshotId: snapshotId)
            )
            _ = response
            onRefresh?()
        } catch {
            // 静默失败
        }
        rollingBack = false
    }
}
