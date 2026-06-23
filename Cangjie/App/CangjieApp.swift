//
//  CangjieApp.swift
//  Cangjie
//
//  App 入口，@main 标注，App protocol 实现。
//  初始化 AppState，首次启动引导服务器配置，注入环境对象。
//

import SwiftUI

/// 仓颉 — PlotPilot iOS 客户端入口
///
/// App 名称：仓颉
/// Bundle ID：com.cangjie.ios
/// 最低部署：iOS 16.0
/// 目标设备：iPad Pro 2021 (M1), iOS 16.6.1
///
/// 首次启动若 Keychain 无服务器配置，显示服务器配置引导页。
@main
struct CangjieApp: App {

    /// 全局应用状态
    @StateObject private var appState = AppState()

    /// API 配置
    @StateObject private var apiConfig = APIConfig.shared

    var body: some Scene {
        WindowGroup {
            rootContent
                .environmentObject(appState)
                .environmentObject(apiConfig)
                .preferredColorScheme(appState.colorScheme)
                .environment(\.fontSizeScale, appState.currentFontSizeScale)
                .environment(\.themeMode, appState.themeMode)
                .tint(Theme.primary)
                .task {
                    // App 启动时执行健康检查
                    await appState.checkServerConnection()
                }
        }
    }

    /// 根内容视图
    ///
    /// 根据服务器配置状态决定显示引导页还是主界面。
    @ViewBuilder
    private var rootContent: some View {
        if appState.needsServerConfig {
            // 首次启动或未配置服务器，显示配置引导
            ServerConfigGuideView()
                .environmentObject(appState)
                .environmentObject(apiConfig)
        } else {
            // 已配置，显示主界面
            RootView()
                .environmentObject(appState)
                .environmentObject(apiConfig)
        }
    }
}

// MARK: - 服务器配置引导视图

/// 首次启动服务器配置引导视图
///
/// T01 阶段提供基础实现，T03 的 ServerConnectionSection 将提供完整功能。
struct ServerConfigGuideView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var apiConfig: APIConfig

    @State private var serverURL: String = ""
    @State private var bearerToken: String = ""
    @State private var basicAuthUser: String = ""
    @State private var basicAuthPassword: String = ""
    @State private var isTesting: Bool = false
    @State private var testResult: String?
    @State private var testSuccess: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // 图标与标题
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Theme.primary)

                        Text("仓颉")
                            .font(Theme.largeTitleFont())

                        Text("PlotPilot iOS 客户端")
                            .font(Theme.bodyFont())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // 配置表单
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("服务器配置")
                            .font(Theme.headlineFont())

                        VStack(spacing: Theme.Spacing.sm) {
                            TextField("服务器地址", text: $serverURL)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)

                            SecureField("Bearer Token（可选）", text: $bearerToken)
                                .textFieldStyle(.roundedBorder)

                            TextField("Basic Auth 用户名（可选）", text: $basicAuthUser)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)

                            SecureField("Basic Auth 密码（可选）", text: $basicAuthPassword)
                                .textFieldStyle(.roundedBorder)
                        }

                        // 测试结果
                        if let result = testResult {
                            HStack {
                                Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(testSuccess ? Theme.success : Theme.error)
                                Text(result)
                                    .font(Theme.captionFont())
                            }
                            .padding(.top, Theme.Spacing.xxs)
                        }

                        // 按钮
                        HStack(spacing: Theme.Spacing.md) {
                            Button {
                                Task { await testConnection() }
                            } label: {
                                if isTesting {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("测试连接")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(serverURL.isEmpty || isTesting)

                            Button {
                                saveAndContinue()
                            } label: {
                                Text("保存并进入")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(serverURL.isEmpty)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(Theme.CornerRadius.large)

                    // 说明
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("使用说明")
                            .font(Theme.headlineFont())

                        Text("• 输入 PlotPilot 后端服务器地址（如 https://plotpilot.example.com）")
                        Text("• 如果服务器配置了 Nginx Bearer Token 或 Basic Auth 鉴权，请填写对应凭证")
                        Text("• 首次使用需在云端部署 PlotPilot 后端，详见部署文档")
                    }
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.lg)

                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
        }
    }

    /// 测试连接
    private func testConnection() async {
        guard !serverURL.isEmpty else { return }

        await MainActor.run {
            isTesting = true
            testResult = nil
        }

        // 临时保存配置
        apiConfig.saveConfiguration(
            baseURL: serverURL,
            bearerToken: bearerToken,
            basicAuthUser: basicAuthUser,
            basicAuthPassword: basicAuthPassword
        )

        do {
            let health = try await APIClient.shared.healthCheck()
            await MainActor.run {
                isTesting = false
                testSuccess = health.isHealthy
                if health.isHealthy {
                    testResult = "连接成功！后端版本 \(health.version)，守护进程\(health.isDaemonRunning ? "运行中" : "未运行")"
                } else {
                    testResult = "后端状态异常：\(health.status)"
                }
            }
        } catch {
            await MainActor.run {
                isTesting = false
                testSuccess = false
                testResult = "连接失败：\(error.localizedDescription)"
            }
        }
    }

    /// 保存配置并继续
    private func saveAndContinue() {
        apiConfig.saveConfiguration(
            baseURL: serverURL,
            bearerToken: bearerToken,
            basicAuthUser: basicAuthUser,
            basicAuthPassword: basicAuthPassword
        )
        appState.needsServerConfig = false

        // 异步检查连接
        Task {
            await appState.checkServerConnection()
        }
    }
}

// MARK: - 占位根视图

/// T01 阶段占位根视图
///
/// T03 将用完整的 RootView（NavigationSplitView 三栏布局）替换此视图。
/// 此视图仅确保 T01 代码可编译通过，并显示基本状态信息。
struct PlaceholderRootView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.success)

            Text("仓颉已就绪")
                .font(Theme.titleFont())

            Text("T01 基础设施搭建完成")
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)

            if let health = appState.healthStatus {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("后端版本：\(health.version)")
                    Text("守护进程：\(health.isDaemonRunning ? "运行中" : "未运行")")
                    Text("运行时长：\(Int(health.uptimeSeconds ?? 0))秒")
                }
                .font(Theme.captionFont())
                .foregroundColor(Theme.textSecondary)
                .padding()
                .background(Theme.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
            }

            Text("等待 T02-T05 实现完整功能...")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
