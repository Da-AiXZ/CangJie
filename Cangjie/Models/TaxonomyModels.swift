//
//  TaxonomyModels.swift
//  Cangjie
//
//  题材包模型，对齐原版 builtin_cn_v1.bundle.json + cnMarket.ts:1-54。
//  机制4：每个模型标注原版文件+行号。
//

import Foundation

// MARK: - 题材包模型（builtin_cn_v1.bundle.json:1-16, cnMarket.ts:12-36）

/// 题材包 — builtin_cn_v1.bundle.json:1-16
struct TaxonomyBundle: Codable, Equatable {
    let schemaKind: String
    let schemaVersion: String
    let id: String
    let locale: String
    let domain: String
    let title: String
    let description: String
    let facetKeysSemantics: [String: AnyCodable]
    let roots: [TaxonomyNode]

    enum CodingKeys: String, CodingKey {
        case schemaKind = "schema_kind"
        case schemaVersion = "schema_version"
        case id, locale, domain, title, description
        case facetKeysSemantics = "facet_keys_semantics"
        case roots
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaKind = try c.decodeIfPresent(String.self, forKey: .schemaKind) ?? ""
        self.schemaVersion = try c.decodeIfPresent(String.self, forKey: .schemaVersion) ?? ""
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.locale = try c.decodeIfPresent(String.self, forKey: .locale) ?? ""
        self.domain = try c.decodeIfPresent(String.self, forKey: .domain) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.facetKeysSemantics = try c.decodeIfPresent([String: AnyCodable].self, forKey: .facetKeysSemantics) ?? [:]
        self.roots = try c.decodeIfPresent([TaxonomyNode].self, forKey: .roots) ?? []
    }
}

/// 题材节点 — builtin_cn_v1.bundle.json:17-33
struct TaxonomyNode: Codable, Identifiable, Equatable {
    let id: String
    let labels: [String: String]
    let facets: TaxonomyFacets?
    let children: [TaxonomyNode]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        self.facets = try c.decodeIfPresent(TaxonomyFacets.self, forKey: .facets)
        self.children = try c.decodeIfPresent([TaxonomyNode].self, forKey: .children)
    }
}

/// 题材 facet — cnMarket.ts:12-36
struct TaxonomyFacets: Codable, Equatable {
    let marketTrack: String?
    let worldTone: String?
    let writingProfile: TaxonomyWritingProfile?
    let themeAgentKey: String?
    let searchBlob: String?

    enum CodingKeys: String, CodingKey {
        case marketTrack = "market_track"
        case worldTone = "world_tone"
        case writingProfile = "writing_profile"
        case themeAgentKey = "theme_agent_key"
        case searchBlob = "search_blob"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.marketTrack = try c.decodeIfPresent(String.self, forKey: .marketTrack)
        self.worldTone = try c.decodeIfPresent(String.self, forKey: .worldTone)
        self.writingProfile = try c.decodeIfPresent(TaxonomyWritingProfile.self, forKey: .writingProfile)
        self.themeAgentKey = try c.decodeIfPresent(String.self, forKey: .themeAgentKey)
        self.searchBlob = try c.decodeIfPresent(String.self, forKey: .searchBlob)
    }
}

/// 写作原则 — cnMarket.ts:22-28
struct TaxonomyWritingProfile: Codable, Equatable {
    let storyStructure: String?
    let pacingControl: String?
    let writingStyle: String?
    let specialRequirements: String?

    enum CodingKeys: String, CodingKey {
        case storyStructure = "story_structure"
        case pacingControl = "pacing_control"
        case writingStyle = "writing_style"
        case specialRequirements = "special_requirements"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.storyStructure = try c.decodeIfPresent(String.self, forKey: .storyStructure)
        self.pacingControl = try c.decodeIfPresent(String.self, forKey: .pacingControl)
        self.writingStyle = try c.decodeIfPresent(String.self, forKey: .writingStyle)
        self.specialRequirements = try c.decodeIfPresent(String.self, forKey: .specialRequirements)
    }
}
