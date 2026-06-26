//
//  StructureModels.swift
//  Cangjie
//
//  故事结构模型，字段对齐后端 interfaces/api/v1/blueprint/story_structure.py 的请求模型。
//  以及 application/blueprint/services/story_structure_service.py 的返回结构。
//

import Foundation

// MARK: - 结构节点类型

/// 结构节点类型
enum StructureNodeType: String, Codable, CaseIterable {
    case part
    case volume
    case act
    case chapter

    var displayName: String {
        switch self {
        case .part: return "部"
        case .volume: return "卷"
        case .act: return "幕"
        case .chapter: return "章"
        }
    }
}

// MARK: - 结构节点

/// 故事结构节点
/// 字段对齐原版 structure.ts:9-30 StoryNode（21 字段 = 原 12 + 新增 9）
struct StoryNode: Codable, Identifiable, Equatable {
    let id: String
    let novelId: String
    let nodeType: String
    let number: Int
    let title: String
    let description: String?
    let parentId: String?
    let orderIndex: Int?
    let chapterRange: String?
    let chapterStart: Int?
    let chapterEnd: Int?
    let children: [StoryNode]?
    // P0-9.6 新增 9 字段（对齐 structure.ts:20-28）
    let chapterCount: Int?
    let metadata: AnyCodable?
    let createdAt: String?
    let updatedAt: String?
    let level: Int?
    let icon: String?
    let displayName: String?
    let wordCount: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case nodeType = "node_type"
        case number, title, description
        case parentId = "parent_id"
        case orderIndex = "order_index"
        case chapterRange = "chapter_range"
        case chapterStart = "chapter_start"
        case chapterEnd = "chapter_end"
        case children
        // P0-9.6 新增 CodingKeys
        case chapterCount = "chapter_count"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case level
        case icon
        case displayName = "display_name"
        case wordCount = "word_count"
        case status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .nodeType) ?? "act"
        self.number = try c.decodeIfPresent(Int.self, forKey: .number) ?? 0
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        self.orderIndex = try c.decodeIfPresent(Int.self, forKey: .orderIndex)
        self.chapterRange = try c.decodeIfPresent(String.self, forKey: .chapterRange)
        self.chapterStart = try c.decodeIfPresent(Int.self, forKey: .chapterStart)
        self.chapterEnd = try c.decodeIfPresent(Int.self, forKey: .chapterEnd)
        self.children = try c.decodeIfPresent([StoryNode].self, forKey: .children)
        // P0-9.6 新增字段解码
        self.chapterCount = try c.decodeIfPresent(Int.self, forKey: .chapterCount)
        self.metadata = try c.decodeIfPresent(AnyCodable.self, forKey: .metadata)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        self.level = try c.decodeIfPresent(Int.self, forKey: .level)
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
    }
}

// MARK: - 结构树

/// 故事结构树
struct StoryStructureTree: Codable, Equatable {
    let novelId: String
    let nodes: [StoryNode]

    enum CodingKeys: String, CodingKey {
        case nodes
        case novelId = "novel_id"
    }

    init(from decoder: Decoder) throws {
        // 后端返回可能是数组（节点列表）或字典（含 novel_id + nodes）
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            self.novelId = dict["novel_id"]?.stringStringValue ?? ""
            let nodesData = try JSONSerialization.data(withJSONObject: dict["nodes"]?.value ?? [])
            self.nodes = (try? CangjieDecoder.shared.decode([StoryNode].self, from: nodesData)) ?? []
        } else if let nodesArray = try? container.decode([StoryNode].self) {
            self.novelId = ""
            self.nodes = nodesArray
        } else {
            self.novelId = ""
            self.nodes = []
        }
    }
}

// MARK: - 创建节点请求

/// 创建节点请求，对应后端 CreateNodeRequest
struct CreateNodeRequest: Codable {
    let nodeType: String
    let number: Int
    let title: String
    let parentId: String?
    let description: String?
    let orderIndex: Int?

    enum CodingKeys: String, CodingKey {
        case nodeType = "node_type"
        case number, title
        case parentId = "parent_id"
        case description
        case orderIndex = "order_index"
    }
}

// MARK: - 更新节点请求

