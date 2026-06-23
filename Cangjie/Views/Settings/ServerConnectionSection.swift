//
//  ServerConnectionSection.swift
//  Cangjie
//
//  服务器连接：地址输入/健康检查按钮/Bearer Token/连接状态指示。
//  对齐 Vue3 的服务器配置交互。
//

import SwiftUI
import UIKit

/// 服务器连接设置分区
struct ServerConnectionSection: View {

    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var appState: AppState

    @State private var serverURL: String = ""
    @State private var bearerToken: String = ""
    @State private var basicAuthUser: String = ""
    @State private var basicAuthPassword: String = ""

    var body: some View {
        Section {
            // 服务器地址
            TextField("服务器地址", text: $serverURL)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            // 粘贴服务器地址按钮（带文字标签，确保点击区域明确）
            Button("📋 从剪贴板粘贴服务器地址") {
                if let text = UIPasteboard.general.string {
                    serverURL = text
                }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            // Bearer Token（改用 TextField，全局支持第三方键盘）
            TextField("Bearer Token（可选）", text: $bearerToken)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            // 粘贴 Bearer Token 按钮
            Button("📋 从剪贴板粘贴 Bearer Token") {
                if let text = UIPasteboard.general.string {
                    bearerToken = text
                }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            // 连接状态
            connectionStatusRow

            // 操作按钮
            HStack {
                Button {
                    Task { await testConnection() }
                } label: {
                    Label("测试连接", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.bordered)
                .disabled(serverURL.isEmpty)

                Button {
                    saveConfig()
                } label: {
                    Label("保存", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(serverURL.isEmpty)
            }

            // 健康信息
            if let health = appState.healthStatus {
                VStack(alignment: .leading, spacing: 4) {
                    Label("版本：\(health.version)", systemImage: "tag")
                        .font(.system(size: 12))
                    Label("守护进程：\(health.isDaemonRunning ? "运行中" : "未运行")", systemImage: "gear")
                        .font(.system(size: 12))
                    if let uptime = health.uptimeSeconds {
                        Label("运行时长：\(Int(uptime))秒", systemImage: "clock")
                            .font(.system(size: 12))
                    }
                }
                .foregroundColor(Theme.textSecondary)
            }
        }
        .onAppear {
            loadCurrentConfig()
        }
    }

    // MARK: - 连接状态行

    private var connectionStatusRow: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(statusText)
                .font(.system(size: 13))

            Spacer()
        }
    }

    // MARK: - 辅助

    private var statusColor: Color {
        switch appState.serverConnection {
        case .connected: return Theme.success
        case .connecting: return Theme.info
        case .failed: return Theme.error
        case .disconnected: return Theme.textTertiary
        }
    }

    private var statusText: String {
        switch appState.serverConnection {
        case .connected: return "已连接"
        case .connecting: return "连接中…"
        case .failed(let message): return "连接失败：\(message)"
        case .disconnected: return "未连接"
        }
    }

    private func loadCurrentConfig() {
        serverURL = APIConfig.shared.baseURL
        bearerToken = APIConfig.shared.bearerToken
        basicAuthUser = APIConfig.shared.basicAuthUser
        basicAuthPassword = APIConfig.shared.basicAuthPassword
    }

    private func testConnection() async {
        saveConfig()
        await appState.checkServerConnection()
    }

    private func saveConfig() {
        APIConfig.shared.saveConfiguration(
            baseURL: serverURL,
            bearerToken: bearerToken,
            basicAuthUser: basicAuthUser,
            basicAuthPassword: basicAuthPassword
        )
    }
}
