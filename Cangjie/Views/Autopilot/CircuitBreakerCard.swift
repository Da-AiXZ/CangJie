//
//  CircuitBreakerCard.swift
//  Cangjie
//
//  熔断器状态卡片：开闭状态/错误计数/最近错误/重置按钮。
//  对齐 Vue3 CircuitBreakerStatus.vue 的交互。
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

            // 错误计数
            if let breaker = autopilotStore.circuitBreaker {
                HStack(spacing: Theme.Spacing.lg) {
                    statItem(label: "错误计数", value: "\(breaker.failureCount)/\(breaker.threshold)")

                    if breaker.failureCount >= breaker.threshold {
                        statItem(label: "状态", value: "已熔断", color: Theme.error)
                    } else {
                        statItem(label: "状态", value: "正常", color: Theme.success)
                    }

                    if let resetTimeout = breaker.resetTimeoutSeconds {
                        statItem(label: "重置超时", value: "\(resetTimeout)s")
                    }
                }

                // 最近错误时间
                if let lastFailure = breaker.lastFailureAt, !lastFailure.isEmpty {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("最近错误：\(lastFailure)")
                            .font(.system(size: 10))
                        Spacer()
                    }
                    .foregroundColor(Theme.textTertiary)
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
            .disabled(autopilotStore.circuitBreaker?.state == "closed")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }

    // MARK: - 辅助

    private var breakerColor: Color {
        guard let breaker = autopilotStore.circuitBreaker else { return Theme.textTertiary }
        switch breaker.state {
        case "open": return Theme.error
        case "half_open", "half-open": return Theme.warning
        case "closed": return Theme.success
        default: return Theme.textSecondary
        }
    }

    private var breakerStateLabel: String {
        guard let breaker = autopilotStore.circuitBreaker else { return "未知" }
        switch breaker.state {
        case "open": return "已熔断"
        case "half_open", "half-open": return "半开"
        case "closed": return "已闭合"
        default: return breaker.state
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
