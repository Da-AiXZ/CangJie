//
//  ChapterWriterStreamView.swift
//  Cangjie
//
//  章节写作流，对齐原版 components/autopilot/ChapterWriterStream.vue:1-122。
//  SSE流式章节内容显示：脉冲点+章节号+stageLabel+字数+增量chunk追加+完整内容兜底。
//

import SwiftUI

/// 章节写作流视图
///
/// 对齐原版 `components/autopilot/ChapterWriterStream.vue`。
/// 监听 SSE chapter-stream，实时显示章节生成内容。
struct ChapterWriterStreamView: View {

    /// 小说 ID（对齐 :23 props.novelId）
    let novelId: String

    /// 是否正在写作（对齐 :24 props.isWriting）
    let isWriting: Bool

    /// 内容更新回调（对齐 :27-29 emit content-update）
    var onContentUpdate: ((Int, String, Int) -> Void)? = nil

    // MARK: - 状态

    /// 显示内容（对齐 :32 displayContent）
    @State private var displayContent: String = ""

    /// 当前章节号（对齐 :33 chapterNumber）
    @State private var chapterNumber: Int = 0

    /// 当前 beat 索引（对齐 :34 beatIndex）
    @State private var beatIndex: Int = 0

    /// 是否已启动 SSE
    @State private var streamStarted: Bool = false

    // MARK: - 依赖

    @EnvironmentObject private var autopilotStore: AutopilotStore

    // MARK: - 计算属性

    /// 字数（对齐 :35 wordCount）
    private var wordCount: Int { displayContent.count }

    /// stageLabel（对齐 :37-40）
    private var stageLabel: String {
        return beatIndex > 0 ? "正文撰写中" : ""
    }

    /// isVisible（对齐 :31）
    private var isVisible: Bool { isWriting }

    // MARK: - Body

    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // 对齐 :3-10 流式头部
                streamHeader

                // 对齐 :11-14 流式内容
                streamContent
            }
            .background(Theme.secondaryBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            .padding(.top, 8)
            .onChange(of: isWriting) { writing in
                // 对齐 :107-117 watch isWriting
                if writing {
                    startStream()
                } else {
                    stopStream()
                }
            }
            .onAppear {
                // 对齐 :116 immediate: true
                if isWriting && !streamStarted {
                    startStream()
                }
            }
            .onDisappear {
                // 对齐 :119-121 onUnmounted
                stopStream()
            }
        }
    }

    // MARK: - 流式头部（对齐 :3-10）

    private var streamHeader: some View {
        HStack(spacing: 8) {
            // 对齐 :4 pulse-dot
            Circle()
                .fill(Theme.success)
                .frame(width: 7, height: 7)

            // 对齐 :5-8 header-text
            HStack(spacing: 8) {
                Text("正在生成第 \(chapterNumber) 章")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                if !stageLabel.isEmpty {
                    Text(stageLabel)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.success.opacity(0.15))
                        .cornerRadius(4)
                        .foregroundColor(Theme.success)
                }
            }

            Spacer()

            // 对齐 :9 word-count
            Text("\(wordCount) 字")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.success.opacity(0.04))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.15)), alignment: .bottom)
    }

    // MARK: - 流式内容（对齐 :11-14）

    private var streamContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    Text(displayContent.isEmpty ? "等待生成…" : displayContent)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // 对齐 :13 cursor
                    Text("▋")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.success)
                }
                .padding(16)
                .id("streamBottom")
            }
            .frame(height: 200)
            .onChange(of: displayContent) { _ in
                // 对齐 :69-74 自动滚动到底部
                withAnimation {
                    proxy.scrollTo("streamBottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - SSE 流启停（对齐 :45-105）

    /// 启动流（对齐 :45-98 startStream）
    private func startStream() {
        guard !streamStarted else { return }
        streamStarted = true

        // 重置状态（对齐 :50-52）
        displayContent = ""
        chapterNumber = 0
        beatIndex = 0

        // 对齐 :54-97 chapterApi.subscribeStream → SSEStreamRegistry.startChapterStream
        let _ = SSEStreamRegistry.shared.startChapterStream(
            novelId: novelId,
            onEvent: { event in
                handleSSEEvent(event)
            },
            onError: { error in
                Logger.engine.error("Chapter stream error: \(error.localizedDescription)")
            }
        )
    }

    /// 停止流（对齐 :100-105 stopStream）
    private func stopStream() {
        guard streamStarted else { return }
        streamStarted = false
        SSEStreamRegistry.shared.cancelStream(type: .chapterStream, novelId: novelId)
    }

    // MARK: - SSE 事件处理（对齐 :55-97 callbacks）

    /// 处理 SSE 事件
    ///
    /// 对齐原版 onChapterStart/onChapterChunk/onChapterContent/onAutopilotStopped/onError 回调。
    private func handleSSEEvent(_ sseEvent: SSEEvent) {
        // 章节流使用 data-only 格式，解析为 ChapterStreamEvent
        guard let event = try? sseEvent.decode(ChapterStreamEvent.self) else { return }

        Task { @MainActor in
            switch event.type {
            case ChapterStreamEvent.typeChapterStart:
                // 对齐 :55-59 onChapterStart
                if let num = event.metadata?.chapterNumber {
                    chapterNumber = num
                }
                displayContent = ""
                beatIndex = 0

            case ChapterStreamEvent.typeChapterChunk:
                // 对齐 :61-75 onChapterChunk
                if let meta = event.metadata {
                    if let isSnapshot = meta.content, !isSnapshot.isEmpty {
                        // isSnapshot → 覆盖（:62-63）
                        // 原版 payload.isSnapshot 为布尔值，但 iOS metadata.content 是 String?
                        // 这里用 content 非空作为 snapshot 标志
                        displayContent = isSnapshot
                    } else if let chunk = meta.chunk {
                        // chunk → 追加（:64-65）
                        displayContent += chunk
                    }
                    if let bi = meta.beatIndex {
                        beatIndex = bi
                    }
                }

            case ChapterStreamEvent.typeChapterContent:
                // 对齐 :76-90 onChapterContent
                if let meta = event.metadata {
                    if let num = meta.chapterNumber {
                        chapterNumber = num
                    }
                    // 兜底：如果增量漏了，用完整内容覆盖（:79-81）
                    if let content = meta.content, content.count > displayContent.count {
                        displayContent = content
                    }
                    if let bi = meta.beatIndex {
                        beatIndex = bi
                    }
                    // 向父组件发送内容更新（:84-89）
                    onContentUpdate?(chapterNumber, displayContent, displayContent.count)
                }

            case ChapterStreamEvent.typeAutopilotStopped:
                // 对齐 :91-93 onAutopilotStopped — 停止时清理
                break

            default:
                break
            }
        }
    }
}
