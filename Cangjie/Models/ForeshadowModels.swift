//
//  ForeshadowModels.swift
//  Cangjie
//
//  伏笔手账模型，字段对齐后端 interfaces/api/v1/analyst/foreshadow_ledger.py 的请求/响应模型。
//

import Foundation

// MARK: - 伏笔条目

/// 伏笔条目响应，对应后端 SubtextEntryResponse
struct ForeshadowEntry: Codable, Identifiable, Equatable {
    let id: String
    let chapter: Int
    let characterId: String
    let question: String
    let status: String
    let consumedAtChapter: Int?
    let suggestedResolveChapter: Int?
    let resolveChapterWindow: Int?
    let importance: String
    let isPriorityForChapter: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, chapter, question, status, importance
        case characterId = "character_id"
        case consumedAtChapter = "consumed_at_chapter"
        case suggestedResolveChapter = "suggested_resolve_chapter"
        case resolveChapterWindow = "resolve_chapter_window"
        case isPriorityForChapter = "is_priority_for_chapter"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.chapter = try c.decodeIfPresent(Int.self, forKey: .chapter) ?? 0
        self.characterId = try c.decodeIfPresent(String.self, forKey: .characterId) ?? ""
        self.question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        self.consumedAtChapter = try c.decodeIfPresent(Int.self, forKey: .consumedAtChapter)
        self.suggestedResolveChapter = try c.decodeIfPresent(Int.self, forKey: .suggestedResolveChapter)
        self.resolveChapterWindow = try c.decodeIfPresent(Int.self, forKey: .resolveChapterWindow)
        self.importance = try c.decodeIfPresent(String.self, forKey: .importance) ?? "medium"
        self.isPriorityForChapter = try c.decodeIfPresent(Bool.self, forKey: .isPriorityForChapter) ?? false
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

// MARK: - 创建伏笔请求

/// 创建伏笔请求，对应后端 CreateSubtextEntryRequest
struct CreateForeshadowRequest: Codable {
    let entryId: String
    let chapter: Int
    let characterId: String
    let question: String

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case chapter
        case characterId = "character_id"
        case question
    }
}

// MARK: - 更新伏笔请求

/// 更新伏笔请求，对应后端 UpdateSubtextEntryRequest
struct UpdateForeshadowRequest: Codable {
    let chapter: Int?
    let characterId: String?
    let question: String?
    let status: String?
    let consumedAtChapter: Int?
    let isPriorityForChapter: Bool?

    enum CodingKeys: String, CodingKey {
        case chapter, question, status
        case characterId = "character_id"
        case consumedAtChapter = "consumed_at_chapter"
        case isPriorityForChapter = "is_priority_for_chapter"
    }
}
