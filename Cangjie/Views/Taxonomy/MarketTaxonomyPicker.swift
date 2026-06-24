//
//  MarketTaxonomyPicker.swift
//  Cangjie
//
//  市场题材选择器 — 对齐 MarketTaxonomyPicker.vue:1-495（26条功能点）。
//  6 个 @Binding 双向绑定，本地加载 bundle.json（决策3）。
//  搜索过滤 + pickMajor/pickTheme + syncFromGenreString 反向同步。
//

import SwiftUI

/// 市场题材选择器 — 对齐 MarketTaxonomyPicker.vue:1-495
struct MarketTaxonomyPicker: View {

    // MARK: - 6 个双向绑定（对齐 MarketTaxonomyPicker.vue:164-169 defineModel）

    @Binding var genre: String
    @Binding var worldPreset: String
    @Binding var storyStructure: String
    @Binding var pacingControl: String
    @Binding var writingStyle: String
    @Binding var specialRequirements: String

    // MARK: - Props（对齐 MarketTaxonomyPicker.vue:153-162 withDefaults）

    var locale: String = TaxonomyStore.cnLocale
    var disabled: Bool = false

    // MARK: - Store

    @StateObject private var taxonomyStore = TaxonomyStore()

    // MARK: - 本地状态（对齐 MarketTaxonomyPicker.vue:175-177）

    @State private var searchQuery: String = ""
    @State private var pickedMajorId: String? = nil
    @State private var pickedThemeId: String? = nil

    // MARK: - 计算属性

    /// roots — 对齐 MarketTaxonomyPicker.vue:171 BUILTIN_CN_MARKET_V1.roots
    private var roots: [TaxonomyNode] {
        taxonomyStore.roots
    }

    /// rootsCount — 对齐 MarketTaxonomyPicker.vue:172
    private var rootsCount: Int {
        roots.count
    }

    /// searchTable — 对齐 MarketTaxonomyPicker.vue:173 flattenRootsForSearch(roots)
    private var searchTable: [TaxonomyStore.FlatSearchHit] {
        TaxonomyStore.flattenRootsForSearch(roots: roots)
    }

