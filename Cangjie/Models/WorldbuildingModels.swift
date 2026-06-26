//
//  WorldbuildingModels.swift
//  Cangjie
//
//  世界观模型，字段对齐原版 api/worldbuilding.ts:3-46。
//  Worldbuilding + CoreRules + Geography + Society + Culture + DailyLife。
//

import Foundation

// MARK: - 核心规则

/// 核心规则，对应原版 worldbuilding.ts:3-7 CoreRules
struct CoreRules: Codable, Equatable {
    let powerSystem: String
    let physicsRules: String
    let magicTech: String

    enum CodingKeys: String, CodingKey {
        case powerSystem = "power_system"
        case physicsRules = "physics_rules"
        case magicTech = "magic_tech"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.powerSystem = try c.decodeIfPresent(String.self, forKey: .powerSystem) ?? ""
        self.physicsRules = try c.decodeIfPresent(String.self, forKey: .physicsRules) ?? ""
        self.magicTech = try c.decodeIfPresent(String.self, forKey: .magicTech) ?? ""
    }

    init(powerSystem: String = "", physicsRules: String = "", magicTech: String = "") {
        self.powerSystem = powerSystem
        self.physicsRules = physicsRules
        self.magicTech = magicTech
    }
}

// MARK: - 地理

/// 地理，对应原版 worldbuilding.ts:9-14 Geography
struct Geography: Codable, Equatable {
    let terrain: String
    let climate: String
    let resources: String
    let ecology: String

    enum CodingKeys: String, CodingKey {
        case terrain, climate, resources, ecology
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.terrain = try c.decodeIfPresent(String.self, forKey: .terrain) ?? ""
        self.climate = try c.decodeIfPresent(String.self, forKey: .climate) ?? ""
        self.resources = try c.decodeIfPresent(String.self, forKey: .resources) ?? ""
        self.ecology = try c.decodeIfPresent(String.self, forKey: .ecology) ?? ""
    }

    init(terrain: String = "", climate: String = "", resources: String = "", ecology: String = "") {
        self.terrain = terrain
        self.climate = climate
        self.resources = resources
        self.ecology = ecology
    }
}

// MARK: - 社会

/// 社会，对应原版 worldbuilding.ts:16-20 Society
struct Society: Codable, Equatable {
    let politics: String
    let economy: String
    let classSystem: String

    enum CodingKeys: String, CodingKey {
        case politics, economy
        case classSystem = "class_system"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.politics = try c.decodeIfPresent(String.self, forKey: .politics) ?? ""
        self.economy = try c.decodeIfPresent(String.self, forKey: .economy) ?? ""
        self.classSystem = try c.decodeIfPresent(String.self, forKey: .classSystem) ?? ""
    }

    init(politics: String = "", economy: String = "", classSystem: String = "") {
        self.politics = politics
        self.economy = economy
        self.classSystem = classSystem
    }
}

// MARK: - 文化

/// 文化，对应原版 worldbuilding.ts:22-26 Culture
struct Culture: Codable, Equatable {
    let history: String
    let religion: String
    let taboos: String

    enum CodingKeys: String, CodingKey {
        case history, religion, taboos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.history = try c.decodeIfPresent(String.self, forKey: .history) ?? ""
        self.religion = try c.decodeIfPresent(String.self, forKey: .religion) ?? ""
        self.taboos = try c.decodeIfPresent(String.self, forKey: .taboos) ?? ""
    }

    init(history: String = "", religion: String = "", taboos: String = "") {
        self.history = history
        self.religion = religion
        self.taboos = taboos
    }
}

// MARK: - 日常生活

/// 日常生活，对应原版 worldbuilding.ts:28-32 DailyLife
struct DailyLife: Codable, Equatable {
    let foodClothing: String
    let languageSlang: String
    let entertainment: String

    enum CodingKeys: String, CodingKey {
        case foodClothing = "food_clothing"
        case languageSlang = "language_slang"
        case entertainment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.foodClothing = try c.decodeIfPresent(String.self, forKey: .foodClothing) ?? ""
        self.languageSlang = try c.decodeIfPresent(String.self, forKey: .languageSlang) ?? ""
        self.entertainment = try c.decodeIfPresent(String.self, forKey: .entertainment) ?? ""
    }

    init(foodClothing: String = "", languageSlang: String = "", entertainment: String = "") {
        self.foodClothing = foodClothing
        self.languageSlang = languageSlang
        self.entertainment = entertainment
    }
}

// MARK: - 世界观

/// 世界观，对应原版 worldbuilding.ts:34-46 Worldbuilding
struct Worldbuilding: Codable, Identifiable, Equatable {
    let id: String
    let novelId: String
    let schemaVersion: Int?
    let dimensions: [String: [String: String]]?
    let coreRules: CoreRules
    let geography: Geography
    let society: Society
    let culture: Culture
    let dailyLife: DailyLife
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case schemaVersion = "schema_version"
        case dimensions
        case coreRules = "core_rules"
        case geography
        case society
        case culture
        case dailyLife = "daily_life"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion)
        self.dimensions = try c.decodeIfPresent([String: [String: String]].self, forKey: .dimensions)
        self.coreRules = try c.decodeIfPresent(CoreRules.self, forKey: .coreRules) ?? CoreRules()
        self.geography = try c.decodeIfPresent(Geography.self, forKey: .geography) ?? Geography()
        self.society = try c.decodeIfPresent(Society.self, forKey: .society) ?? Society()
        self.culture = try c.decodeIfPresent(Culture.self, forKey: .culture) ?? Culture()
        self.dailyLife = try c.decodeIfPresent(DailyLife.self, forKey: .dailyLife) ?? DailyLife()
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }

    init(
        id: String = "",
        novelId: String = "",
        schemaVersion: Int? = nil,
        dimensions: [String: [String: String]]? = nil,
        coreRules: CoreRules = CoreRules(),
        geography: Geography = Geography(),
        society: Society = Society(),
        culture: Culture = Culture(),
        dailyLife: DailyLife = DailyLife(),
        createdAt: String = "",
        updatedAt: String = ""
    ) {
        self.id = id
        self.novelId = novelId
        self.schemaVersion = schemaVersion
        self.dimensions = dimensions
        self.coreRules = coreRules
        self.geography = geography
        self.society = society
        self.culture = culture
        self.dailyLife = dailyLife
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
