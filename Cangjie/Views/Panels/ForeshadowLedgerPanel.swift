//
//  ForeshadowLedgerPanel.swift
//  Cangjie
//
//  伏笔手账本（CRUD+优先级星标+消费弹窗+筛选+Tab），对齐 ForeshadowLedgerPanel.vue:1-519。
//

import SwiftUI

/// 伏笔重要程度 — domain/foreshadow.ts:1-44
enum ForeshadowImportance: String, CaseIterable, Codable {
    case low, medium, high, critical

    var label: String {
        switch self {
        case .critical: return "危急"
        case .high: return "重要"
        case .medium: return "一般"
        case .low: return "次要"
        }
    }

    var order: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    var accentColor: Color {
        switch self {
        case .critical: return Theme.error
        case .high: return Theme.warning
        case .medium: return Theme.primary
        case .low: return Theme.textTertiary
        }
    }

    var chipColor: Color {
        switch self {
        case .critical: return Theme.error
        case .high: return Theme.warning
        case .medium: return Theme.info
        case .low: return Theme.textTertiary
        }
    }

    static func from(_ raw: String) -> ForeshadowImportance {
        ForeshadowImportance(rawValue: raw) ?? .medium
    }
}

struct ForeshadowLedgerPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var novelStore: NovelStore
    @EnvironmentObject var workbenchStore: WorkbenchStore
    @StateObject private var store = ForeshadowStore()

    // 状态 — ForeshadowLedgerPanel.vue:246-254
    @State private var activeTab: String = "pending"
    @State private var activeFilter: String = "all"
    @State private var filterCharacter: String? = nil
    @State private var dataLoaded = false
    @State private var consumingEntryId: String? = nil
    @State private var priorityLoadingId: String? = nil

    // 弹窗状态 — ForeshadowLedgerPanel.vue:311-312
    @State private var showEditModal = false
    @State private var editingEntry: ForeshadowEntry? = nil
    @State private var showConsumeModal = false
    @State private var consumingEntry: ForeshadowEntry? = nil
    @State private var consumeChapter: Int = 1
    @State private var saving = false

    // P2-9：删除确认 — ForeshadowLedgerPanel.vue:129-134 n-popconfirm
    @State private var showDeleteConfirm = false
    @State private var entryToDelete: ForeshadowEntry?

    // P2-10：帮助tooltip — ForeshadowLedgerPanel.vue:11-18
    @State private var showHelpPopover = false

    // 表单 — ForeshadowLedgerPanel.vue:313-319
    @State private var formQuestion = ""
    @State private var formCharacterId = ""
    @State private var formChapter: Int = 1
    @State private var formImportance: ForeshadowImportance = .medium
    @State private var formSuggestedResolveChapter: Int? = nil

    private var currentChapterNumber: Int? {
        novelStore.currentChapter?.number
    }

    private var pendingEntries: [ForeshadowEntry] {
        store.entries.filter { $0.status == "pending" }
    }

    private var consumedEntries: [ForeshadowEntry] {
        store.entries.filter { $0.status == "consumed" }
    }

    private var pendingCount: Int {
        pendingEntries.count
    }

    // 角色选项 — ForeshadowLedgerPanel.vue:263-266
    private var characterOptions: [String] {
        Array(Set(pendingEntries.map { $0.characterId }.filter { !$0.isEmpty })).sorted()
    }

    // 筛选+排序 — ForeshadowLedgerPanel.vue:268-282
    private var filteredPending: [ForeshadowEntry] {
        var list = pendingEntries
        if activeFilter == "due", let ch = currentChapterNumber {
            list = list.filter { entry in
                guard let suggested = entry.suggestedResolveChapter else { return false }
                return suggested <= ch + 2
            }
        }
        if activeFilter == "char", let fc = filterCharacter {
            list = list.filter { $0.characterId == fc }
        }
        return list.sorted { a, b in
            if a.isPriorityForChapter != b.isPriorityForChapter {
                return a.isPriorityForChapter
            }
            return ForeshadowImportance.from(a.importance).order > ForeshadowImportance.from(b.importance).order
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            filterStrip
            tabBar
            contentArea
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadEntries(novelId: novelId)
                dataLoaded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WorkbenchStore.foreshadowTickNotification)) { _ in
            if let novelId = appState.currentNovelId {
                Task { await store.loadEntries(novelId: novelId) }
            }
        }
        .onChange(of: appState.currentNovelId) { newId in
            if let novelId = newId {
                Task { await store.loadEntries(novelId: novelId) }
            }
        }
        .sheet(isPresented: $showEditModal) {
            editModal
        }
        .sheet(isPresented: $showConsumeModal) {
            consumeModal
        }
        // P2-9：删除确认弹窗 — ForeshadowLedgerPanel.vue:129-134 n-popconfirm
        .confirmationDialog(
            "确认删除这条伏笔？",
            isPresented: $showDeleteConfirm,
            presenting: entryToDelete
        ) { entry in
            Button("删除", role: .destructive) {
                Task {
                    if let novelId = appState.currentNovelId {
                        await store.deleteEntry(novelId: novelId, entryId: entry.id)
                    }
                }
                entryToDelete = nil
            }
            Button("取消", role: .cancel) { entryToDelete = nil }
        }
    }

    // MARK: - Header — ForeshadowLedgerPanel.vue:5-32
    private var headerBar: some View {
        HStack(spacing: 8) {
            Text("伏笔账本").font(.system(size: 14, weight: .bold))
            if pendingCount > 0 {
                Text("\(pendingCount) 待兑现")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.warning)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.warning.opacity(0.12))
                    .cornerRadius(4)
            }
            if !consumedEntries.isEmpty {
                Text("\(consumedEntries.count) 已消费")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.textTertiary.opacity(0.12))
                    .cornerRadius(4)
            }
            // P2-10：帮助tooltip — ForeshadowLedgerPanel.vue:11-18
            Button {
                showHelpPopover.toggle()
            } label: {
                Text("?")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 15, height: 15)
                    .background(Theme.tertiaryBackground)
                    .foregroundColor(Theme.textTertiary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showHelpPopover) {
                Text("伏笔 ≈ 主角（或读者）当下的疑问；在本阶段兑现并与爽点挂钩即可，不必写论文。")
                    .font(.system(size: 12))
                    .frame(width: 200)
                    .padding(8)
                // CI#29 修复：移除 .presentationCompactAdaptation(.popover)（iOS 16.4+ API，项目目标 16.0）
            }
            Spacer()
            Button(action: openCreateModal) {
                Label("+ 添加", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button {
                if let novelId = appState.currentNovelId {
                    Task { await store.loadEntries(novelId: novelId) }
                }
            } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: - Filter strip — ForeshadowLedgerPanel.vue:35-57
    private var filterStrip: some View {
        HStack(spacing: 6) {
            filterButton("全部", filter: "all")
            if currentChapterNumber != nil {
                filterButton("本章到期 ↑", filter: "due")
            }
            if !characterOptions.isEmpty {
                Picker("按角色", selection: $filterCharacter) {
                    Text("按角色").tag(String?.none)
                    ForEach(characterOptions, id: \.self) { id in
                        Text(id).tag(String?.some(id))
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 100)
                .onChange(of: filterCharacter) { val in
                    if val != nil { activeFilter = "char" }
                    else if activeFilter == "char" { activeFilter = "all" }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private func filterButton(_ label: String, filter: String) -> some View {
        Button {
            activeFilter = filter
            if filter != "char" { filterCharacter = nil }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: activeFilter == filter ? .semibold : .regular))
                .foregroundColor(activeFilter == filter ? Theme.primary : Theme.textSecondary)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Tab — ForeshadowLedgerPanel.vue:60-68
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("待兑现", tab: "pending", badge: pendingCount)
            tabButton("已消费", tab: "consumed", badge: 0)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.bottom, 4)
    }

    private func tabButton(_ label: String, tab: String, badge: Int) -> some View {
        Button { activeTab = tab } label: {
            HStack(spacing: 4) {
                Text(label).font(.system(size: 12, weight: activeTab == tab ? .semibold : .regular))
                if badge > 0 && tab == "pending" {
                    Text("\(min(badge, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Theme.warning)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(activeTab == tab ? Theme.primary : Theme.textSecondary)
            .padding(.vertical, 4)
            .overlay(
                Rectangle()
                    .fill(activeTab == tab ? Theme.primary : Color.clear)
                    .frame(height: 2)
                    .offset(y: 14), alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content — ForeshadowLedgerPanel.vue:70-166
    private var contentArea: some View {
        ScrollView {
            VStack(spacing: 6) {
                if !dataLoaded && store.isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.tertiaryBackground)
                            .frame(height: 50)
                            .redacted(reason: .placeholder)
                    }
                } else if activeTab == "pending" {
                    if filteredPending.isEmpty {
                        emptyState(icon: "🪄", text: activeFilter == "due" ? "本章无到期伏笔" : "暂无待兑现伏笔", showAddButton: activeFilter == "all")
                    } else {
                        ForEach(filteredPending) { entry in
                            pendingCard(entry)
                        }
                    }
                } else {
                    if consumedEntries.isEmpty {
                        emptyState(icon: "✅", text: "暂无已消费伏笔", showAddButton: false)
                    } else {
                        ForEach(consumedEntries) { entry in
                            consumedCard(entry)
                        }
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private func emptyState(icon: String, text: String, showAddButton: Bool) -> some View {
        VStack(spacing: 8) {
            Text(icon).font(.system(size: 32))
            Text(text).font(.system(size: 12)).foregroundColor(Theme.textTertiary)
            if showAddButton {
                Button(action: openCreateModal) {
                    Text("+ 添加伏笔").font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - 待兑现卡片 — ForeshadowLedgerPanel.vue:89-138
    private func pendingCard(_ entry: ForeshadowEntry) -> some View {
        let importance = ForeshadowImportance.from(entry.importance)
        return VStack(alignment: .leading, spacing: 4) {
            // Row 1: importance + question + star
            HStack(spacing: 5) {
                Text(importance.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(importance.chipColor)
                    .cornerRadius(3)
                Text(entry.question)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button {
                    Task {
                        priorityLoadingId = entry.id
                        await store.togglePriority(novelId: appState.currentNovelId ?? "", entryId: entry.id, currentValue: entry.isPriorityForChapter)
                        priorityLoadingId = nil
                    }
                } label: {
                    Text(entry.isPriorityForChapter ? "★" : "☆")
                        .font(.system(size: 14))
                        .foregroundColor(entry.isPriorityForChapter ? Theme.warning : Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(priorityLoadingId == entry.id)
            }
            // Row 2: meta + actions
            HStack(spacing: 5) {
                Text("第\(entry.chapter)章")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Theme.tertiaryBackground)
                    .cornerRadius(3)
                if !entry.characterId.isEmpty {
                    Text(entry.characterId)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.primary)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(3)
                }
                if let suggested = entry.suggestedResolveChapter {
                    Text("→ 第\(suggested)章兑现")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
                Button {
                    consumingEntry = entry
                    consumeChapter = (currentChapterNumber ?? entry.chapter) + 1
                    showConsumeModal = true
                } label: {
                    Text("✓").font(.system(size: 12)).foregroundColor(Theme.success)
                }
                .buttonStyle(.plain)
                .disabled(consumingEntryId == entry.id)

                Button("编辑") {
                    openEditModal(entry)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button("删") {
                    entryToDelete = entry
                    showDeleteConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .foregroundColor(Theme.error)
            }
        }
        .padding(8)
        .background(entry.isPriorityForChapter ? Theme.warning.opacity(0.06) : Theme.secondaryBackground)
        .overlay(
            Rectangle()
                .fill(importance.accentColor)
                .frame(width: 3), alignment: .leading
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    // MARK: - 已消费卡片 — ForeshadowLedgerPanel.vue:147-163
    private func consumedCard(_ entry: ForeshadowEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text("✓ 已消费")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Theme.success)
                    .cornerRadius(3)
                Text(entry.question)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(Theme.textSecondary)
            }
            HStack(spacing: 5) {
                Text("第\(entry.chapter)章埋")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                Text("→")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                if let consumed = entry.consumedAtChapter {
                    Text("第\(consumed)章兑现")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.success)
                }
            }
        }
        .padding(8)
        .background(Theme.secondaryBackground.opacity(0.82))
        .cornerRadius(8)
    }

    // MARK: - 创建/编辑弹窗 — ForeshadowLedgerPanel.vue:168-202
    private var editModal: some View {
        NavigationStack {
            Form {
                Section("伏笔信息") {
                    VStack(alignment: .leading) {
                        Text("当下的疑问").font(.caption).foregroundColor(Theme.textTertiary)
                        TextField("例：他为何总在雨夜出门？", text: $formQuestion, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)
                    }
                    HStack {
                        Text("关联角色").font(.caption)
                        TextField("角色名或 ID", text: $formCharacterId)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("埋入章节").font(.caption)
                        Stepper(value: $formChapter, in: 1...9999) {
                            Text("第 \(formChapter) 章")
                        }
                    }
                    Picker("重要程度", selection: $formImportance) {
                        ForEach(ForeshadowImportance.allCases, id: \.self) { imp in
                            Text(imp.label).tag(imp)
                        }
                    }
                    HStack {
                        Text("预计兑现章").font(.caption)
                        Spacer()
                        Stepper(value: Binding(
                            get: { formSuggestedResolveChapter ?? 0 },
                            set: { formSuggestedResolveChapter = $0 > 0 ? $0 : nil }
                        ), in: 0...9999) {
                            Text(formSuggestedResolveChapter.map { "第 \($0) 章" } ?? "可选")
                        }
                    }
                }
            }
            .navigationTitle(editingEntry != nil ? "编辑伏笔" : "添加伏笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showEditModal = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingEntry != nil ? "保存" : "添加") { Task { await handleSubmit() } }
                        .disabled(saving || formQuestion.trimmingCharacters(in: .whitespaces).isEmpty || formCharacterId.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func openCreateModal() {
        editingEntry = nil
        formQuestion = ""
        formCharacterId = ""
        formChapter = currentChapterNumber ?? 1
        formImportance = .medium
        formSuggestedResolveChapter = nil
        showEditModal = true
    }

    private func openEditModal(_ entry: ForeshadowEntry) {
        editingEntry = entry
        formQuestion = entry.question
        formCharacterId = entry.characterId
        formChapter = entry.chapter
        formImportance = ForeshadowImportance.from(entry.importance)
        formSuggestedResolveChapter = entry.suggestedResolveChapter
        showEditModal = true
    }

    private func handleSubmit() async {
        guard let novelId = appState.currentNovelId else { return }
        saving = true
        if let entry = editingEntry {
            let request = UpdateForeshadowRequest(
                chapter: formChapter, characterId: formCharacterId,
                question: formQuestion, status: nil, consumedAtChapter: nil,
                suggestedResolveChapter: formSuggestedResolveChapter,
                resolveChapterWindow: nil, importance: formImportance.rawValue,
                isPriorityForChapter: nil
            )
            await store.updateEntry(novelId: novelId, entryId: entry.id, request: request)
        } else {
            let request = CreateForeshadowRequest(
                entryId: "fsw-\(Int(Date().timeIntervalSince1970 * 1000))",
                chapter: formChapter, characterId: formCharacterId,
                question: formQuestion,
                suggestedResolveChapter: formSuggestedResolveChapter,
                resolveChapterWindow: nil, importance: formImportance.rawValue
            )
            await store.createEntry(novelId: novelId, request: request)
        }
        saving = false
        showEditModal = false
        await store.loadEntries(novelId: novelId)
    }

    // MARK: - 消费弹窗 — ForeshadowLedgerPanel.vue:205-217
    private var consumeModal: some View {
        NavigationStack {
            Form {
                Section("兑现章节") {
                    Stepper(value: $consumeChapter, in: 1...9999) {
                        Text("第 \(consumeChapter) 章")
                    }
                }
            }
            .navigationTitle("标记已消费")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showConsumeModal = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") { Task { await confirmConsumed() } }
                        .disabled(saving)
                }
            }
        }
    }

    private func confirmConsumed() async {
        guard let entry = consumingEntry, let novelId = appState.currentNovelId else { return }
        saving = true
        consumingEntryId = entry.id
        await store.markConsumed(novelId: novelId, entryId: entry.id, consumedAtChapter: consumeChapter)
        consumingEntryId = nil
        saving = false
        showConsumeModal = false
        await store.loadEntries(novelId: novelId)
    }
}
