//
//  TimelinePanel.swift
//  Cangjie
//
//  剧情时间线·列表编辑(Bible)，对齐 TimelinePanel.vue:1-280。
//  从 Bible 拉取 timeline_notes，支持添加/编辑/删除事件。
//

import SwiftUI

struct TimelinePanel: View {
    let slug: String

    @State private var timelineEvents: [TimelineNoteDTO] = []
    @State private var loading = false
    @State private var showAddModal = false
    @State private var editingIndex: Int? = nil

    // 表单 — TimelinePanel.vue:111-115
    @State private var formTimePoint = ""
    @State private var formEvent = ""
    @State private var formDescription = ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            contentArea
        }
        .background(Theme.background)
        .task { await loadTimeline() }
        .onReceive(NotificationCenter.default.publisher(for: WorkbenchStore.chroniclesTickNotification)) { _ in
            Task { await loadTimeline() }
        }
        .onChange(of: slug) { _ in
            Task { await loadTimeline() }
        }
        .sheet(isPresented: $showAddModal) {
            addEditModal
        }
    }

    // MARK: - Header — TimelinePanel.vue:3-21
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("剧情时间轴").font(.system(size: 14, weight: .bold))
                    Text("叙事事件")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Theme.tertiaryBackground).cornerRadius(10)
                }
                Text("垂直时间步进：世界内历法/相对时间与事件摘要")
                    .font(.system(size: 10)).foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Button("+ 添加事件") { openAdd() }
                .buttonStyle(.bordered).controlSize(.small)
            Button {
                Task { await loadTimeline() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise").font(.system(size: 11))
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var contentArea: some View {
        ScrollView {
            if loading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if timelineEvents.isEmpty {
                VStack(spacing: 8) {
                    Text("⏱️").font(.system(size: 40))
                    Text("暂无时间线事件，点击「添加事件」开始规划")
                        .font(.system(size: 12)).foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 32)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(timelineEvents.enumerated()), id: \.element.id) { index, event in
                        eventRow(event, index: index)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - 事件行 — TimelinePanel.vue:33-48
    private func eventRow(_ event: TimelineNoteDTO, index: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间线圆点
            Circle().fill(Theme.info).frame(width: 8, height: 8).padding(.top, 4)
            Rectangle().fill(Theme.textTertiary.opacity(0.2)).frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.event).font(.system(size: 12, weight: .semibold))
                Text(event.timePoint.isEmpty ? "未指定时间" : event.timePoint)
                    .font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                if !event.description.isEmpty {
                    Text(event.description).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                }
                HStack(spacing: 6) {
                    Button("编辑") { openEdit(index) }
                        .buttonStyle(.bordered).controlSize(.mini)
                    Button("删除") {
                        timelineEvents.remove(at: index)
                        Task { await saveTimeline() }
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                    .foregroundColor(Theme.error)
                }
            }
            Spacer()
        }
    }

    // MARK: - 添加/编辑弹窗 — TimelinePanel.vue:54-86
    private var addEditModal: some View {
        NavigationStack {
            Form {
                Section("事件信息") {
                    TextField("时间点（例：第三年冬、2024-01-01、三天后）", text: $formTimePoint)
                    TextField("事件名称或简述", text: $formEvent)
                    VStack(alignment: .leading) {
                        Text("详细描述").font(.caption).foregroundColor(Theme.textTertiary)
                        TextField("事件的详细描述（可选）", text: $formDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder).lineLimit(3...6)
                    }
                }
            }
            .navigationTitle(editingIndex != nil ? "编辑事件" : "添加事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAddModal = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") { Task { await handleSubmit() } }
                        .disabled(formEvent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func openAdd() {
        editingIndex = nil
        formTimePoint = ""
        formEvent = ""
        formDescription = ""
        showAddModal = true
    }

    private func openEdit(_ index: Int) {
        editingIndex = index
        let event = timelineEvents[index]
        formTimePoint = event.timePoint
        formEvent = event.event
        formDescription = event.description
        showAddModal = true
    }

    // MARK: - 提交 — TimelinePanel.vue:139-163
    private func handleSubmit() async {
        guard !formEvent.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let newEvent = TimelineNoteDTO(
            id: editingIndex != nil ? timelineEvents[editingIndex!].id : "timeline-\(Int(Date().timeIntervalSince1970 * 1000))",
            event: formEvent,
            timePoint: formTimePoint,
            description: formDescription
        )
        if let idx = editingIndex {
            timelineEvents[idx] = newEvent
        } else {
            timelineEvents.append(newEvent)
        }
        showAddModal = false
        editingIndex = nil
        await saveTimeline()
    }

    // MARK: - 加载 — TimelinePanel.vue:125-137
    private func loadTimeline() async {
        loading = true
        do {
            // L-2修复：复用现有 BibleDTO 模型
            let bible: BibleDTO = try await APIClient.shared.request(
                APIEndpoint.Bible.get(novelId: slug)
            )
            timelineEvents = bible.timelineNotes
        } catch {
            timelineEvents = []
        }
        loading = false
    }

    // MARK: - 保存 — TimelinePanel.vue:181-192
    private func saveTimeline() async {
        do {
            // L-2修复：复用现有 BibleDTO 模型
            let bible: BibleDTO = try await APIClient.shared.request(
                APIEndpoint.Bible.get(novelId: slug)
            )
            // 构建更新请求体：重用 Bible 数据，仅替换 timeline_notes
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let charactersData = try encoder.encode(bible.characters)
            let worldSettingsData = try encoder.encode(bible.worldSettings)
            let locationsData = try encoder.encode(bible.locations)
            let timelineData = try encoder.encode(timelineEvents)
            let styleNotesData = try encoder.encode(bible.styleNotes)

            let charactersObj = try JSONSerialization.jsonObject(with: charactersData)
            let worldObj = try JSONSerialization.jsonObject(with: worldSettingsData)
            let locationsObj = try JSONSerialization.jsonObject(with: locationsData)
            let timelineObj = try JSONSerialization.jsonObject(with: timelineData)
            let styleObj = try JSONSerialization.jsonObject(with: styleNotesData)

            let updateBody: [String: AnyCodable] = [
                "characters": AnyCodable(charactersObj),
                "world_settings": AnyCodable(worldObj),
                "locations": AnyCodable(locationsObj),
                "timeline_notes": AnyCodable(timelineObj),
                "style_notes": AnyCodable(styleObj),
            ]
            try await APIClient.shared.send(
                APIEndpoint.Bible.update(novelId: slug),
                body: updateBody
            )
        } catch {
            // 静默失败
        }
    }
}
