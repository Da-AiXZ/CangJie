//
//  StatsModels.swift
//  Cangjie
//
//  写作统计模型，字段对齐后端 interfaces/api/stats/models/stats_models.py。
//  以及 interfaces/api/stats/models/responses.py 的 SuccessResponse 封装。
//

import Foundation

// MARK: - 统一响应封装

/// 后端统计 API 的统一响应封装 SuccessResponse<T>
struct StatsSuccessResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? true
        self.data = try c.decode(T.self, forKey: .data)
        self.message = try c.decodeIfPresent(String.self, forKey: .message)
    }
}

// MARK: - 全局统计

/// 全局统计，对应后端 GlobalStats
struct GlobalStats: Codable, Equatable {
    let totalBooks: Int
    let totalChapters: Int
    let totalWords: Int
    let totalCharacters: Int
    let booksByStage: [String: Int]

    enum CodingKeys: String, CodingKey {
        case totalBooks = "total_books"
        case totalChapters = "total_chapters"
        case totalWords = "total_words"
        case totalCharacters = "total_characters"
        case booksByStage = "books_by_stage"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.totalBooks = try c.decodeIfPresent(Int.self, forKey: .totalBooks) ?? 0
        self.totalChapters = try c.decodeIfPresent(Int.self, forKey: .totalChapters) ?? 0
        self.totalWords = try c.decodeIfPresent(Int.self, forKey: .totalWords) ?? 0
        self.totalCharacters = try c.decodeIfPresent(Int.self, forKey: .totalCharacters) ?? 0
        self.booksByStage = try c.decodeIfPresent([String: Int].self, forKey: .booksByStage) ?? [:]
    }
}

// MARK: - 书籍统计

/// 书籍统计，对应后端 BookStats
struct BookStats: Codable, Equatable {
    let slug: String
    let title: String
    let totalChapters: Int
    let completedChapters: Int
    let totalWords: Int
    let avgChapterWords: Double
    let completionRate: Double
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case slug, title
        case totalChapters = "total_chapters"
        case completedChapters = "completed_chapters"
        case totalWords = "total_words"
        case avgChapterWords = "avg_chapter_words"
        case completionRate = "completion_rate"
        case lastUpdated = "last_updated"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.slug = try c.decodeIfPresent(String.self, forKey: .slug) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.totalChapters = try c.decodeIfPresent(Int.self, forKey: .totalChapters) ?? 0
        self.completedChapters = try c.decodeIfPresent(Int.self, forKey: .completedChapters) ?? 0
        self.totalWords = try c.decodeIfPresent(Int.self, forKey: .totalWords) ?? 0
        self.avgChapterWords = try c.decodeIfPresent(Double.self, forKey: .avgChapterWords) ?? 0.0
        self.completionRate = try c.decodeIfPresent(Double.self, forKey: .completionRate) ?? 0.0
        self.lastUpdated = try c.decodeIfPresent(String.self, forKey: .lastUpdated)
    }
}

// MARK: - 章节统计

/// 章节统计，对应后端 ChapterStats
struct ChapterStats: Codable, Equatable {
    let chapterId: Int
    let title: String
    let wordCount: Int
    let characterCount: Int
    let paragraphCount: Int
    let hasContent: Bool

    enum CodingKeys: String, CodingKey {
        case chapterId = "chapter_id"
        case title
        case wordCount = "word_count"
        case characterCount = "character_count"
        case paragraphCount = "paragraph_count"
        case hasContent = "has_content"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterId = try c.decodeIfPresent(Int.self, forKey: .chapterId) ?? 0
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        self.characterCount = try c.decodeIfPresent(Int.self, forKey: .characterCount) ?? 0
        self.paragraphCount = try c.decodeIfPresent(Int.self, forKey: .paragraphCount) ?? 0
        self.hasContent = try c.decodeIfPresent(Bool.self, forKey: .hasContent) ?? false
    }
}

// MARK: - 写作进度

/// 每日写作进度，对应后端 WritingProgress
struct WritingProgress: Codable, Equatable {
    let date: String
    let wordsWritten: Int
    let chaptersCompleted: Int

    enum CodingKeys: String, CodingKey {
        case date
        case wordsWritten = "words_written"
        case chaptersCompleted = "chapters_completed"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        self.wordsWritten = try c.decodeIfPresent(Int.self, forKey: .wordsWritten) ?? 0
        self.chaptersCompleted = try c.decodeIfPresent(Int.self, forKey: .chaptersCompleted) ?? 0
    }
}

// MARK: - 统计查询参数

/// 统计查询参数
struct StatsQuery {
    let slug: String?
    let days: Int

    init(slug: String? = nil, days: Int = 30) {
        self.slug = slug
        self.days = days
    }
}
