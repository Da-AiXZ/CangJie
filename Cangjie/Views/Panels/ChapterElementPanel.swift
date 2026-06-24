//
//  ChapterElementPanel.swift
//  Cangjie
//
//  章节元素面板：人物/地点/道具分组 + Bible ID→name映射 + filterType筛选 + CRUD。
//  对齐原版 ChapterElementPanel.vue:1-446 + chapterElement.ts:1-75。
//  机制4：每个区块标注原版文件+行号。
//

import SwiftUI

/// 章节元素 Store — 管理 ChapterElement CRUD
/// 对齐原版 chapterElement.ts:37-75 chapterElementApi
@MainActor
final class ChapterElementStore: ObservableObject {

    // MARK: - 状态

    /// 元素列表 — ChapterElementPanel.vue:218
    @Published var elements: [ChapterElementDTO] = []

    /// 是否正在加载 — ChapterElementPanel.vue:219
    @Published var isLoading: Bool = false

    /// 筛选类型 — ChapterElementPanel.vue:222
    @Published var filterType: String? = nil

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// Bible 角色列表（用于 ID→name映射） — ChapterElementPanel.vue:225
    @Published var bibleCharacters: [CharacterDTO] = []

    /// Bible 地点列表 — ChapterElementPanel.vue:226
    @Published var bibleLocations: [LocationDTO] = []

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 加载元素列表 — chapterElement.ts:38-44 getElements()

    /// 加载章节元素列表 — ChapterElementPanel.vue:316-327 loadElements()
    /// - Parameter chapterId: 章节 ID（ChapterDTO.id）
    func loadElements(chapterId: String) async {
        guard !chapterId.isEmpty else { return }
        isLoading = true
        self.errorMessage = nil

        do {
            let response: ChapterElementListResponse = try await apiClient.request(
                APIEndpoint.ChapterElement.list(chapterId: chapterId)
            )
            var data = response.data ?? []
            // 按筛选类型过滤 — chapterElement.ts:42 params: element_type
            if let filter = filterType, !filter.isEmpty {
                data = data.filter { $0.elementType == filter }
            }
            self.elements = data
        } catch {
            self.errorMessage = "加载章节元素失败"
        }

        isLoading = false
    }

    // MARK: - 添加元素 — chapterElement.ts:46-52 addElement()

    /// 添加章节元素
    /// - Parameters:
    ///   - chapterId: 章节 ID
    ///   - element: 创建请求体
    func addElement(chapterId: String, element: ChapterElementCreate) async {
        do {
            let response: ChapterElementSingleResponse = try await apiClient.request(
                APIEndpoint.ChapterElement.create(chapterId: chapterId),
                body: element
            )
            if let data = response.data {
                elements.append(data)
            }
        } catch {
            self.errorMessage = "添加元素失败"
        }
    }

    // MARK: - 批量更新 — chapterElement.ts:54-60 batchUpdate()

    /// 批量替换章节元素
    /// - Parameters:
    ///   - chapterId: 章节 ID
    ///   - elements: 元素列表
    func batchUpdate(chapterId: String, elements: [ChapterElementCreate]) async {
        do {
            let request = ChapterElementBatchUpdateRequest(elements: elements)
            let response: ChapterElementBatchUpdateResponse = try await apiClient.request(
                APIEndpoint.ChapterElement.batchUpdate(chapterId: chapterId),
                body: request
            )
            if let data = response.data {
                self.elements = data.elements ?? []
            }
        } catch {
            self.errorMessage = "批量更新失败"
        }
    }

    // MARK: - 删除元素 — chapterElement.ts:62-67 deleteElement()

    /// 删除章节元素
    /// - Parameters:
    ///   - chapterId: 章节 ID
    ///   - elementId: 元素 ID
    func deleteElement(chapterId: String, elementId: String) async {
        do {
            let _: ChapterElementDeleteResponse = try await apiClient.request(
                APIEndpoint.ChapterElement.delete(chapterId: chapterId, elementId: elementId)
            )
            elements.removeAll { $0.id == elementId }
        } catch {
            self.errorMessage = "删除元素失败"
        }
    }

    // MARK: - 反查元素出现章节 — chapterElement.ts:69-74 getElementChapters()

    /// 反查元素出现的章节
    /// - Parameters:
    ///   - elementType: 元素类型
    ///   - elementId: 元素 ID
    /// - Returns: 出现次数和章节列表
    func getElementChapters(elementType: String, elementId: String) async -> (Int, [AnyCodable]) {
        do {
            let response: ChapterElementChaptersResponse = try await apiClient.request(
                APIEndpoint.ChapterElement.chaptersByElement(elementType: elementType, elementId: elementId)
            )
            let count = response.data?.appearanceCount ?? 0
            let chapters = response.data?.chapters ?? []
            return (count, chapters)
        } catch {
            return (0, [])
        }
    }

