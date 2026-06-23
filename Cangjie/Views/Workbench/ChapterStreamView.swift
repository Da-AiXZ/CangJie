//
//  ChapterStreamView.swift
//  Cangjie
//
//  中栏替代视图：自动驾驶章节生成时显示。
//  SSE 接收 chapter-stream SSE 逐 token 拼接渲染，
//  ScrollViewReader 自动滚底，节拍进度指示。
//  对齐 Vue3 AutopilotWritingStream.vue 的逐 token 渲染 + 自动滚底。
//

import SwiftUI

/// 章节生成流视图
struct ChapterStreamView: View {

    @EnvironmentObject var autopilotStore: AutopilotStore

    /// 当前拼接的内容
    @State private var accumulatedContent: String = ""

    /// 自动滚底
    @State private var autoScroll: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            streamStatusBar

            // 内容流
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        if accumulatedContent.isEmpty {
                            // 等待状态
                            HStack(spacing: Theme.Spacing.sm) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("等待 AI 生成…")
                                    .font(Theme.bodyFont())
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(Theme.Spacing.xl)
                        } else {
                            // 逐 token 渲染
                            Text(accumulatedContent)
                                .font(Theme.editorFont(scale: Theme.ipadScale))
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("bottom")

                            // 流式光标
                            Text("▎")
                                .font(Theme.editorFont(scale: Theme.ipadScale))
                                .foregroundColor(Theme.primary)
                                .id("cursor")
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .background(Theme.background)
                .onChange(of: accumulatedContent) { _ in
                    if autoScroll {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("cursor", anchor: .bottom)
                        }
                    }
                }
            }

            // 底部操作栏
            bottomBar
        }
        .background(Theme.background)
        .navigationTitle("章节生成流")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startListening()
        }
        .onDisappear {
            accumulatedContent = ""
        }
    }

    // MARK: - 顶部状态栏

    private var streamStatusBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // SSE 连接状态
            Circle()
                .fill(autopilotStore.sseConnected ? Theme.success : Theme.error)
                .frame(width: 8, height: 8)

            Text(autopilotStore.sseConnected ? "流式已连接" : "流式未连接")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)

            Divider()
                .frame(height: 16)

            // 当前章节
            if let chapterNum = autopilotStore.currentChapterNumber {
                Text("第\(chapterNum)章")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.primary)
            }

            // 当前阶段
            if let substep = autopilotStore.status?.writingSubstepLabel, !substep.isEmpty {
                Text(substep)
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.info.opacity(0.2))
                    .cornerRadius(4)
            }

            Spacer()

            // 本章字数
            if let status = autopilotStore.status {
                Text("\(status.totalWords) 字")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 底部操作栏

    private var bottomBar: some View {
        HStack {
            // 自动滚底 Toggle
            Toggle("自动滚底", isOn: $autoScroll)
                .font(.system(size: 12))
                .toggleStyle(.switch)
                .controlSize(.mini)

            Spacer()

            // 清空
            Button("清空") {
                accumulatedContent = ""
            }
            .font(.system(size: 12))
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    // MARK: - SSE 监听

    /// 监听 AutopilotStore 的章节事件，逐 token 拼接
    private func startListening() {
        // AutopilotStore 已经在订阅 chapterStream，我们监听其 chapterEvents 数组变化
        // 使用 Timer 轮询检查新事件（简化实现，实际可用 Combine sink）
        Task {
            var lastProcessedIndex = -1
            while !Task.isCancelled {
                let events = autopilotStore.chapterEvents
                for index in (lastProcessedIndex + 1)..<events.count {
                    let event = events[index]
                    if let content = event.content {
                        accumulatedContent.append(content)
                    }
                    if event.done == true {
                        // 章节生成完成
                        break
                    }
                }
                lastProcessedIndex = events.count - 1
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }
    }
}
