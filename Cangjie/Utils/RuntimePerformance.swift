//
//  RuntimePerformance.swift
//  Cangjie
//
//  运行时性能配置常量集，对齐原版 config/performance.ts。
//  D-1: aiInvocation.generationPollMs = 1200（原版 L75）
//  D-2: workbench.guardrailEmptyBackoffMs = 90000 / guardrailErrorBackoffMs = 60000 / guardrailSnapshotRefreshDelayMs = 3500（原版 L96-98）
//

import Foundation

// MARK: - 运行时性能配置

/// 运行时性能配置常量集，对齐原版 config/performance.ts runtimePerformance。
///
/// P2 D-1/D-2：将硬编码值提取为可配置常量。
struct RuntimePerformance {

    // MARK: - AI Invocation 配置（D-1）

    /// AI Invocation 轮询配置 — performance.ts:74-76
    struct AIInvocation {
        /// 生成轮询间隔（毫秒） — performance.ts:75
        /// 原项目默认 1200ms，仓颉 P0 硬编码 2000ms，P2 对齐原项目
        let generationPollMs: Int = 1200
    }

    // MARK: - Workbench 配置（D-2）

    /// Workbench 配置 — performance.ts:87-103
    struct Workbench {
        /// 护栏快照空结果退避时间（毫秒） — performance.ts:97
        /// 空结果后 90 秒内不重复请求
        let guardrailEmptyBackoffMs: Int = 90000

        /// 护栏快照错误退避时间（毫秒） — performance.ts:98
        /// 请求出错后 60 秒内不重复请求
        let guardrailErrorBackoffMs: Int = 60000

        /// 护栏快照刷新延迟（毫秒） — performance.ts:96
        /// 写入后等待 3.5 秒再刷新快照（等待后端落盘）
        let guardrailSnapshotRefreshDelayMs: Int = 3500
    }

    /// AI Invocation 配置实例
    static let aiInvocation = AIInvocation()

    /// Workbench 配置实例
    static let workbench = Workbench()
}