    // MARK: - 加载 Bible 数据 — ChapterElementPanel.vue:330-339 loadBible()

    /// 加载 Bible 数据用于 ID→name映射
    /// - Parameter novelId: 小说 ID
    func loadBible(novelId: String) async {
        do {
            let bible: BibleDTO = try await apiClient.request(
                APIEndpoint.Bible.get(novelId: novelId)
            )
            self.bibleCharacters = bible.characters
            self.bibleLocations = bible.locations
        } catch {
            self.bibleCharacters = []
            self.bibleLocations = []
        }
    }

    // MARK: - ID→name映射 — ChapterElementPanel.vue:238-248 getElementDisplayName()

    /// 获取元素显示名称（从 Bible 映射）
    /// - Parameters:
    ///   - elementId: 元素 ID
    ///   - type: 元素类型
    /// - Returns: 显示名称
    func getElementDisplayName(elementId: String, type: String) -> String {
        if type == "character" {
            if let char = bibleCharacters.first(where: { $0.id == elementId }) {
                return char.name
            }
        }
        if type == "location" {
            if let loc = bibleLocations.first(where: { $0.id == elementId }) {
                return loc.name
            }
        }
        return elementId
    }

    // MARK: - 分组计算属性 — ChapterElementPanel.vue:250-258

    /// 人物分组 — ChapterElementPanel.vue:250-252
    var groupedCharacters: [ChapterElementDTO] {
        return elements.filter { $0.elementType == "character" }
    }

    /// 地点分组 — ChapterElementPanel.vue:253-255
    var groupedLocations: [ChapterElementDTO] {
        return elements.filter { $0.elementType == "location" }
    }

    /// 其他分组（道具/组织/事件） — ChapterElementPanel.vue:256-258
    var groupedOther: [ChapterElementDTO] {
        return elements.filter { $0.elementType != "character" && $0.elementType != "location" }
    }
}

// MARK: - 章节元素面板 — ChapterElementPanel.vue:1-446

/// 章节元素面板 — ChapterElementPanel.vue:1-446
struct ChapterElementPanel: View {

