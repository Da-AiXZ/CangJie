//
//  SSEEvent.swift
//  Cangjie
//
//  SSE 事件模型，表示一条 Server-Sent Events 事件。
//  支持两种帧格式：data-only（autopilot 流）和 event+data（DAG 事件流）。
//  基于架构文档 6.4 节。
//

import Foundation

/// SSE 事件，表示一条 Server-Sent Events 消息。
///
/// SSE 帧格式有两种（源码确认）：
///
/// 1. **autopilot 流**（chapter-stream / stream / log-stream）：仅 `data:` 行
///    ```
///    data: {"type":"log_line","message":"...","timestamp":"..."}\n\n
///    ```
///    事件类型在 JSON 的 `type` 字段中，非 SSE `event:` 字段。
///
/// 2. **DAG 事件流**：带 `event:` 行
///    ```
///    event: node_status_change\n
///    data: {"novel_id":"...","node_id":"...","status":"running"}\n\n
///    ```
struct SSEEvent: Equatable {

    /// 事件名（来自 `event:` 行，仅 DAG 事件流有值）
    let event: String?

    /// 事件数据（来自 `data:` 行，可能为多行拼接）
    let data: String

    /// 事件 ID（来自 `id:` 行，可选）
    let id: String?

    /// 重连间隔（来自 `retry:` 行，毫秒，可选）
    let retry: Int?

    /// 初始化
    /// - Parameters:
    ///   - event: 事件名
    ///   - data: 事件数据
    ///   - id: 事件 ID
    ///   - retry: 重连间隔（毫秒）
    init(event: String? = nil, data: String, id: String? = nil, retry: Int? = nil) {
        self.event = event
        self.data = data
        self.id = id
        self.retry = retry
    }

    /// 将 data 解码为指定类型。
    ///
    /// - Parameter type: 目标类型
    /// - Returns: 解码后的对象
    /// - Throws: 解码错误
    func decode<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = SSEEvent.defaultDecoder) throws -> T {
        guard let data = data.data(using: .utf8) else {
            throw SSEError.invalidData("无法将 data 转换为 UTF-8")
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SSEError.decodingError(error)
        }
    }

    /// 将 data 解码为 JSON 字典。
    ///
    /// - Returns: JSON 字典
    func decodeAsDictionary() -> [String: Any]? {
        guard let data = data.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// 从 JSON 字典中获取 `type` 字段值（autopilot 流的事件类型）。
    var typeFromData: String? {
        return decodeAsDictionary()?["type"] as? String
    }

    /// 从 JSON 字典中获取 `phase` 字段值（Bible 生成流的阶段标识）。
    var phaseFromData: String? {
        return decodeAsDictionary()?["phase"] as? String
    }

    /// 是否为心跳事件
    var isHeartbeat: Bool {
        if let event = event, event == "heartbeat" {
            return true
        }
        if let type = typeFromData, type == "heartbeat" {
            return true
        }
        return false
    }

    /// 是否为连接建立事件
    var isConnected: Bool {
        if let type = typeFromData, type == "connected" {
            return true
        }
        if let event = event, event == "connected" {
            return true
        }
        return false
    }

    // MARK: - Bible SSE 事件类型（bible.ts:400-413）

    /// Bible SSE 事件大类（从 event 行获取，值为 phase/data/done/error）。
    /// Bible 生成流的 event 行值为 phase/data/done/error，子类型在 data JSON 的 type 字段中。
    /// 对齐 bible.ts:400-413 parseSseBlock 逻辑。
    var bibleEventType: String? {
        return event
    }

    /// Bible SSE data 子类型（从 data JSON 的 type 字段获取）。
    /// 当 event 行值为 "data" 时，data JSON 中的 type 字段确定具体子类型：
    /// style / style_chunk / worldbuilding_chunk / worldbuilding_field /
    /// worldbuilding_dimension / character / character_chunk / location / location_chunk /
    /// approval_required
    /// 对齐 bible.ts:436 `const dataType = String(payload?.type ?? '')`
    var bibleDataSubType: String? {
        guard let dict = decodeAsDictionary() else { return nil }
        return dict["type"] as? String
    }

    // MARK: - generate-chapter-stream 事件类型（workflow.ts:362-369）

    /// 单章生成 SSE 事件类型（data-only 格式，从 data JSON 的 type 字段获取）。
    /// 7类事件：phase / llm_chunk / beats_generated / approval_required / chunk / done / error
    /// 对齐 workflow.ts:417 `const typ = o.type as string`
    var generateChapterEventType: String? {
        return typeFromData
    }

    /// 默认 JSON 解码器（配置微秒日期格式）
    private static let defaultDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(DateDecodingStrategyHelper.decode)
        return decoder
    }()
}

// MARK: - SSE 错误

/// SSE 相关错误
enum SSEError: Error, LocalizedError {

    /// 无效的数据
    case invalidData(String)

    /// 解码错误
    case decodingError(Error)

    /// 连接错误
    case connectionError(Error)

    /// 流已取消
    case cancelled

    /// 重连次数耗尽
    case maxRetriesExceeded

    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "SSE 数据无效：\(message)"
        case .decodingError(let error):
            return "SSE 解码失败：\(error.localizedDescription)"
        case .connectionError(let error):
            return "SSE 连接错误：\(error.localizedDescription)"
        case .cancelled:
            return "SSE 连接已取消"
        case .maxRetriesExceeded:
            return "SSE 重连次数耗尽"
        }
    }
}
