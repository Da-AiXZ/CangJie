//
//  ActPlanningModalView.swift
//  Cangjie
//
//  幕规划弹窗，对齐原版 ActPlanningModal.vue:1-428。
//  4阶段状态机(form/stream/edit/error) + SSE流式幕级章节规划。
//

import SwiftUI
import Foundation

/// 幕规划弹窗 — ActPlanningModal.vue:1-428
struct ActPlanningModalView: View {
    // MARK: - Props

    let actId: String
    let actTitle: String

    @Binding var isPresented: Bool

    // MARK: - UI 阶段 — ActPlanningModal.vue:188-189

    enum UiPhase: String {
        case form, stream, edit, error
    }

    @State private var uiPhase: UiPhase = .form

    // MARK: - Form 状态

    @State private var chapterCount: Int = 3

    // MARK: - Stream 状态 — ActPlanningModal.vue:196-201

    @State private var statusMessage: String = "正在连接…"
    @State private var progressPct: Double = 0
    @State private var expectedChapters: Int = 0
    @State private var streamPreview: [ChapterDraft] = []
    @State private var llmStreamPreview: String = ""
    @State private var streamError: String = ""

    // MARK: - Edit 状态 — ActPlanningModal.vue:193

    @State private var chapters: [ChapterDraft] = []
    @State private var confirming: Bool = false

    // MARK: - SSE

    private let sseClient = SSEClient()
    private var streamTask: Task<Void, Never>?

    // MARK: - Computed — ActPlanningModal.vue:205-213

    private var modalHeadline: String {
        "规划章节 — \(actTitle)"
    }

