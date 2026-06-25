//
//  StoryTimelineView.swift
//  Cangjie
//
//  故事时间线（章节事件+快照+创建快照），对齐 StoryTimeline.vue:1-338。
//

import SwiftUI

struct StoryTimelineView: View {
    let slug: String
    let highlightRange: (start: Int, end: Int)?
    var bundledChronicleRows: [ChronicleRow]?
    var onSelectEvent: ((ChronicleStoryEvent) -> Void)? = nil
    var onSelectSnapshot: ((ChronicleSnapshot) -> Void)? = nil
    var onRequestRefresh: (() -> Void)? = nil

    @State private var rows: [ChronicleRow] = []
    @State private var loading = false
    @State private var creating = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                if rows.isEmpty {
                    VStack(spacing: 8) {
                        Text("暂无时间轴数据，章节完成后将自动创建快照")
                            .font(.system(size: 11)).foregroundColor(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 32)
                } else {
                    VStack(spacing: 16) {
                        ForEach(rows) { row in
                            chapterRow(row)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Theme.secondaryBackground)
        .onAppear { loadRows() }
        .onChange(of: bundledChronicleRows) { _ in loadRows() }
        .onChange(of: slug) { _ in loadRows() }
    }

    // MARK: - Header — StoryTimeline.vue:3-11
    private var headerBar: some View {
        HStack {
            Text("时间轴").font(.system(size: 14, weight: .bold))
            Spacer()
            Button {
                Task { await createSnapshot() }
            } label: {
                Label("＋ 快照", systemImage: "plus")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(creating)

            Button {
                if bundledChronicleRows != nil {
                    onRequestRefresh?()
                } else {
                    loadRows()
                }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise").font(.system(size: 11))
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - 章节行 — StoryTimeline.vue:17-65
    private func chapterRow(_ row: ChronicleRow) -> some View {
        let isHighlight = isHighlighted(row.chapterIndex)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(Theme.primary).frame(width: 8, height: 8)
                Text("第 \(row.chapterIndex) 章").font(.system(size: 12, weight: .semibold))
            }

            VStack(spacing: 6) {
                // 剧情事件
                ForEach(row.storyEvents) { event in
                    Button { onSelectEvent?(event) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(event.time)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Theme.success).cornerRadius(3)
                                Text(event.title).font(.system(size: 11, weight: .medium))
                            }
                            if !event.description.isEmpty {
                                Text(event.description).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                            }
                        }
                        .padding(6)
                        .background(Theme.tertiaryBackground)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                // 版本快照
                ForEach(row.snapshots) { snapshot in
                    Button { onSelectSnapshot?(snapshot) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(snapshot.kind == "MANUAL" ? "🟣 手动" : "🔵 自动")
                                    .font(.system(size: 9))
                                    .foregroundColor(snapshot.kind == "MANUAL" ? Theme.warning : Theme.info)
                                Text(snapshot.name).font(.system(size: 11, weight: .medium))
                            }
                            if let createdAt = snapshot.createdAt {
                                Text(formatTime(createdAt))
                                    .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                            }
                        }
                        .padding(6)
                        .background(Theme.tertiaryBackground)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                if row.storyEvents.isEmpty && row.snapshots.isEmpty {
                    Text("—").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                }
            }
            .padding(.leading, 16)
        }
        .padding(12)
        .background(isHighlight ? Theme.primary.opacity(0.04) : Theme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHighlight ? Theme.primary : Theme.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(6)
    }

    // MARK: - 辅助
    private func isHighlighted(_ chapterIndex: Int) -> Bool {
        guard let range = highlightRange else { return false }
        return chapterIndex >= range.start && chapterIndex <= range.end
    }

    private func formatTime(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            let display = DateFormatter()
            display.dateStyle = .short
            display.timeStyle = .short
            return display.string(from: date)
        }
        return timestamp
    }

    private func loadRows() {
        if let bundled = bundledChronicleRows {
            rows = bundled
        } else {
            Task {
                loading = true
                do {
                    let response: ChroniclesResponse = try await APIClient.shared.request(
                        APIEndpoint.Chronicles.get(novelId: slug)
                    )
                    rows = response.rows
                } catch {
                    rows = []
                }
                loading = false
            }
        }
    }

    private func createSnapshot() async {
        creating = true
        do {
            let body: [String: AnyCodable] = [
                "trigger_type": AnyCodable("MANUAL"),
                "name": AnyCodable("手动快照 \(Date().formatted())"),
                "description": AnyCodable("用户手动创建的快照"),
            ]
            try await APIClient.shared.send(
                APIEndpoint.Snapshots.create(novelId: slug),
                body: body
            )
            loadRows()
        } catch {
            // 静默失败
        }
        creating = false
    }
}
