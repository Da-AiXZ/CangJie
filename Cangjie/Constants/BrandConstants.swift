//
//  BrandConstants.swift
//  Cangjie
//
//  品牌常量，对齐原版 constants/brand.ts BRAND + BRAND_COPY。
//  A-5：BrandFooterView 引用。
//

import Foundation

// MARK: - 品牌常量

/// 品牌常量，对齐原版 constants/brand.ts BRAND。
struct Brand {
    /// 产品名 — brand.ts:2
    static let productName = "PlotPilot"

    /// 中文名 — brand.ts:3
    static let chineseName = "墨枢"

    /// 显示名 — brand.ts:4
    static let displayName = "PlotPilot · 墨枢"

    /// 标语 — brand.ts:5
    static let tagline = "作者的领航员"

    /// 描述 — brand.ts:6
    static let descriptor = "AI 小说创作平台"

    /// 团队 — brand.ts:7
    static let team = "PlotPilot（墨枢）团队"

    /// 致谢 — brand.ts:8
    static let credit = "由 PlotPilot（墨枢）团队倾力开发"

    /// 抖音标签 — brand.ts:9
    static let douyinLabel = "抖音：林亦 91472902104"

    /// 抖音链接 — brand.ts:10
    static let douyinUrl = "https://www.douyin.com/user/MS4wLjABAAAA91472902104"

    /// 直播时间 — brand.ts:11
    static let liveSchedule = "每晚 9 点随缘直播"
}

// MARK: - 品牌文案组合

/// 品牌文案组合，对齐原版 constants/brand.ts BRAND_COPY。
struct BrandCopy {
    /// 简短 — brand.ts:15
    static let short = Brand.displayName

    /// 紧凑 — brand.ts:16
    static let compact = "\(Brand.chineseName) · \(Brand.tagline)"

    /// 完整 — brand.ts:17
    static let full = "\(Brand.displayName)｜\(Brand.credit)"

    /// 社交 — brand.ts:18
    static let social = "\(Brand.douyinLabel)｜\(Brand.liveSchedule)"
}