    /// 骨架占位数 — ActPlanningModal.vue:207-213
    private var skeletonCount: Int {
        guard uiPhase == .stream else { return 0 }
        let exp = expectedChapters
        let got = streamPreview.count
        if exp == 0 {
            return min(6, max(2, got + 2))
        }
        return min(20, max(0, exp - got))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                switch uiPhase {
                case .form:
                    formPhase
                case .stream:
                    streamPhase
                case .edit:
                    editPhase
                case .error:
                    errorPhase
                }
            }
            .navigationTitle(modalHeadline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        close()
                    }
                }
            }
        }
        .onDisappear {
            abortStream()
        }
    }

    // MARK: - Form 阶段 — ActPlanningModal.vue:24-44

    private var formPhase: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 提示 — ActPlanningModal.vue:26-28
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Theme.info)
                Text("AI 将根据本幕的叙事目标与 Bible 信息，自动为每章生成标题和大纲。生成时可看到流式骨架与占位。")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.info.opacity(0.08))
            .cornerRadius(8)

            // 章节数输入 — ActPlanningModal.vue:30-38
            HStack {
                Text("本幕章节数")
                    .font(.system(size: 14))
                Stepper(value: $chapterCount, in: 2...20) {
                    Text("\(chapterCount)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.primary)
                }
                Spacer()
            }

            Spacer()

            // 按钮区 — ActPlanningModal.vue:40-43
            HStack {
                Spacer()
                Button("AI 生成章节规划") {
                    startStream()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - Stream 阶段 — ActPlanningModal.vue:46-99

    private var streamPhase: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // 进度条 — ActPlanningModal.vue:48-50
            VStack(spacing: 4) {
                HStack {
                    Circle()
                        .fill(Theme.primary)
                        .frame(width: 6, height: 6)
                        .opacity(0.8)
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.primary)
                    Spacer()
                    Text("\(Int(progressPct))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.textTertiary.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.primary)
                            .frame(width: geo.size.width * (progressPct / 100), height: 4)
                            .animation(.easeInOut(duration: 0.35), value: progressPct)
                    }
                }
                .frame(height: 4)
            }

            // LLM 原始输出预览 — ActPlanningModal.vue:52-59
            if !llmStreamPreview.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("模型输出")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    ScrollView {
                        Text(llmStreamPreview)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 160)
                    .background(Theme.tertiaryBackground)
                }
                .background(Theme.tertiaryBackground)
                .cornerRadius(8)
            }

            // 流式章节卡片 — ActPlanningModal.vue:61-93
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(streamPreview.enumerated()), id: \.offset) { idx, ch in
                        streamChapterCard(ch: ch, idx: idx)
                    }
                    // 骨架占位 — ActPlanningModal.vue:81-93
                    ForEach(0..<skeletonCount, id: \.self) { _ in
                        skeletonCard()
                    }
                }
                .padding(.trailing, 4)
            }

            // 取消按钮 — ActPlanningModal.vue:96-98
            HStack {
                Spacer()
                Button("取消生成") {
                    abortStream()
                }
                .buttonStyle(.borderless)
                .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.lg)
    }

    /// 流式章节卡片 — ActPlanningModal.vue:63-79
    private func streamChapterCard(ch: ChapterDraft, idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ch.title.isEmpty ? "第 \(idx + 1) 章" : ch.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text(ch.outline.isEmpty ? "（无大纲）" : ch.outline)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            if !ch.bibleElements.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ch.bibleElements, id: \.self) { el in
                            Text(el)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.primary.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(Theme.primary)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 骨架占位卡 — ActPlanningModal.vue:81-93
    private func skeletonCard() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.textTertiary.opacity(0.15))
                .frame(width: 120, height: 12)
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.textTertiary.opacity(0.1))
                .frame(height: 8)
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.textTertiary.opacity(0.1))
                .frame(width: 200, height: 8)
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Edit 阶段 — ActPlanningModal.vue:101-144

    private var editPhase: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 成功提示 — ActPlanningModal.vue:103-105
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.success)
                Text("已生成 \(chapters.count) 章规划，可在下方直接修改标题或大纲后确认。")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.success.opacity(0.08))
            .cornerRadius(8)

            // 章节编辑列表 — ActPlanningModal.vue:107-137
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { idx, _ in
                        chapterEditCard(idx: idx)
                    }
                }
            }

            // 按钮区 — ActPlanningModal.vue:139-143
            HStack(spacing: 10) {
                Button("重新生成") {
                    backToForm()
                }
                .disabled(confirming)
                Spacer()
                Button("确认并保存") {
                    Task { await confirm() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(confirming)
            }
        }
        .padding(Theme.Spacing.lg)
    }

    /// 章节编辑卡 — ActPlanningModal.vue:109-135
    private func chapterEditCard(idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("章节标题", text: Binding(
                get: { chapters[idx].title },
                set: { chapters[idx].title = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 13))
            .disabled(confirming)

            ZStack(alignment: .topLeading) {
                if chapters[idx].outline.isEmpty {
                    Text("本章大纲")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                }
                TextEditor(text: Binding(
                    get: { chapters[idx].outline },
                    set: { chapters[idx].outline = $0 }
                ))
                .font(.system(size: 13))
                .frame(minHeight: 50)
                .disabled(confirming)
                .scrollContentBackground(.hidden)
            }
            .background(Theme.tertiaryBackground)
            .cornerRadius(6)

            if !chapters[idx].bibleElements.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(chapters[idx].bibleElements, id: \.self) { el in
                            Text(el)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.primary.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(Theme.primary)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Error 阶段 — ActPlanningModal.vue:146-153

    private var errorPhase: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Theme.error)
                Text(streamError.isEmpty ? "生成失败" : streamError)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.error.opacity(0.08))
            .cornerRadius(8)

            Spacer()

            HStack(spacing: 10) {
                Button("关闭") {
                    close()
                }
                Spacer()
                Button("返回") {
                    backToForm()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.Spacing.lg)
    }

    // MARK: - SSE 流式连接 — ActPlanningModal.vue:227-287

    /// 启动流式生成
    private func startStream() {
        // 重置状态
        streamPreview = []
        llmStreamPreview = ""
        statusMessage = "正在连接…"
        progressPct = 2
        streamError = ""
        expectedChapters = 0
        uiPhase = .stream

        streamTask = Task {
            await consumeSSE()
        }
    }

    /// 消费 SSE 流 — planning.ts:533-615
    private func consumeSSE() async {
        // 构建 URL — planning.ts:545-549
        let path = "/planning/acts/\(actId)/chapters/stream"
        guard let baseURL = APIConfig.shared.fullURL(path: path, prefix: APIConfig.apiV1Prefix) else {
            await MainActor.run {
                streamError = "无法构建请求 URL"
                uiPhase = .error
            }
            return
        }

        let url: URL
        if chapterCount > 0 {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "chapter_count", value: "\(chapterCount)")]
            url = components?.url ?? baseURL
        } else {
            url = baseURL
        }

        do {
            let stream = sseClient.connect(url: url)
            for try await event in stream {
                if Task.isCancelled { break }

                let eventName = event.event ?? ""
                guard let dict = event.decodeAsDictionary() else { continue }

                switch eventName {
                case "status":
                    await handleStatus(dict)
                case "chunk":
                    handleChunk(dict)
                case "chapter":
                    handleChapter(dict)
                case "done":
                    await handleDone(dict)
                    return
                case "error":
                    let msg = dict["message"] as? String ?? "未知错误"
                    await MainActor.run {
                        streamError = msg
                        uiPhase = .error
                    }
                    return
                default:
                    break
                }
            }
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    streamError = error.localizedDescription
                    uiPhase = .error
                }
            }
        }
    }

    /// 处理 status 事件 — ActPlanningModal.vue:240-250
    @MainActor
    private func handleStatus(_ dict: [String: Any]) {
        if let message = dict["message"] as? String {
            statusMessage = message
        }
        if let percent = dict["percent"] as? Double {
            progressPct = percent
        } else if let percent = dict["percent"] as? Int {
            progressPct = Double(percent)
        }
        if let expected = dict["expected_chapters"] as? Int, expected > 0 {
            expectedChapters = expected
        }
        if let phase = dict["phase"] as? String, phase == "streaming" {
            progressPct = max(progressPct, 90)
            llmStreamPreview = ""
        }
    }

    /// 处理 chunk 事件 — ActPlanningModal.vue:251-258
    private func handleChunk(_ dict: [String: Any]) {
        if let text = dict["text"] as? String, !text.isEmpty {
            Task { @MainActor in
                llmStreamPreview += text
            }
        }
    }

    /// 处理 chapter 事件 — ActPlanningModal.vue:259-264
    private func handleChapter(_ dict: [String: Any]) {
        let draft = mapRawToDraft(dict)
        Task { @MainActor in
            streamPreview.append(draft)
        }
    }

    /// 处理 done 事件 — ActPlanningModal.vue:265-278
    @MainActor
    private func handleDone(_ dict: [String: Any]) {
        let rawChapters = dict["chapters"] as? [[String: Any]] ?? []
        chapters = rawChapters.map { mapRawToDraft($0) }

        if chapters.isEmpty {
            streamError = "AI 未返回章节数据"
            uiPhase = .error
            return
        }

        progressPct = 100
        streamPreview = []
        uiPhase = .edit
    }

    /// 原始字典转 ChapterDraft — ActPlanningModal.vue:215-225
    private func mapRawToDraft(_ c: [String: Any]) -> ChapterDraft {
        let title = (c["title"] as? String) ?? ""
        let outline = (c["outline"] as? String) ?? (c["description"] as? String) ?? ""
        let bibleElements = (c["bible_elements"] as? [String]) ?? []
        return ChapterDraft(title: title, outline: outline, bibleElements: bibleElements)
    }

    // MARK: - 生命周期 — ActPlanningModal.vue:289-349

    /// 中止流式生成 — ActPlanningModal.vue:289-295
    private func abortStream() {
        streamTask?.cancel()
        streamTask = nil
        if uiPhase == .stream {
            uiPhase = .form
            streamPreview = []
            llmStreamPreview = ""
        }
    }

    /// 返回 Form — ActPlanningModal.vue:297-305
    private func backToForm() {
        streamTask?.cancel()
        streamTask = nil
        uiPhase = .form
        chapters = []
        streamPreview = []
        llmStreamPreview = ""
        streamError = ""
    }

    /// 关闭弹窗 — ActPlanningModal.vue:307-309
    private func close() {
        streamTask?.cancel()
        streamTask = nil
        isPresented = false
    }

    /// 确认保存 — ActPlanningModal.vue:337-349
    private func confirm() async {
        confirming = true
        do {
            let request = ConfirmActChaptersRequest(chapters: chapters)
            let _: ConfirmActChaptersResponse = try await APIClient.shared.request(
                APIEndpoint.Planning.actChaptersConfirm(actId: actId),
                body: request
            )
            await MainActor.run {
                confirming = false
                isPresented = false
            }
        } catch {
            await MainActor.run {
                streamError = error.localizedDescription
                uiPhase = .error
                confirming = false
            }
        }
    }
}
