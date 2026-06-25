//
//  VoiceModels.swift
//  Cangjie
//
//  文风金库数据模型，字段对齐原版 api/voice.ts:7-24 的 TypeScript 接口。
//  后端路由：/api/v1/novels/{novel_id}/voice/...
//

import Foundation

// MARK: - 文风样本提交请求体

/// 文风样本提交请求体，对应原版 voice.ts:7-12 `VoiceSamplePayload`。
///
/// 原版定义：
/// ```typescript
/// interface VoiceSamplePayload {
///   ai_original: string
///   author_refined: string
///   chapter_number: number
///   scene_type?: string
/// }
/// ```
struct VoiceSamplePayload: Codable, Equatable {

    /// AI 原始文本 — voice.ts:8 `ai_original`
    let aiOriginal: String

    /// 作者修改后文本 — voice.ts:9 `author_refined`
    let authorRefined: String

    /// 章节编号 — voice.ts:10 `chapter_number`
    let chapterNumber: Int

    /// 场景类型（可选）— voice.ts:11 `scene_type?`
    let sceneType: String?

    enum CodingKeys: String, CodingKey {
        case aiOriginal = "ai_original"
        case authorRefined = "author_refined"
        case chapterNumber = "chapter_number"
        case sceneType = "scene_type"
    }

    /// 成员初始化器
    /// - Parameters:
    ///   - aiOriginal: AI 原始文本
    ///   - authorRefined: 作者修改后文本
    ///   - chapterNumber: 章节编号
    ///   - sceneType: 场景类型（可选）
    init(aiOriginal: String, authorRefined: String, chapterNumber: Int, sceneType: String? = nil) {
        self.aiOriginal = aiOriginal
        self.authorRefined = authorRefined
        self.chapterNumber = chapterNumber
        self.sceneType = sceneType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.aiOriginal = try c.decodeIfPresent(String.self, forKey: .aiOriginal) ?? ""
        self.authorRefined = try c.decodeIfPresent(String.self, forKey: .authorRefined) ?? ""
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.sceneType = try c.decodeIfPresent(String.self, forKey: .sceneType)
    }
}

// MARK: - 文风样本提交响应

/// 文风样本提交响应，对应原版 voice.ts:14-16 `VoiceSampleResponse`。
///
/// 原版定义：
/// ```typescript
/// interface VoiceSampleResponse {
///   sample_id: string
/// }
/// ```
struct VoiceSampleResponse: Codable, Equatable {

    /// 样本 ID — voice.ts:15 `sample_id`
    let sampleId: String

    enum CodingKeys: String, CodingKey {
        case sampleId = "sample_id"
    }

    init(sampleId: String) {
        self.sampleId = sampleId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sampleId = try c.decodeIfPresent(String.self, forKey: .sampleId) ?? ""
    }
}

// MARK: - 文风指纹统计

/// 文风指纹统计，对应原版 voice.ts:18-24 `VoiceFingerprintDTO`。
///
/// 原版定义：
/// ```typescript
/// interface VoiceFingerprintDTO {
///   adjective_density: number
///   avg_sentence_length: number
///   sentence_count: number
///   sample_count: number
///   last_updated: string
/// }
/// ```
struct VoiceFingerprintDTO: Codable, Equatable {

    /// 形容词密度 — voice.ts:19 `adjective_density`
    let adjectiveDensity: Double

    /// 平均句长 — voice.ts:20 `avg_sentence_length`
    let avgSentenceLength: Double

    /// 句子总数 — voice.ts:21 `sentence_count`
    let sentenceCount: Int

    /// 样本总数 — voice.ts:22 `sample_count`
    let sampleCount: Int

    /// 最后更新时间 — voice.ts:23 `last_updated`（ISO 8601 字符串）
    let lastUpdated: String

    enum CodingKeys: String, CodingKey {
        case adjectiveDensity = "adjective_density"
        case avgSentenceLength = "avg_sentence_length"
        case sentenceCount = "sentence_count"
        case sampleCount = "sample_count"
        case lastUpdated = "last_updated"
    }

    init(
        adjectiveDensity: Double,
        avgSentenceLength: Double,
        sentenceCount: Int,
        sampleCount: Int,
        lastUpdated: String
    ) {
        self.adjectiveDensity = adjectiveDensity
        self.avgSentenceLength = avgSentenceLength
        self.sentenceCount = sentenceCount
        self.sampleCount = sampleCount
        self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.adjectiveDensity = try c.decodeIfPresent(Double.self, forKey: .adjectiveDensity) ?? 0.0
        self.avgSentenceLength = try c.decodeIfPresent(Double.self, forKey: .avgSentenceLength) ?? 0.0
        self.sentenceCount = try c.decodeIfPresent(Int.self, forKey: .sentenceCount) ?? 0
        self.sampleCount = try c.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 0
        self.lastUpdated = try c.decodeIfPresent(String.self, forKey: .lastUpdated) ?? ""
    }
}
