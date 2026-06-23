//
//  ChronicleModels.swift
//  Cangjie
//
//  编年史模型，字段对齐后端 interfaces/api/v1/engine/chronicles.py 的 Pydantic 模型。
//

import Foundation

// MARK: - 故事事件项

/// 故事事件项，对应后端 StoryEventItem
struct ChronicleStoryEvent: Codable, Identifiable, Equatable {
    var id: String { noteId }
    let noteId: String
    let time: String
    let title: String
    let description: String
    let sourceChapter: Int?

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
        case time, title, description
        case sourceChapter = "source_chapter"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.noteId = try c.decodeIfPresent(String.self, forKey: .noteId) ?? ""
        self.time = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.sourceChapter = try c.decodeIfPresent(Int.self, forKey: .sourceChapter)
    }
}

// MARK: - 快照项

/// 快照项，对应后端 SnapshotItem
struct ChronicleSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let kind: String
    let name: String
    let branchName: String
    let createdAt: String?
    let description: String?
    let anchorChapter: Int?

    enum CodingKeys: String, CodingKey {
        case id, kind, name
        case branchName = "branch_name"
        case createdAt = "created_at"
        case description
        case anchorChapter = "anchor_chapter"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "AUTO"
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.branchName = try c.decodeIfPresent(String.self, forKey: .branchName) ?? "main"
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.anchorChapter = try c.decodeIfPresent(Int.self, forKey: .anchorChapter)
    }
}

// MARK: - 编年史行

/// 编年史行，对应后端 ChronicleRow
struct ChronicleRow: Codable, Identifiable, Equatable {
    var id: Int { chapterIndex }
    let chapterIndex: Int
    let storyEvents: [ChronicleStoryEvent]
    let snapshots: [ChronicleSnapshot]

    enum CodingKeys: String, CodingKey {
        case chapterIndex = "chapter_index"
        case storyEvents = "story_events"
        case snapshots
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterIndex = try c.decodeIfPresent(Int.self, forKey: .chapterIndex) ?? 0
        self.storyEvents = try c.decodeIfPresent([ChronicleStoryEvent].self, forKey: .storyEvents) ?? []
        self.snapshots = try c.decodeIfPresent([ChronicleSnapshot].self, forKey: .snapshots) ?? []
    }
}

// MARK: - 编年史响应

/// 编年史响应，对应后端 ChroniclesResponse
struct ChroniclesResponse: Codable, Equatable {
    let rows: [ChronicleRow]
    let maxChapterInBook: Int
    let note: String?

    enum CodingKeys: String, CodingKey {
        case rows, note
        case maxChapterInBook = "max_chapter_in_book"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rows = try c.decodeIfPresent([ChronicleRow].self, forKey: .rows) ?? []
        self.maxChapterInBook = try c.decodeIfPresent(Int.self, forKey: .maxChapterInBook) ?? 0
        self.note = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

// MARK: - 编年史轨道

/// 编年史轨道（按章节聚合的展示结构）
struct ChronicleTrack: Equatable {
    let rows: [ChronicleRow]
    let maxChapter: Int
}
