//
//  PropManagerPanel.swift
//  Cangjie
//
//  道具管理（CRUD+事件创建+关键道具切换+实体索引+详情抽屉），对齐 ManuscriptPropsPanel.vue:1-567。
//

import SwiftUI

/// 道具分类标签 — propApi.ts:48-55
enum PropCategoryLabels {
    static let labels: [String: String] = [
        "WEAPON": "武器", "ARTIFACT": "法器", "TOOL": "工具",
        "CONSUMABLE": "消耗品", "TOKEN": "信物", "OTHER": "其他",
    ]
    static let icons: [String: String] = [
        "WEAPON": "🗡", "ARTIFACT": "🔮", "TOOL": "🔧",
        "CONSUMABLE": "💊", "TOKEN": "📜", "OTHER": "📦",
    ]
    static func label(_ category: String) -> String { labels[category] ?? category }
    static func icon(_ category: String) -> String { icons[category] ?? "📦" }
}

/// 道具生命周期标签 — propApi.ts:32-46
enum PropLifecycleLabels {
    static let labels: [String: String] = [
        "DORMANT": "未登场", "INTRODUCED": "已登场", "ACTIVE": "使用中",
        "DAMAGED": "损毁", "RESOLVED": "已结局",
    ]
    static func label(_ state: String) -> String { labels[state] ?? state }

    static func color(_ state: String) -> Color {
        switch state {
        case "DORMANT": return Theme.textTertiary
        case "INTRODUCED": return Theme.info
        case "ACTIVE": return Theme.success
        case "DAMAGED": return Theme.error
        case "RESOLVED": return Theme.textTertiary
        default: return Theme.textSecondary
        }
    }
}

/// 道具事件类型标签 — PropDetailDrawer.vue:85-88
enum PropEventLabels {
    static let labels: [String: String] = [
        "INTRODUCED": "登场", "USED": "使用", "TRANSFERRED": "转移",
        "DAMAGED": "损毁", "REPAIRED": "修复", "UPGRADED": "强化", "RESOLVED": "结局",
    ]
    static func label(_ type: String) -> String { labels[type] ?? type }
    static func color(_ type: String) -> Color {
        switch type {
        case "DAMAGED": return Theme.error
        case "REPAIRED", "INTRODUCED": return Theme.success
        case "TRANSFERRED": return Theme.warning
        default: return Theme.info
        }
    }
    static var allTypes: [String] { ["INTRODUCED", "USED", "TRANSFERRED", "DAMAGED", "REPAIRED", "UPGRADED", "RESOLVED"] }
}

