//
//  TaxonomyStore.swift
//  Cangjie
//
//  题材包 Store：本地加载 builtin_cn_v1.bundle.json + cnMarket.ts 辅助函数。
//  对齐原版 cnMarket.ts:1-54 + types.ts:43-48 pickLocaleLabel。
//  决策3：本地打包，不走 API（APIEndpoint.Taxonomy.builtinBundle 保留备用）。
//

import SwiftUI
import Foundation

/// 题材包 Store — 本地加载 + 搜索/选择辅助
@MainActor
final class TaxonomyStore: ObservableObject {

    // MARK: - 状态

    /// 已加载的中文题材包（对齐 cnMarket.ts:6 BUILTIN_CN_MARKET_V1）
    @Published var bundle: TaxonomyBundle?

    /// 是否加载失败
    @Published var loadError: String?

    // MARK: - 常量

    /// 中文 locale（对齐 types.ts:43 CN_LOCALE）
    static let cnLocale = "zh-CN"

    // MARK: - 本地加载

    /// 从 Bundle.main 加载 builtin_cn_v1.bundle.json（决策3）
    /// 对齐 cnMarket.ts:1 `import raw from './builtin_cn_v1.bundle.json'`
    func loadBuiltinCNBundle() {
        guard bundle == nil else { return }

        guard let url = Bundle.main.url(forResource: "builtin_cn_v1.bundle", withExtension: "json") else {
            loadError = "未找到 builtin_cn_v1.bundle.json"
            Logger.data.error("TaxonomyStore: 未找到 builtin_cn_v1.bundle.json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try CangjieDecoder.shared.decode(TaxonomyBundle.self, from: data)
            bundle = decoded
        } catch {
            loadError = "解析题材包失败: \(error.localizedDescription)"
            Logger.data.error("TaxonomyStore: 解析题材包失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 便捷属性

    /// 题材根节点列表（对齐 MarketTaxonomyPicker.vue:171 BUILTIN_CN_MARKET_V1.roots）
    var roots: [TaxonomyNode] {
        return bundle?.roots ?? []
    }

    // MARK: - 辅助函数（对齐 cnMarket.ts:8-54 + types.ts:45-48）

    /// 取本地化标签 — 对齐 types.ts:45-48 pickLocaleLabel
    static func pickLocaleLabel(_ node: TaxonomyNode, locale: String = cnLocale) -> String {
        let labels = node.labels
        if let label = labels[locale] { return label }
        if let label = labels[cnLocale] { return label }
        if let label = labels["zh"] { return label }
        if let first = labels.values.first { return first }
        return node.id
    }

    /// 大类/主题组合 genre 字符串 — 对齐 cnMarket.ts:8-10 marketMajorThemeGenre
    static func marketMajorThemeGenre(root: TaxonomyNode, leaf: TaxonomyNode, locale: String = cnLocale) -> String {
        return "\(pickLocaleLabel(root, locale: locale)) / \(pickLocaleLabel(leaf, locale: locale))"
    }

    /// facet 文本取值辅助 — 对齐 cnMarket.ts:12-15 facetTextForSelection
    private static func facetTextForSelection(root: TaxonomyNode, leaf: TaxonomyNode?, key: String) -> String {
        // 内联取值函数，避免 String? → Any? 双 Optional 问题
        func extract(_ facets: TaxonomyFacets?) -> String? {
            switch key {
            case "market_track": return facets?.marketTrack
            case "world_tone": return facets?.worldTone
            case "theme_agent_key": return facets?.themeAgentKey
            case "search_blob": return facets?.searchBlob
            default: return nil
            }
        }
        // 优先取 leaf facets，回退 root facets（对齐 cnMarket.ts:13-14）
        if let raw = extract(leaf?.facets) ?? extract(root.facets) {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    /// 世界观正文 — 对齐 cnMarket.ts:18-20 worldToneForSelection
    static func worldToneForSelection(root: TaxonomyNode, leaf: TaxonomyNode?) -> String {
        return facetTextForSelection(root: root, leaf: leaf, key: "world_tone")
    }

    /// 写作原则 profile — 对齐 cnMarket.ts:22-28 writingProfileFacet + cnMarket.ts:30-32 writingProfileForSelection
    static func writingProfileForSelection(root: TaxonomyNode, leaf: TaxonomyNode?) -> TaxonomyWritingProfile {
        let rootProfile = root.facets?.writingProfile
        let leafProfile = leaf?.facets?.writingProfile
        // 合并：leaf 覆盖 root（对齐 cnMarket.ts:27 `{ ...base, ...override }`）
        return TaxonomyWritingProfile(
            storyStructure: leafProfile?.storyStructure ?? rootProfile?.storyStructure,
            pacingControl: leafProfile?.pacingControl ?? rootProfile?.pacingControl,
            writingStyle: leafProfile?.writingStyle ?? rootProfile?.writingStyle,
            specialRequirements: leafProfile?.specialRequirements ?? rootProfile?.specialRequirements
        )
    }

    /// 主题代理 key — 对齐 cnMarket.ts:34-36 themeAgentKeyForSelection
    static func themeAgentKeyForSelection(root: TaxonomyNode) -> String {
        return facetTextForSelection(root: root, leaf: nil, key: "theme_agent_key")
    }

    // MARK: - 搜索扁平化（对齐 cnMarket.ts:43-54 flattenRootsForSearch）

    /// 搜索命中结构
    struct FlatSearchHit {
        let root: TaxonomyNode
        let scoreAid: String
    }

    /// 将 roots 扁平化为搜索索引 — 对齐 cnMarket.ts:43-54 flattenRootsForSearch
    static func flattenRootsForSearch(roots: [TaxonomyNode]) -> [FlatSearchHit] {
        var out: [FlatSearchHit] = []
        for root in roots {
            let major = pickLocaleLabel(root)
            let profile = writingProfileForSelection(root: root, leaf: nil)
            let blob = "\(major) \(facetTextForSelection(root: root, leaf: nil, key: "search_blob")) \(facetTextForSelection(root: root, leaf: nil, key: "market_track")) \(profile.storyStructure ?? "") \(profile.pacingControl ?? "") \(profile.writingStyle ?? "") \(profile.specialRequirements ?? "")"
            let childLabels = root.children?.map { pickLocaleLabel($0) }.joined(separator: " ") ?? ""
            out.append(FlatSearchHit(root: root, scoreAid: "\(blob) \(childLabels)".lowercased()))
        }
        return out
    }
}
