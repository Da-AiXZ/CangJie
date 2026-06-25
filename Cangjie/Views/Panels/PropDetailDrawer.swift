//
//  PropDetailDrawer.swift
//  Cangjie
//
//  道具详情抽屉（生命周期+分类+描述+持有者+事件时间线+添加事件+快速修复），对齐 PropDetailDrawer.vue:1-146。
//

import SwiftUI

struct PropDetailDrawer: View {
    let prop: PropDTO
    let slug: String
    let charOptions: [(id: String, name: String)]
    var onUpdated: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = PropStore()
    @State private var showAddEvent = false
    @State private var acting = false

    // 事件表单
    @State private var eventChapter: Int = 1
    @State private var eventType: String = "USED"
    @State private var eventDescription: String = ""

    private var holderName: String {
        guard let holderId = prop.holderCharacterId else { return "" }
        return charOptions.first(where: { $0.id == holderId })?.name ?? String(holderId.prefix(8))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 生命周期+分类标签 — PropDetailDrawer.vue:5-10
                    HStack(spacing: 8) {
                        Text(PropLifecycleLabels.label(prop.lifecycleState))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(PropLifecycleLabels.color(prop.lifecycleState))
                            .cornerRadius(4)
                        Text("\(PropCategoryLabels.icon(prop.propCategory)) \(PropCategoryLabels.label(prop.propCategory))")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.tertiaryBackground)
                            .cornerRadius(4)
                    }

                    // 描述 — PropDetailDrawer.vue:11
                    Text(prop.description.isEmpty ? "暂无描述" : prop.description)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)

                    // 持有者 — PropDetailDrawer.vue:12-15
                    if !holderName.isEmpty {
                        HStack {
                            Text("持有者:").font(.system(size: 12)).foregroundColor(Theme.textTertiary)
                            Text(holderName).font(.system(size: 12, weight: .semibold))
                        }
                    }

                    // 快速修复（仅 DAMAGED 状态）— PropDetailDrawer.vue:17-21
                    if prop.lifecycleState == "DAMAGED" {
                        Button {
                            Task { await quickEvent("REPAIRED") }
                        } label: {
                            Label("🔧 修复", systemImage: "wrench.fill")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(acting)
                    }

                    Divider()

                    // 事件时间线 — PropDetailDrawer.vue:23-41
                    Text("事件时间线").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)

                    if store.currentPropEvents.isEmpty && !store.isLoading {
                        Text("暂无事件记录").font(.system(size: 11)).foregroundColor(Theme.textTertiary)
                    } else {
                        ForEach(store.currentPropEvents) { event in
                            eventRow(event)
                        }
                    }

                    // 添加事件按钮 — PropDetailDrawer.vue:43
                    Button {
                        eventChapter = 1
                        eventType = "USED"
                        eventDescription = ""
                        showAddEvent = true
                    } label: {
                        Label("＋ 手动记录事件", systemImage: "plus.circle")
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(16)
            }
            .navigationTitle(prop.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await store.loadPropEvents(novelId: slug, propId: prop.id)
            }
            .sheet(isPresented: $showAddEvent) {
                addEventModal
            }
        }
    }

    // MARK: - 事件行 — PropDetailDrawer.vue:27-39
    private func eventRow(_ event: PropEventDTO) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间线圆点
            Circle()
                .fill(PropEventLabels.color(event.eventType))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            Rectangle()
                .fill(Theme.textTertiary.opacity(0.2))
                .frame(width: 2)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("第\(event.chapterNumber)章 · \(PropEventLabels.label(event.eventType))")
                    .font(.system(size: 11, weight: .medium))
                if !event.description.isEmpty {
                    Text(event.description).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                }
                // 来源标签 — PropDetailDrawer.vue:35-38
                Text(sourceLabel(event.source))
                    .font(.system(size: 9))
                    .foregroundColor(event.source == "MANUAL" ? Theme.warning : Theme.textTertiary)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background((event.source == "MANUAL" ? Theme.warning : Theme.textTertiary).opacity(0.12))
                    .cornerRadius(3)
            }
            Spacer()
        }
    }

    private func sourceLabel(_ source: String) -> String {
        switch source {
        case "MANUAL": return "手动"
        case "AUTO_LLM": return "AI"
        default: return "标记"
        }
    }

    // MARK: - 添加事件弹窗 — PropDetailDrawer.vue:46-58
    private var addEventModal: some View {
        NavigationStack {
            Form {
                Section("事件信息") {
                    Stepper(value: $eventChapter, in: 1...9999) {
                        Text("第 \(eventChapter) 章")
                    }
                    Picker("事件类型", selection: $eventType) {
                        ForEach(PropEventLabels.allTypes, id: \.self) { type in
                            Text(PropEventLabels.label(type)).tag(type)
                        }
                    }
                    TextField("一句话描述", text: $eventDescription, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...3)
                }
            }
            .navigationTitle("记录事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAddEvent = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await submitEvent() } }
                }
            }
        }
    }

    // MARK: - 提交事件 — PropDetailDrawer.vue:131-142
    private func submitEvent() async {
        let request = CreatePropEventRequest(
            chapterNumber: eventChapter, eventType: eventType,
            description: eventDescription, actorCharacterId: nil,
            fromHolderId: nil, toHolderId: nil
        )
        await store.createPropEvent(novelId: slug, propId: prop.id, request: request)
        showAddEvent = false
        await store.loadPropEvents(novelId: slug, propId: prop.id)
        onUpdated?()
    }

    // MARK: - 快速事件 — PropDetailDrawer.vue:113-129
    private func quickEvent(_ type: String) async {
        acting = true
        let request = CreatePropEventRequest(
            chapterNumber: 1, eventType: type,
            description: "手动标记: \(PropEventLabels.label(type))",
            actorCharacterId: nil, fromHolderId: nil, toHolderId: nil
        )
        await store.createPropEvent(novelId: slug, propId: prop.id, request: request)
        await store.loadPropEvents(novelId: slug, propId: prop.id)
        acting = false
        onUpdated?()
    }
}
