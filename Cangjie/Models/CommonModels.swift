//
//  CommonModels.swift
//  Cangjie
//
//  通用数据模型：泛型 API 响应封装、分页信息、健康检查状态。
//  所有 Codable 模型字段对齐后端 DTO，空值处理遵循架构文档 6.7 节。
//

import Foundation

// MARK: - 健康检查响应

/// 后端健康检查响应，对应 `GET /health` 返回。
///
/// 后端返回示例：
/// ```json
/// {
///   "status": "healthy",
///   "version": "1.0.2",
///   "build_id": "abc123",
///   "uptime_seconds": 3600.5,
///   "daemon_process": {
///     "running": true,
///     "pid": 12345
///   }
/// }
/// ```
struct HealthStatus: Codable, Equatable {

    /// 服务状态，通常为 "healthy"
    let status: String

    /// 后端版本号
    let version: String

    /// 构建标识
    let buildId: String?

    /// 运行时长（秒）
    let uptimeSeconds: Double?

    /// 守护进程状态
    let daemonProcess: DaemonProcess?

    enum CodingKeys: String, CodingKey {
        case status
        case version
        case buildId = "build_id"
        case uptimeSeconds = "uptime_seconds"
        case daemonProcess = "daemon_process"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? ""
        self.buildId = try container.decodeIfPresent(String.self, forKey: .buildId)
        self.uptimeSeconds = try container.decodeIfPresent(Double.self, forKey: .uptimeSeconds)
        self.daemonProcess = try container.decodeIfPresent(DaemonProcess.self, forKey: .daemonProcess)
    }

    init(
        status: String,
        version: String,
        buildId: String? = nil,
        uptimeSeconds: Double? = nil,
        daemonProcess: DaemonProcess? = nil
    ) {
        self.status = status
        self.version = version
        self.buildId = buildId
        self.uptimeSeconds = uptimeSeconds
        self.daemonProcess = daemonProcess
    }

    /// 是否健康
    var isHealthy: Bool {
        return status == "healthy"
    }

    /// 守护进程是否运行中
    var isDaemonRunning: Bool {
        return daemonProcess?.running ?? false
    }
}

/// 守护进程状态信息
struct DaemonProcess: Codable, Equatable {

    /// 是否运行中
    let running: Bool

    /// 进程 ID
    let pid: Int?

    init(running: Bool, pid: Int? = nil) {
        self.running = running
        self.pid = pid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.running = try container.decodeIfPresent(Bool.self, forKey: .running) ?? false
        self.pid = try container.decodeIfPresent(Int.self, forKey: .pid)
    }
}

// MARK: - 后端错误响应

/// 后端 FastAPI 标准错误响应。
///
/// 后端错误时返回 `{"detail": "错误信息"}` + HTTP 状态码。
struct BackendErrorResponse: Codable {

    /// 错误详情
    let detail: String

    init(detail: String) {
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // detail 可能是字符串，也可能是数组（FastAPI 校验错误）
        if let detailString = try? container.decode(String.self, forKey: .detail) {
            self.detail = detailString
        } else if let detailArray = try? container.decode([AnyCodable].self, forKey: .detail) {
            // FastAPI 校验错误返回数组格式
            self.detail = detailArray.map { "\($0)" }.joined(separator: "; ")
        } else {
            self.detail = "未知错误"
        }
    }
}

// MARK: - 分页信息

/// 通用分页元数据。
///
/// 后端大部分列表接口直接返回数组（无分页封装），
/// 但统计 API 和部分查询接口可能使用分页。
struct PageInfo: Codable, Equatable {

    /// 当前页码（从 1 开始）
    let page: Int

    /// 每页条数
    let pageSize: Int

    /// 总条数
    let total: Int

    /// 总页数
    var totalPages: Int {
        guard pageSize > 0 else { return 0 }
        return Int(ceil(Double(total) / Double(pageSize)))
    }

    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case total
    }

    init(page: Int, pageSize: Int, total: Int) {
        self.page = page
        self.pageSize = pageSize
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        self.pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize) ?? 20
        self.total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }
}

// MARK: - 分页响应封装

/// 通用分页响应封装。
///
/// 当后端返回分页数据时使用此结构。
struct PaginatedResponse<T: Codable>: Codable {

    /// 数据列表
    let items: [T]

    /// 分页信息
    let pageInfo: PageInfo?

    enum CodingKeys: String, CodingKey {
        case items
        case pageInfo = "page_info"
    }

