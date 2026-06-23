//
//  AboutSection.swift
//  Cangjie
//
//  关于：版本号/构建号/源码地址/许可证/致谢。
//

import SwiftUI

/// 关于设置分区
struct AboutSection: View {

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        // 版本信息
        HStack {
            Image(systemName: "info.circle")
                .foregroundColor(Theme.primary)
            Text("版本")
            Spacer()
            Text("\(appVersion) (\(buildNumber))")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
        }

        // 源码地址
        Link(destination: URL(string: "https://github.com/plotpilot/plotpilot")!) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(Theme.primary)
                Text("源码地址")
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
        }

        // 许可证
        Link(destination: URL(string: "https://opensource.org/licenses/MIT")!) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(Theme.primary)
                Text("许可证")
                Spacer()
                Text("MIT")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
        }

        // 致谢
        NavigationLink {
            creditsView
        } label: {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(Theme.primary)
                Text("致谢")
            }
        }
    }

    // MARK: - 致谢页

    private var creditsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("仓颉 · PlotPilot iOS")
                    .font(Theme.titleFont())

                Text("长篇叙事工作台 — 以梗概与类型开局，选定目标篇幅；宏观结构、幕次与节拍由后台自动编排。")
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)

                Divider()

                Text("技术栈")
                    .font(Theme.headlineFont())
                VStack(alignment: .leading, spacing: 4) {
                    Text("• SwiftUI + NavigationSplitView")
                    Text("• Swift 5.9 + async/await")
                    Text("• SSE (Server-Sent Events) 流式")
                    Text("• FastAPI + SQLite 后端")
                }
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)

                Divider()

                Text("开源依赖")
                    .font(Theme.headlineFont())
                VStack(alignment: .leading, spacing: 4) {
                    Text("• PlotPilot 后端引擎")
                    Text("• Naive UI (前端参考)")
                    Text("• LangGraph (DAG 运行时)")
                }
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle("致谢")
        .navigationBarTitleDisplayMode(.inline)
    }
}
