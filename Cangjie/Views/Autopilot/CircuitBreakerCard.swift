//
//  CircuitBreakerCard.swift
//  Cangjie
//
//  熔断器状态卡片：开闭状态/错误计数/最近错误/错误历史/重置按钮。
//  对齐原版 autopilot.ts:30-36 AutopilotCircuitBreakerData 字段。
//

import SwiftUI

/// 熔断器状态卡片
struct CircuitBreakerCard: View {

    let novelId: String

    @EnvironmentObject var autopilotStore: AutopilotStore

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // 标题行
            HStack {
                Image(systemName: "circuitbreaker")
                    .foregroundColor(breakerColor)
                Text("熔断器")
                    .font(Theme.headlineFont())
                Spacer()

                // 状态标签
                Text(breakerStateLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(breakerColor)
                    .cornerRadius(4)
            }

            // 错误计数（autopilot.ts:32 error_count / autopilot.ts:33 max_errors）
            if let breaker = autopilotStore.circuitBreaker {
                HStack(spacing: Theme.Spacing.lg) {
                    statItem(label: "错误计数", value: "\(breaker.errorCount)/\(breaker.maxErrors)")

                    if breaker.errorCount >= breaker.maxErrors {
                        statItem(label: "状态", value: "已熔断", color: Theme.error)
                    } else {
                        statItem(label: "状态", value: "正常", color: Theme.success)
                    }
                }

                // 最近错误（autopilot.ts:34 last_error 嵌套对象）
                if let lastError = breaker.lastError {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 10))
                            Text("最近错误：\(lastError.message)")
                                .font(.system(size: 10))
                            Spacer()
                        }
                        .foregroundColor(Theme.textTertiary)

                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(lastError.timestamp)
                                .font(.system(size: 10))
                            Spacer()
                        }
                        .foregroundColor(Theme.textTertiary)

                        if let context = lastError.context, !context.isEmpty {
                            Text(context)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }

                // 错误历史（autopilot.ts:35 error_history 数组）
                if let history = breaker.errorHistory, !history.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("错误历史（最近 \(history.count) 条）")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textTertiary)

                        ForEach(Array(history.enumerated()), id: \.offset) { index, record in
                            HStack {
                                Text("·")
                                    .font(.system(size: 10))
                                Text(record.message)
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(record.timestamp)
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                    }
                }
            } else {
                Text("加载中…")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)
            }

            // 重置按钮
            Button {
                Task { await autopilotStore.resetCircuitBreaker(novelId: novelId) }
            } label: {
                Label("重置熔断器", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(autopilotStore.circuitBreaker?.status == "closed")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }

    // MARK: - 辅助

    /// 熔断器颜色（autopilot.ts:31 status: closed/open/half_open）
    private var breakerColor: Color {
        guard let breaker = autopilotStore.circuitBreaker else { return Theme.textTertiary }
        switch breaker.status {
        case "open": return Theme.error
        case "half_open", "half-open": return Theme.warning
        case "closed": return Theme.success
        default: return Theme.textSecondary
        }
    }

    /// 熔断器状态标签
    private var breakerStateLabel: String {
        guard let breaker = autopilotStore.circuitBreaker else { return "未知" }
        switch breaker.status {
        case "open": return "已熔断"
        case "half_open", "half-open": return "半开"
        case "closed": return "已闭合"
        default: return breaker.status
        }
    }

    private func statItem(label: String, value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(color ?? Theme.textPrimary)
        }
    }
}