    /// 过滤后的大类 — 对齐 MarketTaxonomyPicker.vue:183-193 filteredMajors
    private var filteredMajors: [TaxonomyNode] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return roots }
        var out: [TaxonomyNode] = []
        for hit in searchTable {
            if hit.scoreAid.contains(q) {
                out.append(hit.root)
            }
        }
        return out.isEmpty ? [] : out
    }

    /// 当前选中大类 — 对齐 MarketTaxonomyPicker.vue:195-199 activeMajor
    private var activeMajor: TaxonomyNode? {
        guard let id = pickedMajorId else { return nil }
        return roots.first { $0.id == id }
    }

    /// 当前选中主题 — 对齐 MarketTaxonomyPicker.vue:201-206 activeTheme
    private var activeTheme: TaxonomyNode? {
        guard let major = activeMajor, let id = pickedThemeId else { return nil }
        return major.children?.first { $0.id == id }
    }

    /// 大类标签 — 对齐 MarketTaxonomyPicker.vue:208-210 activeMajorLabel
    private var activeMajorLabel: String {
        guard let major = activeMajor else { return "" }
        return TaxonomyStore.pickLocaleLabel(major, locale: locale)
    }

    /// 主题标签 — 对齐 MarketTaxonomyPicker.vue:212-214 activeThemeLabel
    private var activeThemeLabel: String {
        guard let theme = activeTheme else { return "" }
        return TaxonomyStore.pickLocaleLabel(theme, locale: locale)
    }

    /// 赛道属性 — 对齐 MarketTaxonomyPicker.vue:216-219 activeMarketTrack
    private var activeMarketTrack: String {
        guard let major = activeMajor else { return "" }
        return major.facets?.marketTrack ?? ""
    }

    /// 引擎大类 — 对齐 MarketTaxonomyPicker.vue:316-321 themeAgentKeyDisplay
    private var themeAgentKeyDisplay: String {
        guard let major = activeMajor, pickedThemeId != nil else { return "" }
        let k = TaxonomyStore.themeAgentKeyForSelection(root: major)
        return k.isEmpty ? "" : "theme:\(k)"
    }

    // MARK: - Body（对齐 MarketTaxonomyPicker.vue:1-128）

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 对齐 MarketTaxonomyPicker.vue:3-16 搜索框
            searchBar

            // 对齐 MarketTaxonomyPicker.vue:18-37 ① 大类
            majorSection

            // 对齐 MarketTaxonomyPicker.vue:39-123 mtp-detail
            if activeMajor != nil {
                detailSection
            } else if filteredMajors.isEmpty {
                // 对齐 MarketTaxonomyPicker.vue:124-126 mtp-empty-search
                Text("没有找到匹配的分类，换一个关键词试试")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .opacity(disabled ? 0.72 : 1.0) // 对齐 MarketTaxonomyPicker.vue:331-333 mtp--busy
        .onAppear {
            taxonomyStore.loadBuiltinCNBundle()
            // 对齐 MarketTaxonomyPicker.vue:281-289 watch genre → syncFromGenreString
            if pickedMajorId == nil && genre.contains("/") {
                syncFromGenreString()
            }
        }
        .onChange(of: searchQuery) { _ in
            // 对齐 MarketTaxonomyPicker.vue:256-262 watch filteredMajors
            guard let pickedId = pickedMajorId else { return }
            if !filteredMajors.contains(where: { $0.id == pickedId }) {
                pickedMajorId = filteredMajors.first?.id
                pickedThemeId = nil
            }
        }
    }

    // MARK: - 搜索框（对齐 MarketTaxonomyPicker.vue:3-16）

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textTertiary)
            TextField(
                "搜索大类、主题关键词（如「电竞」「废土」「谍战」）…",
                text: $searchQuery
            )
            .disabled(disabled)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(10)
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .padding(.bottom, 8)
    }

    // MARK: - ① 大类（对齐 MarketTaxonomyPicker.vue:18-37）

    private var majorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("① 大类")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("已过滤 \(filteredMajors.count) / \(rootsCount)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
            }
            // 对齐 MarketTaxonomyPicker.vue:22-37 mtp-major-row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filteredMajors, id: \.id) { maj in
                        Button {
                            pickMajor(maj)
                        } label: {
                            Text(TaxonomyStore.pickLocaleLabel(maj, locale: locale))
                                .font(.system(size: 13, weight: pickedMajorId == maj.id ? .bold : .regular))
                                .foregroundColor(pickedMajorId == maj.id ? .white : Theme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(pickedMajorId == maj.id ? Theme.primary : Theme.secondaryBackground)
                                .cornerRadius(16)
                        }
                        .disabled(disabled)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - 详情区（对齐 MarketTaxonomyPicker.vue:39-123 mtp-detail）

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 对齐 MarketTaxonomyPicker.vue:40-61 ② 网文主题
            themeSection

            // 对齐 MarketTaxonomyPicker.vue:63-80 mtp-classify-strip
            classifyStrip

            // 对齐 MarketTaxonomyPicker.vue:82-93 ③ 世界观基调
            worldPresetSection

            // 对齐 MarketTaxonomyPicker.vue:95-122 ④ 写作原则
            writingPrinciplesSection
        }
        .padding(.top, 6)
    }

    // MARK: - ② 网文主题（对齐 MarketTaxonomyPicker.vue:40-61）

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("② 网文主题")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            if let major = activeMajor, let children = major.children, !children.isEmpty {
                // 对齐 MarketTaxonomyPicker.vue:44-56 theme chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(children, id: \.id) { ch in
                            Button {
                                if let major = activeMajor {
                                    pickTheme(root: major, leaf: ch)
                                }
                            } label: {
                                Text(TaxonomyStore.pickLocaleLabel(ch, locale: locale))
                                    .font(.system(size: 13, weight: pickedThemeId == ch.id ? .bold : .regular))
                                    .foregroundColor(pickedThemeId == ch.id ? Theme.primary : Theme.textSecondary)
                            }
                            .disabled(disabled)
                        }
                    }
                }
            } else {
                // 对齐 MarketTaxonomyPicker.vue:58-60
                Text("该大类暂无细分节点")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    // MARK: - 分类信息条（对齐 MarketTaxonomyPicker.vue:63-80）

    private var classifyStrip: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 8) {
            classifyItem("市场大类", activeMajorLabel)
            classifyItem("细分主题", activeThemeLabel.isEmpty ? "未选择" : activeThemeLabel)
            classifyItem("赛道属性", activeMarketTrack.isEmpty ? "未配置" : activeMarketTrack)
            classifyItem("引擎大类", themeAgentKeyDisplay.isEmpty ? "theme:other" : themeAgentKeyDisplay)
        }
        .padding(.top, 4)
    }

    /// 分类信息条目 — 对齐 MarketTaxonomyPicker.vue:402-419 .mtp-classify-item
    private func classifyItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - ③ 世界观基调（对齐 MarketTaxonomyPicker.vue:82-93）

    private var worldPresetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("③ 世界观基调")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                Text("可修改，重写后仍为「预设 + 自定义」语义")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
            }
            // 对齐 MarketTaxonomyPicker.vue:86-93 textarea
            TextEditor(text: $worldPreset)
                .frame(minHeight: 80)
                .padding(4)
                .background(Theme.secondaryBackground)
                .cornerRadius(8)
                .disabled(disabled)
                .overlay(
                    Group {
                        if worldPreset.isEmpty {
                            Text("先选择一大类与一个主题…")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textTertiary)
                                .padding(.leading, 10)
                                .padding(.top, 12)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }

    // MARK: - ④ 写作原则（对齐 MarketTaxonomyPicker.vue:95-122）

    private var writingPrinciplesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("④ 写作原则")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                Text("四个大类均按当前主题独立生成，可修改")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
            }
            // 对齐 MarketTaxonomyPicker.vue:99-122 mtp-writing-grid（2列）
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 12) {
                principleCard(
                    index: "01",
                    title: "剧情结构",
                    scope: "\(activeMajorLabel.isEmpty ? "大类" : activeMajorLabel) / \(activeThemeLabel.isEmpty ? "主题" : activeThemeLabel) 的开篇、发展、高潮、结尾",
                    note: "沿用四段框架，但切入点、推进对象、高潮落点和续作伏笔必须落到主题主句。",
                    text: $storyStructure
                )
                principleCard(
                    index: "02",
                    title: "节奏把控",
                    scope: "\(activeMarketTrack.isEmpty ? "赛道" : activeMarketTrack) 的小 / 中 / 大爽点排布",
                    note: "不按固定字数阈值切分，按具体压力、选择、可见回报和新增代价安排触发点。",
                    text: $pacingControl
                )
                principleCard(
                    index: "03",
                    title: "写作风格",
                    scope: "\(activeThemeLabel.isEmpty ? "主题" : activeThemeLabel) 的叙事、环境描写、人物对话",
                    note: "分别约束叙事推进、场景质感和角色声口，避免只套用大类通用语气。",
                    text: $writingStyle
                )
                principleCard(
                    index: "04",
                    title: "特殊要求",
                    scope: "\(activeMajorLabel.isEmpty ? "大类" : activeMajorLabel) / \(activeThemeLabel.isEmpty ? "主题" : activeThemeLabel) 的专属创作细则",
                    note: "围绕大类、主题主句和赛道约束定制禁忌与要求，避免只复述分类名。",
                    text: $specialRequirements
                )
            }
        }
    }

    /// 写作原则卡片 — 对齐 MarketTaxonomyPicker.vue:100-121 mtp-principle-card
    private func principleCard(
        index: String,
        title: String,
        scope: String,
        note: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 9) {
                // 对齐 MarketTaxonomyPicker.vue:446-459 mtp-principle-index
                Text(index)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Color(red: 0.145, green: 0.388, blue: 0.922))
                    .frame(width: 28, height: 22)
                    .background(Color(red: 0.145, green: 0.388, blue: 0.922).opacity(0.09))
                    .cornerRadius(7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(scope)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            Text(note)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .lineLimit(3)
            // 对齐 MarketTaxonomyPicker.vue:113-120 textarea
            TextEditor(text: text)
                .frame(minHeight: 100)
                .padding(4)
                .background(Theme.secondaryBackground)
                .cornerRadius(8)
                .disabled(disabled)
        }
        .padding(12)
        .background(Theme.secondaryBackground.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - 选择大类（对齐 MarketTaxonomyPicker.vue:291-299 pickMajor）

    private func pickMajor(_ root: TaxonomyNode) {
        pickedMajorId = root.id
        let first = root.children?.first
        pickedThemeId = first?.id

        // 对齐 MarketTaxonomyPicker.vue:296 genre = marketMajorThemeGenre
        if let first = first {
            genre = TaxonomyStore.marketMajorThemeGenre(root: root, leaf: first, locale: locale)
        } else {
            genre = ""
        }
        // 对齐 MarketTaxonomyPicker.vue:297 worldPreset = worldToneForSelection
        worldPreset = TaxonomyStore.worldToneForSelection(root: root, leaf: first)
        // 对齐 MarketTaxonomyPicker.vue:298 applyWritingProfile
        applyWritingProfile(root: root, leaf: first)
    }

    // MARK: - 选择主题（对齐 MarketTaxonomyPicker.vue:301-306 pickTheme）

    private func pickTheme(root: TaxonomyNode, leaf: TaxonomyNode) {
        pickedThemeId = leaf.id
        // 对齐 MarketTaxonomyPicker.vue:303 genre
        genre = TaxonomyStore.marketMajorThemeGenre(root: root, leaf: leaf, locale: locale)
        // 对齐 MarketTaxonomyPicker.vue:304 worldPreset
        worldPreset = TaxonomyStore.worldToneForSelection(root: root, leaf: leaf)
        // 对齐 MarketTaxonomyPicker.vue:305 applyWritingProfile
        applyWritingProfile(root: root, leaf: leaf)
    }

    // MARK: - 应用写作原则（对齐 MarketTaxonomyPicker.vue:308-314 applyWritingProfile）

    private func applyWritingProfile(root: TaxonomyNode, leaf: TaxonomyNode?) {
        let profile = TaxonomyStore.writingProfileForSelection(root: root, leaf: leaf)
        // 对齐 MarketTaxonomyPicker.vue:310-313
        storyStructure = profile.storyStructure?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        pacingControl = profile.pacingControl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        writingStyle = profile.writingStyle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        specialRequirements = profile.specialRequirements?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - 反向同步（对齐 MarketTaxonomyPicker.vue:264-279 syncFromGenreString）

    /// 从 genre 字符串反向同步选择状态 — 对齐 MarketTaxonomyPicker.vue:264-279
    private func syncFromGenreString() {
        let g = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard g.contains("/") else { return }

        let parts = g.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return }

        let majorLabel = parts[0].trimmingCharacters(in: .whitespaces)
        let themeLabel = parts[1].trimmingCharacters(in: .whitespaces)

        for r in roots {
            guard TaxonomyStore.pickLocaleLabel(r, locale: locale) == majorLabel else { continue }
            pickedMajorId = r.id
            if let leaf = r.children?.first(where: { TaxonomyStore.pickLocaleLabel($0, locale: locale) == themeLabel }) {
                pickedThemeId = leaf.id
                return
            }
        }
    }
}
