//
//  ChapterElementModels.swift
//  Cangjie
//
//  章节元素模型，对齐原版 chapterElement.ts:1-75。
//  机制4：每个模型标注原版文件+行号。
//

import Foundation

// MARK: - 枚举（chapterElement.ts:10-12）

/// 元素类型 — chapterElement.ts:10
enum ElementType: String, Codable, CaseIterable {
    case character
    case location
    case item
    case organization
    case event
}

/// 关系类型 — chapterElement.ts:11
enum RelationType: String, Codable, CaseIterable {
    case appears
    case mentioned
    case scene
    case uses
    case involved
    case occurs
}

/// 重要度 — chapterElement.ts:12
enum Importance: String, Codable, CaseIterable {
    case major
    case normal
    case minor
}

// MARK: - DTO（chapterElement.ts:14-33）

/// 章节元素 DTO — chapterElement.ts:14-24
struct ChapterElementDTO: Codable, Identifiable, Equatable {
    let id: String
    let chapterId: String
    let elementType: String
    let elementId: String
    let relationType: String
    let importance: String
    let appearanceOrder: Int?
    let notes: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case chapterId = "chapter_id"
        case elementType = "element_type"
        case elementId = "element_id"
        case relationType = "relation_type"
        case importance
        case appearanceOrder = "appearance_order"
        case notes
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.chapterId = try c.decodeIfPresent(String.self, forKey: .chapterId) ?? ""
        self.elementType = try c.decodeIfPresent(String.self, forKey: .elementType) ?? ""
        self.elementId = try c.decodeIfPresent(String.self, forKey: .elementId) ?? ""
        self.relationType = try c.decodeIfPresent(String.self, forKey: .relationType) ?? ""
        self.importance = try c.decodeIfPresent(String.self, forKey: .importance) ?? "normal"
        self.appearanceOrder = try c.decodeIfPresent(Int.self, forKey: .appearanceOrder)
        self.notes = try c.decodeIfPresent(String.self, forKey: .notes)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

/// 创建章节元素请求 — chapterElement.ts:26-33
struct ChapterElementCreate: Codable {
    let elementType: String
    let elementId: String
    let relationType: String
    var importance: String?
    var appearanceOrder: Int?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case elementType = "element_type"
        case elementId = "element_id"
        case relationType = "relation_type"
        case importance
        case appearanceOrder = "appearance_order"
        case notes
    }
}

// MARK: - API 响应封装（chapterElement.ts:38-74）

/// 章节元素列表响应 — chapterElement.ts:38-44
struct ChapterElementListResponse: Codable {
    let success: Bool?
    let data: [ChapterElementDTO]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success)
        self.data = try c.decodeIfPresent([ChapterElementDTO].self, forKey: .data)
    }
}

/// 单个章节元素响应 — chapterElement.ts:46-52
struct ChapterElementSingleResponse: Codable {
    let success: Bool?
    let data: ChapterElementDTO?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success)
        self.data = try c.decodeIfPresent(ChapterElementDTO.self, forKey: .data)
    }
}

/// 批量更新请求 — chapterElement.ts:54-60
struct ChapterElementBatchUpdateRequest: Codable {
    let elements: [ChapterElementCreate]
}

/// 批量更新响应 — chapterElement.ts:54-60
struct ChapterElementBatchUpdateResponse: Codable {
    let success: Bool?
    let data: ChapterElementBatchUpdateData?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success)
        self.data = try c.decodeIfPresent(ChapterElementBatchUpdateData.self, forKey: .data)
    }
}

/// 批量更新数据
struct ChapterElementBatchUpdateData: Codable {
    let updatedCount: Int?
    let elements: [ChapterElementDTO]?

    enum CodingKeys: String, CodingKey {
        case updatedCount = "updated_count"
        case elements
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.updatedCount = try c.decodeIfPresent(Int.self, forKey: .updatedCount)
        self.elements = try c.decodeIfPresent([ChapterElementDTO].self, forKey: .elements)
    }
}

/// 删除响应 — chapterElement.ts:62-66
struct ChapterElementDeleteResponse: Codable {
    let success: Bool?
    let message: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success)
        self.message = try c.decodeIfPresent(String.self, forKey: .message)
    }
}

/// 反查元素出现章节响应 — chapterElement.ts:69-74
struct ChapterElementChaptersResponse: Codable {
    let success: Bool?
    let data: ChapterElementChaptersData?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success)
        self.data = try c.decodeIfPresent(ChapterElementChaptersData.self, forKey: .data)
    }
}

/// 反查元素出现章节数据
struct ChapterElementChaptersData: Codable {
    let appearanceCount: Int?
    let chapters: [AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case appearanceCount = "appearance_count"
        case chapters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.appearanceCount = try c.decodeIfPresent(Int.self, forKey: .appearanceCount)
        self.chapters = try c.decodeIfPresent([AnyCodable].self, forKey: .chapters)
    }
}
