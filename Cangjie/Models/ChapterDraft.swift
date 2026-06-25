//
//  ChapterDraft.swift
//  Cangjie
//
//  幕规划章节草稿模型，对齐原版 ActPlanningModal.vue:163-168 `ChapterDraft`。
//

import Foundation

// MARK: - 章节草稿 — ActPlanningModal.vue:163-168

/// 幕规划章节草稿，对应原版 ActPlanningModal.vue:163-168 `ChapterDraft`
struct ChapterDraft: Codable, Identifiable, Equatable {
    var id: String { title + outline }
    var title: String
    var outline: String
    var bibleElements: [String]

    enum CodingKeys: String, CodingKey {
        case title, outline
        case bibleElements = "bible_elements"
    }

    init(title: String = "", outline: String = "", bibleElements: [String] = []) {
        self.title = title
        self.outline = outline
        self.bibleElements = bibleElements
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.outline = try c.decodeIfPresent(String.self, forKey: .outline) ?? ""
        self.bibleElements = try c.decodeIfPresent([String].self, forKey: .bibleElements) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(outline, forKey: .outline)
        try c.encode(bibleElements, forKey: .bibleElements)
    }
}

// MARK: - 确认幕章节请求 — planning.ts:563-567

/// 确认幕章节请求，对应原版 planning.ts:563-567 `confirmActChapters`
struct ConfirmActChaptersRequest: Codable {
    let chapters: [ChapterDraft]
}

// MARK: - 确认幕章节响应 — planning.ts:565-567

/// 确认幕章节响应
struct ConfirmActChaptersResponse: Codable {
    let success: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success, message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? true
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
    }

    init(success: Bool? = true, message: String? = "") {
        self.success = success
        self.message = message
    }
}
