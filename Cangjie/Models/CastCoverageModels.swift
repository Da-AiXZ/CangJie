//
//  CastCoverageModels.swift
//  Cangjie
//
//  Cast 覆盖分析结构化模型，字段对齐原版 api/cast.ts:51-69。
//  C-2：将 CastCoverage.bibleNotInCast/quotedNotInCast 从 AnyCodable 结构化。
//  CharacterCoverage 已在 CastModels.swift 中定义，此处补充 BibleCharacter / QuotedText。
//

import Foundation

// MARK: - 圣典角色（覆盖分析）

/// 圣典角色覆盖项，对齐原版 api/cast.ts:51-56 BibleCharacter。
///
/// 用于 CastCoverage.bibleNotInCast：出现在 Bible 但未出现在正文中的角色。
struct CastBibleCharacter: Codable, Equatable {

    /// 角色名
    let name: String

    /// 角色定位
    let role: String

    /// 是否出现在小说正文中
    let inNovelText: Bool

    /// 出现的章节 ID 列表
    let chapterIds: [Int]

    enum CodingKeys: String, CodingKey {
        case name, role
        case inNovelText = "in_novel_text"
        case chapterIds = "chapter_ids"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        self.inNovelText = try c.decodeIfPresent(Bool.self, forKey: .inNovelText) ?? false
        self.chapterIds = try c.decodeIfPresent([Int].self, forKey: .chapterIds) ?? []
    }

    init(name: String, role: String, inNovelText: Bool, chapterIds: [Int]) {
        self.name = name
        self.role = role
        self.inNovelText = inNovelText
        self.chapterIds = chapterIds
    }
}

// MARK: - 引用文本（覆盖分析）

/// 引用文本覆盖项，对齐原版 api/cast.ts:58-62 QuotedText。
///
/// 用于 CastCoverage.quotedNotInCast：正文出现但未在 Bible 注册的引用文本。
struct CastQuotedText: Codable, Equatable {

    /// 引用文本内容
    let text: String

    /// 出现次数
    let count: Int

    /// 出现的章节 ID 列表
    let chapterIds: [Int]

    enum CodingKeys: String, CodingKey {
        case text, count
        case chapterIds = "chapter_ids"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
        self.chapterIds = try c.decodeIfPresent([Int].self, forKey: .chapterIds) ?? []
    }

    init(text: String, count: Int, chapterIds: [Int]) {
        self.text = text
        self.count = count
        self.chapterIds = chapterIds
    }
}