    init(items: [T], pageInfo: PageInfo? = nil) {
        self.items = items
        self.pageInfo = pageInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decodeIfPresent([T].self, forKey: .items) ?? []
        self.pageInfo = try container.decodeIfPresent(PageInfo.self, forKey: .pageInfo)
    }
}

// MARK: - AnyCodable（动态 JSON 值）

/// 动态 JSON 值容器，用于后端返回的灵活结构（如 generation_prefs、node_states 等）。
///
/// 后端部分字段使用 `Dict[str, Any]`，JSON 中可能是任意结构，
/// AnyCodable 能安全编解码这些动态值。
struct AnyCodable: Codable, Equatable {

    /// 存储的值
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            self.value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as String, r as String):
            return l == r
        case let (l as [Any], r as [Any]):
            return AnyCodable(l).stringValue == AnyCodable(r).stringValue
        case let (l as [String: Any], r as [String: Any]):
            return AnyCodable(l).stringValue == AnyCodable(r).stringValue
        default:
            return false
        }
    }

    /// 转为 JSON 字符串（用于调试/日志）
    var stringValue: String {
        if let data = try? JSONSerialization.data(
            withJSONObject: value,
            options: [.fragmentsAllowed]
        ),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\(value)"
    }

    /// 转为字典（如果底层值是字典）
    var dictionaryValue: [String: Any]? {
        return value as? [String: Any]
    }

    /// 转为数组（如果底层值是数组）
    var arrayValue: [Any]? {
        return value as? [Any]
    }

    /// 转为字符串（如果底层值是字符串）
    var stringStringValue: String? {
        return value as? String
    }

    /// 转为整数（如果底层值是整数）
    var intValue: Int? {
        return value as? Int
    }

    /// 转为浮点数（如果底层值是数字）
    var doubleValue: Double? {
        return value as? Double
    }

    /// 转为布尔值（如果底层值是布尔）
    var boolValue: Bool? {
        return value as? Bool
    }
}

// MARK: - 通用消息响应

/// 后端通用消息响应（如 `{"message": "操作成功", "ok": true}`）。
struct MessageResponse: Codable, Equatable {

    /// 消息内容
    let message: String

    /// 是否成功
    let ok: Bool?

    enum CodingKeys: String, CodingKey {
        case message
        case ok
    }

    init(message: String, ok: Bool? = nil) {
        self.message = message
        self.ok = ok
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.ok = try container.decodeIfPresent(Bool.self, forKey: .ok)
    }
}

// MARK: - HTTP 方法枚举

/// HTTP 请求方法枚举
enum HTTPMethod: String, Equatable {

    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - SSE 流类型枚举

/// SSE 流类型，对应架构文档 6.5 节的 7 条流。
enum SSEStreamType: String, CaseIterable, Hashable {

    /// 章节生成流 — `GET /api/v1/autopilot/{id}/chapter-stream`
    case chapterStream

    /// 自动驾驶事件/日志流 — `GET /api/v1/autopilot/{id}/stream`（别名 `/log-stream`）
    case autopilotStream

    /// Bible 流式生成 — `POST /api/v1/bible/novels/{id}/generate-stream`
    case bibleGenerateStream

    /// 宏观规划流 — `GET /api/v1/planning/novels/{id}/macro/stream`
    case macroPlanStream

    /// 宏观规划进度流 — `GET /api/v1/planning/novels/{id}/macro/progress/stream`
    case macroPlanProgressStream

    /// DAG 事件流 — `GET /api/v1/dag/events?novel_id={id}`
    case dagEvents

    /// 扩展包安装流 — `POST /api/v1/system/install-extensions`
    case extensionInstall

    /// 流的中文描述
    var displayName: String {
        switch self {
        case .chapterStream:
            return "章节生成流"
        case .autopilotStream:
            return "自动驾驶日志流"
        case .bibleGenerateStream:
            return "Bible 生成流"
        case .macroPlanStream:
            return "宏观规划流"
        case .macroPlanProgressStream:
            return "规划进度流"
        case .dagEvents:
            return "DAG 事件流"
        case .extensionInstall:
            return "扩展包安装流"
        }
    }

    /// 是否使用 data-only 帧格式（autopilot 系列流）
    /// DAG 事件流使用 event+data 帧格式
    var isDataOnlyFormat: Bool {
        switch self {
        case .dagEvents:
            return false
        default:
            return true
        }
    }
}