/// 更新节点请求，对应后端 UpdateNodeRequest
struct UpdateNodeRequest: Codable {
    let title: String?
    let description: String?
    let number: Int?
}

// MARK: - 重排序请求

/// 重排序请求，对应后端 ReorderRequest
struct ReorderRequest: Codable {
    let nodeIds: [String]

    enum CodingKeys: String, CodingKey {
        case nodeIds = "node_ids"
    }
}

// MARK: - 宏观规划 SSE 事件

/// 宏观规划 SSE 事件类型
enum MacroPlanEventType: String, Codable {
    case status
    case chunk
    case node
    case done
    case error
}

/// 宏观规划 SSE 事件
struct MacroPlanEvent: Codable, Equatable {
    let type: String
    let phase: String?
    let message: String?
    let current: Int?
    let total: Int?
    let percent: Double?
    let text: String?
    let nodeType: String?
    let partIndex: Int?
    let volumeIndex: Int?
    let actIndex: Int?
    let title: String?
    let description: String?
    let estimatedChapters: Int?
    let structure: [AnyCodable]?
    let qualityMetrics: AnyCodable?
    let generationTime: Double?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case type, phase, message, current, total, percent, text, title, description, error
        case partIndex = "part_index"
        case volumeIndex = "volume_index"
        case actIndex = "act_index"
        case estimatedChapters = "estimated_chapters"
        case structure
        case qualityMetrics = "quality_metrics"
        case generationTime = "generation_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // type 字段优先从顶层取，node 事件的 type 是节点类型（part/volume/act）
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.phase = try c.decodeIfPresent(String.self, forKey: .phase)
        self.message = try c.decodeIfPresent(String.self, forKey: .message)
        self.current = try c.decodeIfPresent(Int.self, forKey: .current)
        self.total = try c.decodeIfPresent(Int.self, forKey: .total)
        self.percent = try c.decodeIfPresent(Double.self, forKey: .percent)
        self.text = try c.decodeIfPresent(String.self, forKey: .text)
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .type)
        self.partIndex = try c.decodeIfPresent(Int.self, forKey: .partIndex)
        self.volumeIndex = try c.decodeIfPresent(Int.self, forKey: .volumeIndex)
        self.actIndex = try c.decodeIfPresent(Int.self, forKey: .actIndex)
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.estimatedChapters = try c.decodeIfPresent(Int.self, forKey: .estimatedChapters)
        self.structure = try c.decodeIfPresent([AnyCodable].self, forKey: .structure)
        self.qualityMetrics = try c.decodeIfPresent(AnyCodable.self, forKey: .qualityMetrics)
        self.generationTime = try c.decodeIfPresent(Double.self, forKey: .generationTime)
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
    }

    /// 便利构造器（用于代码内构造进度事件）
    init(type: String, message: String? = nil, percent: Double? = nil,
         structure: [AnyCodable]? = nil, error: String? = nil) {
        self.type = type
        self.phase = nil
        self.message = message
        self.current = nil
        self.total = nil
        self.percent = percent
        self.text = nil
        self.nodeType = nil
        self.partIndex = nil
        self.volumeIndex = nil
        self.actIndex = nil
        self.title = nil
        self.description = nil
        self.estimatedChapters = nil
        self.structure = structure
        self.qualityMetrics = nil
        self.generationTime = nil
        self.error = error
    }
}

// MARK: - 宏观规划请求

/// 宏观规划请求，对应后端 MacroPlanRequest
struct MacroPlanRequest: Codable {
    let targetChapters: Int
    let structure: StructurePreference

    enum CodingKeys: String, CodingKey {
        case targetChapters = "target_chapters"
        case structure
    }
}

/// 结构偏好，对应后端 StructurePreference
struct StructurePreference: Codable {
    let parts: Int
    let volumesPerPart: Int
    let actsPerVolume: Int

    enum CodingKeys: String, CodingKey {
        case parts
        case volumesPerPart = "volumes_per_part"
        case actsPerVolume = "acts_per_volume"
    }
}

/// 宏观规划确认请求
struct MacroPlanConfirmRequest: Codable {
    let structure: [AnyCodable]

    enum CodingKeys: String, CodingKey {
        case structure
    }
}