struct PropManagerPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var novelStore: NovelStore
    @StateObject private var store = PropStore()
    @State private var selectedProp: PropDTO?
    @State private var showCreateModal = false
    @State private var editingProp: PropDTO?
    @State private var showReindexConfirm = false
    @State private var charOptions: [(id: String, name: String)] = []

    // 表单
    @State private var formName = ""
    @State private var formDescription = ""
    @State private var formAliases = ""
    @State private var formCategory = "OTHER"
    @State private var formHolderId: String? = nil
    @State private var formIntroducedChapter: Int? = nil

    private var currentChapterNumber: Int? {
        novelStore.currentChapter?.number
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            // P2-11：用法提示折叠面板 — ManuscriptPropsPanel.vue:13-17
            DisclosureGroup("用法：在正文中插入 [[prop:道具ID|显示名]] 引用道具") {
                Text("示例：他拿起 [[prop:bronze-compass|青铜罗盘]]，指针剧烈颤抖。保存章节后系统自动建立道具事件并更新生命周期状态。")
                    .font(.system(size: 10)).foregroundColor(Theme.textTertiary)
            }
            .font(.system(size: 10))
            .padding(.horizontal, 12).padding(.vertical, 4)

            if currentChapterNumber != nil {
                entityIndexSection
            }
            propsListSection
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await loadAll(novelId: novelId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WorkbenchStore.deskTickNotification)) { _ in
            if let novelId = appState.currentNovelId {
                Task { await loadAll(novelId: novelId) }
            }
        }
        .onChange(of: appState.currentNovelId) { newId in
            if let novelId = newId {
                Task { await loadAll(novelId: novelId) }
            }
        }
        .sheet(item: $selectedProp) { prop in
            PropDetailDrawer(prop: prop, slug: appState.currentNovelId ?? "", charOptions: charOptions) {
                Task {
                    if let novelId = appState.currentNovelId {
                        await store.loadProps(novelId: novelId)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateModal) {
            createEditModal
        }
    }

    private func loadAll(novelId: String) async {
        await store.loadProps(novelId: novelId)
        if let ch = currentChapterNumber {
            await store.loadChapterMentions(novelId: novelId, chapterNumber: ch)
        }
        await loadCharOptions(novelId: novelId)
    }

    // MARK: - Header — ManuscriptPropsPanel.vue:5-10
    private var headerBar: some View {
        HStack {
            Text("手稿道具").font(.system(size: 14, weight: .bold))
            Spacer()
            Button(action: { openCreate() }) {
                Label("+ 新建", systemImage: "plus").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: - 实体索引 — ManuscriptPropsPanel.vue:34-70
    private var entityIndexSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bookmark.fill").font(.system(size: 11)).foregroundColor(Theme.info)
                Text("本章实体索引").font(.system(size: 12, weight: .semibold))
                Text("自动").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Theme.tertiaryBackground).cornerRadius(3)
                Spacer()
                Button {
                    if let novelId = appState.currentNovelId, let ch = currentChapterNumber {
                        Task { await store.loadChapterMentions(novelId: novelId, chapterNumber: ch) }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)

                Button {
                    showReindexConfirm = true
                } label: {
                    Text("▾").font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .confirmationDialog("从正文重建索引？", isPresented: $showReindexConfirm) {
                    Button("从正文重建") {
                        if let novelId = appState.currentNovelId, let ch = currentChapterNumber {
                            Task { await store.reindexChapterMentions(novelId: novelId, chapterNumber: ch) }
                        }
                    }
                    Button("取消", role: .cancel) {}
                }
            }
            if store.chapterMentions.isEmpty {
                Text("尚无索引，保存章节或「从正文重建」")
                    .font(.system(size: 11)).foregroundColor(Theme.textTertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(store.chapterMentions) { mention in
                        entityTag(mention)
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func entityTag(_ mention: ChapterEntityMention) -> some View {
        HStack(spacing: 2) {
            Text(mention.displayLabel).font(.system(size: 10))
            if mention.mentionCount > 1 {
                Text("×\(mention.mentionCount)").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(entityColor(mention.entityKind).opacity(0.12))
        .foregroundColor(entityColor(mention.entityKind))
        .cornerRadius(10)
    }

    private func entityColor(_ kind: String) -> Color {
        switch kind {
        case "char": return Theme.success
        case "faction": return Theme.warning
        case "prop": return Theme.info
        default: return Theme.textSecondary
        }
    }

    // MARK: - 道具库列表 — ManuscriptPropsPanel.vue:73-103
    private var propsListSection: some View {
        ScrollView {
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "briefcase.fill").font(.system(size: 11)).foregroundColor(Theme.warning)
                    Text("道具库").font(.system(size: 12, weight: .semibold))
                    if !store.props.isEmpty {
                        Text("\(store.props.count) 件")
                            .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.top, 8)

                if store.props.isEmpty && !store.isLoading {
                    VStack(spacing: 6) {
                        Text("📦").font(.system(size: 28))
                        Text("暂无道具").font(.system(size: 11)).foregroundColor(Theme.textTertiary)
                        Button(action: openCreate) {
                            Text("+ 新建道具").font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else if store.isLoading && store.props.isEmpty {
                    // P2-12：骨架屏 — ManuscriptPropsPanel.vue:74-80 n-skeleton
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.tertiaryBackground)
                            .frame(height: 48)
                            .redacted(reason: .placeholder)
                            .padding(.horizontal, 12)
                    }
                } else {
                    ForEach(store.props) { prop in
                        propRow(prop)
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func propRow(_ prop: PropDTO) -> some View {
        Button { selectedProp = prop } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(PropCategoryLabels.icon(prop.propCategory))
                        .font(.system(size: 12))
                    Text(prop.name).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(PropLifecycleLabels.label(prop.lifecycleState))
                        .font(.system(size: 9))
                        .foregroundColor(PropLifecycleLabels.color(prop.lifecycleState))
                    // 关键道具标记
                    if isKeyProp(prop) {
                        Text("关键")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.warning)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Theme.warning.opacity(0.12))
                            .cornerRadius(3)
                    }
                }
                if !prop.description.isEmpty {
                    Text(prop.description).font(.system(size: 10)).foregroundColor(Theme.textTertiary).lineLimit(1)
                }
                HStack(spacing: 8) {
                    if let holder = prop.holderCharacterId {
                        Text("持有: \(charOptions.first(where: { $0.id == holder })?.name ?? String(holder.prefix(6)))")
                            .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                    }
                    if let ch = prop.introducedChapter {
                        Text("第\(ch)章登场").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                    // 关键道具切换
                    Button {
                        Task {
                            if let novelId = appState.currentNovelId {
                                await store.togglePropKey(novelId: novelId, propId: prop.id, currentKeyContext: isKeyProp(prop))
                            }
                        }
                    } label: {
                        Text(isKeyProp(prop) ? "关键" : "普通")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(isKeyProp(prop) ? Theme.warning : Theme.textTertiary)
                    }
                    .buttonStyle(.plain)

                    Button("编辑") { openEdit(prop) }
                        .buttonStyle(.bordered).controlSize(.mini)

                    Button("删") {
                        Task {
                            if let novelId = appState.currentNovelId {
                                await store.deleteProp(novelId: novelId, propId: prop.id)
                            }
                        }
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                    .foregroundColor(Theme.error)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private func isKeyProp(_ prop: PropDTO) -> Bool {
        if let val = prop.attributes["key_context"]?.boolValue { return val }
        if let val = prop.attributes["key_context"]?.intValue { return val != 0 }
        return false
    }

    // MARK: - 创建/编辑弹窗 — ManuscriptPropsPanel.vue:108-155
    private var createEditModal: some View {
        NavigationStack {
            Form {
                Section("道具信息") {
                    TextField("名称（如：青铜罗盘）", text: $formName)
                    VStack(alignment: .leading) {
                        Text("简述").font(.caption).foregroundColor(Theme.textTertiary)
                        TextField("简述", text: $formDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder).lineLimit(2...6)
                    }
                    VStack(alignment: .leading) {
                        Text("别名（逗号分隔）").font(.caption).foregroundColor(Theme.textTertiary)
                        TextField("罗盘,司南", text: $formAliases)
                            .textFieldStyle(.roundedBorder)
                    }
                    Picker("分类", selection: $formCategory) {
                        ForEach(PropCategoryLabels.labels.keys.sorted(), id: \.self) { key in
                            Text(PropCategoryLabels.label(key)).tag(key)
                        }
                    }
                    Picker("持有者", selection: $formHolderId) {
                        Text("无").tag(String?.none)
                        ForEach(charOptions, id: \.id) { ch in
                            Text(ch.name).tag(String?.some(ch.id))
                        }
                    }
                    HStack {
                        Text("登场章")
                        Spacer()
                        Stepper(value: Binding(
                            get: { formIntroducedChapter ?? 0 },
                            set: { formIntroducedChapter = $0 > 0 ? $0 : nil }
                        ), in: 0...9999) {
                            Text(formIntroducedChapter.map { "第 \($0) 章" } ?? "可选")
                        }
                    }
                }
            }
            .navigationTitle(editingProp != nil ? "编辑道具" : "新建道具")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showCreateModal = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await submitForm() } }
                        .disabled(formName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func openCreate() {
        editingProp = nil
        formName = ""
        formDescription = ""
        formAliases = ""
        formCategory = "OTHER"
        formHolderId = nil
        formIntroducedChapter = currentChapterNumber
        showCreateModal = true
    }

    private func openEdit(_ prop: PropDTO) {
        editingProp = prop
        formName = prop.name
        formDescription = prop.description
        formAliases = prop.aliases.joined(separator: ",")
        formCategory = prop.propCategory
        formHolderId = prop.holderCharacterId
        formIntroducedChapter = prop.introducedChapter
        showCreateModal = true
    }

    private func submitForm() async {
        guard let novelId = appState.currentNovelId,
              !formName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let aliases = formAliases
            .components(separatedBy: CharacterSet(charactersIn: ",，"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let prop = editingProp {
            let request = PatchPropRequest(
                name: formName.trimmingCharacters(in: .whitespaces),
                description: formDescription, aliases: aliases,
                propCategory: formCategory, lifecycleState: nil,
                holderCharacterId: formHolderId, introducedChapter: formIntroducedChapter,
                attributes: nil
            )
            await store.updateProp(novelId: novelId, propId: prop.id, request: request)
        } else {
            let request = CreatePropRequest(
                name: formName.trimmingCharacters(in: .whitespaces),
                description: formDescription, aliases: aliases,
                propCategory: formCategory,
                holderCharacterId: formHolderId,
                introducedChapter: formIntroducedChapter,
                attributes: [:]
            )
            await store.createProp(novelId: novelId, request: request)
        }
        showCreateModal = false
        await store.loadProps(novelId: novelId)
    }

    private func loadCharOptions(novelId: String) async {
        do {
            let response: [CharacterDTO] = try await APIClient.shared.request(
                APIEndpoint.Bible.characters(novelId: novelId)
            )
            charOptions = response.map { (id: $0.id, name: $0.name) }
        } catch {
            charOptions = []
        }
    }
}

// MARK: - FlowLayout（简易换行布局）

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth && lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxX = bounds.maxX
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
