//
//  DateFormatter+ISO.swift
//  Cangjie
//
//  ISO 8601 日期解析扩展，支持后端 Python datetime.isoformat() 的微秒 6 位格式。
//  后端日期格式示例：2026-06-23T12:00:01.123456
//

import Foundation

/// ISO 8601 日期格式化工具，兼容后端 Python datetime.isoformat() 输出。
///
/// 后端使用 Python 的 `datetime.isoformat()`，格式为 `2026-06-23T12:00:01.123456`，
/// 微秒固定 6 位。标准 `ISO8601DateFormatter` 仅支持毫秒 3 位，因此需要自定义格式。
enum ISODateFormatter {

    /// 微秒 6 位格式：yyyy-MM-dd'T'HH:mm:ss.SSSSSS
    private static let microsecondFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    /// 无微秒格式：yyyy-MM-dd'T'HH:mm:ss（后端有时省略微秒）
    private static let noFractionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    /// 标准 ISO8601 格式化器（带时区后缀，如 +08:00 或 Z）
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// 将字符串解析为 Date，依次尝试多种格式。
    ///
    /// 支持的格式：
    /// 1. `2026-06-23T12:00:01.123456`（后端默认，微秒 6 位）
    /// 2. `2026-06-23T12:00:01`（无微秒）
    /// 3. `2026-06-23T12:00:01.123Z`（标准 ISO8601 带时区）
    /// 4. `2026-06-23T12:00:01+08:00`（带时区偏移）
    ///
    /// - Parameter string: 日期字符串
    /// - Returns: 解析后的 Date，解析失败返回 nil
    static func date(from string: String) -> Date? {
        // 1. 尝试标准 ISO8601（带时区后缀 Z 或 +08:00）
        if let date = iso8601Formatter.date(from: string) {
            return date
        }

        // 2. 尝试无时区后缀的 ISO8601
        let noTimeZoneFormatter = ISO8601DateFormatter()
        noTimeZoneFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        noTimeZoneFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = noTimeZoneFormatter.date(from: string) {
            return date
        }

        // 3. 尝试微秒 6 位格式（后端默认）
        if let date = microsecondFormatter.date(from: string) {
            return date
        }

        // 4. 尝试无微秒格式
        if let date = noFractionFormatter.date(from: string) {
            return date
        }

        // 5. 尝试带时区偏移的格式（如 +08:00）
        let offsetFormatter = DateFormatter()
        offsetFormatter.calendar = Calendar(identifier: .gregorian)
        offsetFormatter.locale = Locale(identifier: "en_US_POSIX")
        offsetFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        if let date = offsetFormatter.date(from: string) {
            return date
        }

        // 6. 最后尝试无微秒但带时区偏移
        let offsetNoFractionFormatter = DateFormatter()
        offsetNoFractionFormatter.calendar = Calendar(identifier: .gregorian)
        offsetNoFractionFormatter.locale = Locale(identifier: "en_US_POSIX")
        offsetNoFractionFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        if let date = offsetNoFractionFormatter.date(from: string) {
            return date
        }

        return nil
    }

    /// 将 Date 格式化为后端兼容的 ISO 字符串（微秒 6 位）。
    ///
    /// - Parameter date: 日期对象
    /// - Returns: 格式化后的字符串，如 "2026-06-23T12:00:01.123456"
    static func string(from date: Date) -> String {
        return microsecondFormatter.string(from: date)
    }
}

// MARK: - JSONDecoder 日期解码策略

/// 提供 JSONDecoder 使用的自定义日期解码策略闭包。
/// 配合 APIClient 使用，统一处理后端微秒日期格式。
enum DateDecodingStrategyHelper {

    /// 自定义日期解码闭包，委托给 ISODateFormatter
    static func decode(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        guard let date = ISODateFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析日期字符串: \(dateString)"
            )
        }
        return date
    }
}

// MARK: - JSONEncoder 日期编码策略

/// 提供 JSONEncoder 使用的自定义日期编码策略闭包。
enum DateEncodingStrategyHelper {

    /// 自定义日期编码闭包，委托给 ISODateFormatter
    static func encode(_ date: Date, encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(ISODateFormatter.string(from: date))
    }
}