    @EnvironmentObject var novelStore: NovelStore
    @EnvironmentObject var appState: AppState
    @StateObject private var elementStore = ChapterElementStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // 区块1: 无章节时显示空状态 — ChapterElementPanel.vue:3
                if novelStore.currentChapter == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.textTertiary)
                        Text("请先从左侧选择一个章节")
                            .font(Theme.captionFont())
                            .foregroundColor(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    elementContent
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        // 区块: watch slug → loadBible + loadElements — ChapterElementPanel.vue:345-356
        .onChange(of: appState.currentNovelId) { _ in
            loadData()
        }
        // 区块: watch currentChapterNumber → loadElements — ChapterElementPanel.vue:358-361
        .onChange(of: novelStore.currentChapter?.id) { _ in
            loadData()
        }
        // 区块: onMounted → loadBible + loadElements — ChapterElementPanel.vue:376-380
        .onAppear {
            loadData()
        }
    }

    // MARK: - 元素内容 — ChapterElementPanel.vue:5-167

    private var elementContent: some View {
        VStack(spacing: 12) {
            // 区块2: 人物/地点/道具卡片 — ChapterElementPanel.vue:12-90
            VStack(spacing: 8) {
                // 卡片头部 — ChapterElementPanel.vue:13-32
                HStack {
                    Text("👥 人物 / 地点 / 道具")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    // 筛选器 — ChapterElementPanel.vue:17-25
                    Picker("类型", selection: $elementStore.filterType) {
                        Text("全部").tag(String?.none)
                        Text("人物").tag(String?.some("character"))
                        Text("地点").tag(String?.some("location"))
                        Text("道具").tag(String?.some("item"))
                        Text("组织").tag(String?.some("organization"))
                        Text("事件").tag(String?.some("event"))
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                    // 刷新按钮 — ChapterElementPanel.vue:26
                    Button {
                        loadData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Text("本章涉及的元素，来自叙事同步")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)

                // 加载中 — ChapterElementPanel.vue:34 n-spin
                if elementStore.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    // 区块3: 人物分组 — ChapterElementPanel.vue:36-50
                    if !elementStore.groupedCharacters.isEmpty {
                        elementGroup(title: "👤 人物", items: elementStore.groupedCharacters)
                    }

                    // 区块4: 地点分组 — ChapterElementPanel.vue:52-66
                    if !elementStore.groupedLocations.isEmpty {
                        elementGroup(title: "📍 地点", items: elementStore.groupedLocations)
                    }

                    // 区块5: 其他分组 — ChapterElementPanel.vue:68-86
                    if !elementStore.groupedOther.isEmpty {
                        otherGroup
                    }

                    // 区块6: 空元素提示 — ChapterElementPanel.vue:87
                    if elementStore.elements.isEmpty {
                        Text("暂无关联元素")
                            .font(Theme.captionFont())
                            .foregroundColor(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
            .padding()
            .background(Theme.secondaryBackground)
            .cornerRadius(8)
        }
    }

    // MARK: - 元素分组（人物/地点） — ChapterElementPanel.vue:36-66

    private func elementGroup(title: String, items: [ChapterElementDTO]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))

            ForEach(items) { elem in
                elementRow(elem)
            }
        }
    }

    // MARK: - 其他分组 — ChapterElementPanel.vue:68-86

    private var otherGroup: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("📦 其他")
                .font(.system(size: 12, weight: .semibold))

            ForEach(elementStore.groupedOther) { elem in
                HStack(spacing: 6) {
                    // 元素类型标签 — ChapterElementPanel.vue:72-74
                    Text(elementTypeLabel(elem.elementType))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(elementTypeColor(elem.elementType))
                        .cornerRadius(8)

                    // 元素名称 — ChapterElementPanel.vue:75
                    Text(elementStore.getElementDisplayName(elementId: elem.elementId, type: elem.elementType))
                        .font(.system(size: 12, weight: .medium))

                    // 关系标签 — ChapterElementPanel.vue:76
                    Text(relationLabel(elem.relationType))
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.textTertiary.opacity(0.15))
                        .cornerRadius(8)

                    // 重要度标签 — ChapterElementPanel.vue:77-79
                    Text(importanceLabel(elem.importance))
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(importanceColor(elem.importance))
                        .cornerRadius(8)

                    // 备注 — ChapterElementPanel.vue:80-82
                    if let notes = elem.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - 元素行 — ChapterElementPanel.vue:39-48

    private func elementRow(_ elem: ChapterElementDTO) -> some View {
        HStack(spacing: 6) {
            // 元素名称 — ChapterElementPanel.vue:40
            Text(elementStore.getElementDisplayName(elementId: elem.elementId, type: elem.elementType))
                .font(.system(size: 12, weight: .medium))

            // 关系标签 — ChapterElementPanel.vue:41
            Text(relationLabel(elem.relationType))
                .font(.system(size: 10))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.textTertiary.opacity(0.15))
                .cornerRadius(8)

            // 重要度标签 — ChapterElementPanel.vue:42-44
            Text(importanceLabel(elem.importance))
                .font(.system(size: 10))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(importanceColor(elem.importance))
                .cornerRadius(8)

            // 备注 — ChapterElementPanel.vue:45-47
            if let notes = elem.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - 方法

    /// 加载数据 — ChapterElementPanel.vue:376-380 onMounted
    private func loadData() {
        guard let novelId = appState.currentNovelId,
              let chapterId = novelStore.currentChapter?.id else { return }

        Task {
            // 先加载 Bible（ID→name映射） — ChapterElementPanel.vue:330-339
            await elementStore.loadBible(novelId: novelId)
            // 再加载元素 — ChapterElementPanel.vue:316-327
            await elementStore.loadElements(chapterId: chapterId)
        }
    }

    // MARK: - 标签辅助函数 — chapterElement.ts(domain):8-29

    /// 元素类型中文标签 — chapterElement.ts(domain):8-14
    private func elementTypeLabel(_ type: String) -> String {
        switch type {
        case "character": return "人物"
        case "location": return "地点"
        case "item": return "道具"
        case "organization": return "组织"
        case "event": return "事件"
        default: return type
        }
    }

    /// 元素类型着色 — chapterElement.ts(domain):8-14
    private func elementTypeColor(_ type: String) -> Color {
        switch type {
        case "character": return .red
        case "location": return .green
        case "item": return .orange
        case "organization": return .blue
        case "event": return .gray
        default: return .gray
        }
    }

    /// 关系类型中文标签 — chapterElement.ts(domain):16-23
    private func relationLabel(_ relation: String) -> String {
        switch relation {
        case "appears": return "出场"
        case "mentioned": return "提及"
        case "scene": return "场景"
        case "uses": return "使用"
        case "involved": return "参与"
        case "occurs": return "发生"
        default: return relation
        }
    }

    /// 重要度中文标签 — chapterElement.ts(domain):25-29
    private func importanceLabel(_ importance: String) -> String {
        switch importance {
        case "major": return "主要"
        case "normal": return "一般"
        case "minor": return "次要"
        default: return importance
        }
    }

    /// 重要度着色 — chapterElement.ts(domain):25-29
    private func importanceColor(_ importance: String) -> Color {
        switch importance {
        case "major": return .red.opacity(0.2)
        case "normal": return .blue.opacity(0.2)
        case "minor": return .gray.opacity(0.2)
        default: return .gray.opacity(0.2)
        }
    }
}
