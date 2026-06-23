//
//  Logger.swift
//  Cangjie
//
//  统一日志封装，基于 os.Logger，分级输出 debug/info/warning/error。
//  自动附带文件名与行号，便于定位问题。
//

import Foundation
import os

/// 统一日志门面，封装 os.Logger，按子系统与分类组织日志输出。
///
/// 使用方式：
/// ```swift
/// Logger.network.debug("请求失败: \(error.localizedDescription)")
/// Logger.sse.warning("SSE 连接断开，准备重连")
/// Logger.engine.error("自动驾驶启动失败: \(error)")
/// ```
enum Logger {

    // MARK: - 日志分类

    /// 网络层日志（API 请求/响应/错误）
    static let network = Self.create(category: "network")

    /// SSE 流日志（连接/断开/重连/帧解析）
    static let sse = Self.create(category: "sse")

    /// 引擎日志（自动驾驶/生成/DAG）
    static let engine = Self.create(category: "engine")

    /// 数据层日志（模型编解码/Store 操作）
    static let data = Self.create(category: "data")

    /// UI 层日志（视图生命周期/导航/手势）
    static let ui = Self.create(category: "ui")

    /// 通用日志
    static let general = Self.create(category: "general")

    // MARK: - 创建 Logger

    /// 子系统标识，统一为 Bundle ID
    private static let subsystem = "com.cangjie.ios"

    /// 创建指定分类的 os.Logger
    private static func create(category: String) -> os.Logger {
        return os.Logger(subsystem: subsystem, category: category)
    }
}

// MARK: - 便捷日志方法扩展

extension os.Logger {

    /// 调试日志，仅在 Debug 构建中输出
    func debug(_ message: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        self.debug("[\(fileName):\(line)] \(message, privacy: .public)")
    }

    /// 信息日志
    func info(_ message: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        self.info("[\(fileName):\(line)] \(message, privacy: .public)")
    }

    /// 警告日志
    func warning(_ message: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        self.warning("[\(fileName):\(line)] \(message, privacy: .public)")
    }

    /// 错误日志
    func error(_ message: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        self.error("[\(fileName):\(line)] \(message, privacy: .public)")
    }
}
