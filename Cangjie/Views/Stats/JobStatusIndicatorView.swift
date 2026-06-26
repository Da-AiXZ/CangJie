//
//  JobStatusIndicatorView.swift
//  Cangjie
//
//  任务状态指示器，轮询 GET /jobs/{id} + 取消按钮 POST /jobs/{id}/cancel。
//  对齐原版 JobStatusIndicator 组件。
//

import SwiftUI

/// 任务状态指示器视图
///
/// 轮询 `GET /api/v1/jobs/{jobId}` 每 2 秒一次，显示任务状态。
/// 支持取消任务（`POST /api/v1/jobs/{jobId}/cancel`）。
/// 页面消失时停止轮询。
struct JobStatusIndicatorView: View {
    let jobId: String
    var onCompleted: (() -> Void)? = nil

    @State private var jobStatus: JobStatusResponse?
    @State private var isLoading: Bool = false
    @State private var timer: Timer?
    @State private var hasNotifiedCompleted: Bool = false

    private let apiClient = APIClient.shared
    private let pollInterval: TimeInterval = 2.0

    var body: some View {
        HStack(spacing: 8) {
            if let status = jobStatus {
                // 状态图标
                statusIcon(status.status)

                // 状态文本
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.status.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(statusColor(status.status))
                    if !status.message.isEmpty {
                        Text(status.message)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // 取消按钮（仅 running/queued 时显示）
                if status.status == .running || status.status == .queued {
                    Button {
                        Task { await cancelJob() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.error)
                    }
                    .buttonStyle(.plain)
                }
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                Text("查询任务状态…")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(Theme.textSecondary)
                Text("未知状态")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    // MARK: - 状态图标

    @ViewBuilder
    private func statusIcon(_ status: JobStatus) -> some View {
        switch status {
        case .running:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.success)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.error)
        case .cancelled:
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
        case .queued:
            Image(systemName: "clock.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.info)
        }
    }

    // MARK: - 状态颜色

    private func statusColor(_ status: JobStatus) -> Color {
        switch status {
        case .running: return Theme.info
        case .done: return Theme.success
        case .error: return Theme.error
        case .cancelled: return Theme.textSecondary
        case .queued: return Theme.info
        }
    }

    // MARK: - 轮询

    private func startPolling() {
        Task { await pollStatus() }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            Task { await pollStatus() }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func pollStatus() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let response: JobStatusResponse = try await apiClient.request(
                APIEndpoint.Workflow.getJobStatus(jobId: jobId)
            )
            jobStatus = response

            // 终态处理
            if response.status.isTerminal {
                stopPolling()
                if response.status == .done && !hasNotifiedCompleted {
                    hasNotifiedCompleted = true
                    onCompleted?()
                }
            }
        } catch {
            // 静默失败，继续轮询
        }
        isLoading = false
    }

    // MARK: - 取消任务

    private func cancelJob() async {
        do {
            let _: JobCreateResponse = try await apiClient.request(
                APIEndpoint.Workflow.cancelJob(jobId: jobId),
                body: AnyCodable([:])
            )
            stopPolling()
            // 更新显示状态
            if var current = jobStatus {
                jobStatus = JobStatusResponse(
                    jobId: current.jobId,
                    kind: current.kind,
                    slug: current.slug,
                    status: .cancelled,
                    phase: "cancelled",
                    message: "用户取消",
                    error: nil,
                    started: current.started,
                    finished: current.finished,
                    done: true,
                    ok: true
                )
            }
        } catch {
            // 静默失败
        }
    }
}
