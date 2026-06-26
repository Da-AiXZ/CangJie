//
//  MarketStylePresets.swift
//  Cangjie
//
//  市场向文风公约预设，对齐原版 constants/marketStylePresets.ts。
//  A-7：StylePresetSelectorView 引用 6 预设 + matchPresetValue/getMarketStylePresetIcon。
//

import Foundation

// MARK: - 文风预设

/// 市场向文风公约预设，对齐原版 marketStylePresets.ts:5-12 MarketStylePreset。
struct MarketStylePreset: Identifiable, Equatable {
    /// 唯一 ID（使用 value）
    var id: String { value }

    /// 标签 — marketStylePresets.ts:6
    let label: String

    /// 值 — marketStylePresets.ts:7
    let value: String

    /// 文风公约正文 — marketStylePresets.ts:8
    let body: String

    /// 图标 — marketStylePresets.ts:9
    let icon: String

    /// 别名列表 — marketStylePresets.ts:10
    let aliases: [String]

    /// 关键词列表 — marketStylePresets.ts:11
    let keywords: [String]
}

// MARK: - 预设常量

/// 6 个市场向文风预设，对齐原版 marketStylePresets.ts:48-103 MARKET_STYLE_PRESETS。
let MARKET_STYLE_PRESETS: [MarketStylePreset] = [
    MarketStylePreset(
        label: "修仙·升级打脸",
        value: "xianxia_hot",
        icon: "仙",
        aliases: ["修仙爽文", "修仙", "仙侠", "古典仙侠"],
        keywords: ["仙门", "道统", "因果", "轮回", "修真", "山海", "天道", "古典"],
        body: "【文风公约·修仙爽文】第三人称有限视角；节奏快，章末留钩。冲突外化，升级与打脸交替；系统/机缘仅作推进器，忌说明书式设定堆砌。对话口语化，战斗场面分镜清晰。禁止圣母拖戏、禁止同一信息重复三章。"
    ),
    MarketStylePreset(
        label: "赛博·冷峻群像",
        value: "cyberpunk",
        icon: "械",
        aliases: ["赛博朋克", "赛博", "冷峻群像"],
        keywords: ["巨企", "义体", "信息战", "冷色调", "科技", "道德灰度"],
        body: "【文风公约·赛博朋克】冷色调叙事；巨企、义体、信息战为舞台。短句与名词堆叠营造窒息感，偶用长句收束情绪。科技细节服务情节，不炫技。道德灰度，反派有动机。禁止中二口号滥用。"
    ),
    MarketStylePreset(
        label: "悬疑·线索回收",
        value: "mystery",
        icon: "疑",
        aliases: ["悬疑", "线索回收", "推理"],
        keywords: ["线索", "伏笔", "反转", "调查", "真凶", "信息控制"],
        body: "【文风公约·悬疑】视角控制信息：读者与主角同步知情。伏笔显性埋、合理回收；反转需前文有锚点。节奏张弛：调查—受挫—突破。环境描写参与氛围，不单为写景。禁止机械降神、禁止真凶无铺垫。"
    ),
    MarketStylePreset(
        label: "都市·爽点直给",
        value: "urban_power",
        icon: "都",
        aliases: ["都市爽文", "都市", "爽点直给"],
        keywords: ["强代入", "身份反转", "资源碾压", "职场", "家族线", "反馈"],
        body: "【文风公约·都市爽文】强代入、强反馈；身份反转与资源碾压要\u{201C}事出有因\u{201D}。职场/家族线可并行，主线不漂移。对话带梗但不过密。感情线服务主线时可写，忌喧宾夺主。禁止连续水文复盘。"
    ),
    MarketStylePreset(
        label: "玄幻·热血史诗",
        value: "xuanhuan_epic",
        icon: "玄",
        aliases: ["玄幻", "热血史诗", "史诗"],
        keywords: ["世界观分层", "地图", "势力", "战斗", "成长", "群像", "战力"],
        body: "【文风公约·玄幻】世界观分层展开，地图与势力随剧情解锁。战斗有代价与成长。群像可有配角弧，主角动机始终清晰。辞藻可华丽但句意须清。禁止战力崩坏、禁止无限叠盒子无剧情。"
    ),
    MarketStylePreset(
        label: "言情·甜宠克制",
        value: "romance_sweet",
        icon: "情",
        aliases: ["言情甜宠", "言情", "甜宠"],
        keywords: ["情绪细腻", "误会", "甜", "亲密戏", "恋爱", "双方"],
        body: "【文风公约·言情甜宠】情绪细腻，误会不过三；甜与爽点交替。双方有独立人格与目标，不单为恋爱工具人。亲密戏点到为止、平台合规。禁止为虐而虐、禁止降智推动剧情。"
    ),
]

// MARK: - 辅助函数

/// 标准化文本（去空白），对齐原版 marketStylePresets.ts:14-16 normalizeStyleText
private func normalizeStyleText(_ text: String) -> String {
    return text.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// 提取文风标题，对齐原版 marketStylePresets.ts:18-24 styleHeading
private func styleHeading(_ text: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    // 匹配【文风公约·xxx】
    if let bracketRange = t.range(of: #"^【文风公约[·:：-]?([^】]+)】"#, options: .regularExpression) {
        let match = t[bracketRange]
        // 提取括号内内容
        if let innerStart = match.range(of: "·"),
           let innerEnd = match.range(of: "】") {
            let startIdx = innerStart.upperBound
            let endIdx = innerEnd.lowerBound
            if startIdx < endIdx {
                return String(match[startIdx..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
    return ""
}

/// 计算预设匹配分数，对齐原版 marketStylePresets.ts:26-46 scorePreset
private func scorePreset(styleNotes: String, preset: MarketStylePreset) -> Int {
    let normalized = normalizeStyleText(styleNotes)
    let heading = styleHeading(styleNotes)
    let body = normalizeStyleText(preset.body)
    if normalized.isEmpty { return 0 }
    if normalized == body { return 1000 }
    if normalized.hasPrefix(String(body.prefix(min(body.count, 30)))) { return 900 }

    var score = 0
    let normalizedHeading = normalizeStyleText(heading)
    for alias in preset.aliases {
        let a = normalizeStyleText(alias)
        if a.isEmpty { continue }
        if normalizedHeading.contains(a) { score += 120 }
        if normalized.contains(a) { score += 45 }
    }
    for keyword in preset.keywords {
        let k = normalizeStyleText(keyword)
        if !k.isEmpty && normalized.contains(k) { score += 18 }
    }
    return score
}

/// 匹配预设值，对齐原版 marketStylePresets.ts:105-111 matchPresetValue
/// - Parameter styleNotes: 文风备注文本
/// - Returns: 匹配的预设 value（分数 >= 45），无匹配返回 nil
func matchPresetValue(_ styleNotes: String) -> String? {
    let scored = MARKET_STYLE_PRESETS.map { preset in
        (preset: preset, score: scorePreset(styleNotes: styleNotes, preset: preset))
    }.sorted { $0.score > $1.score }

    guard let best = scored.first, best.score >= 45 else { return nil }
    return best.preset.value
}

/// 获取预设图标，对齐原版 marketStylePresets.ts:113-115 getMarketStylePresetIcon
/// - Parameter value: 预设值
/// - Returns: 图标字符，无匹配返回 "文"
func getMarketStylePresetIcon(_ value: String?) -> String {
    guard let value = value else { return "文" }
    return MARKET_STYLE_PRESETS.first { $0.value == value }?.icon ?? "文"
}
