//
//  KnowledgeJsonView.swift
//  Cangjie
//
//  知识图谱 JSON 查看/编辑模式，对齐原版 components/knowledge/KnowledgeJsonView.vue:1-136。
//  KnowledgePanel.vue:113 子组件，knowledgeView === 'json' 时显示。
//  工具栏：保存JSON + 格式化；TextEditor 编辑 facts 数组 JSON。
//  加载：GET /novels/{id}/knowledge → 提取 facts → JSON 序列化显示。
//  保存：校验数组 → PUT /novels/{id}/knowledge → onReload 回调。
//

import SwiftUI

/// 知识图谱 JSON 查看/编辑模式
///
/// 对齐原版 `components/knowledge/KnowledgeJsonView.vue`。
/// 设计为可独立运行的子组件，接收 novelId 参数 + onReload 回调。
/// 未来嵌入 KnowledgePanel 时直接使用。
struct KnowledgeJsonView: View {

    // MARK: - 参数（对齐原版 :29-30 props/emit）

    /// 小说 ID（对齐 :29 props.slug）
    let novelId: String

    /// 刷新回调（对齐 :30 emit('reload')）
    let onReload: () -> Void

    // MARK: - 状态（对齐原版 :33-38）

    /// 是否正在保存（对齐 :33 saving = ref(false)）
    @State private var saving: Bool = false

    /// JSON 文本（对齐 :34 jsonText = ref('')）
    @State private var jsonText: String = ""

    /// JSON 错误信息（对齐 :35 jsonError = ref('')）
    @State private var jsonError: String = ""

    /// 故事版本号（对齐 :36 storyVersion = ref(1)）
    /// 保存时回传，保持乐观锁
    @State private var storyVersion: Int = 1

    /// 梗概锁定（对齐 :37 premiseLock = ref('')）
    /// 保存时回传，不修改
    @State private var premiseLock: String = ""

    /// 章节快照（对齐 :38 chaptersSnapshot = ref<ChapterSummary[]>([])）
    /// 保存时回传，不修改
    @State private var chaptersSnapshot: [ChapterSummaryDTO] = []

    /// 是否正在加载（iOS 补充，原版无此状态）
    @State private var isLoading: Bool = false

    /// 是否显示成功提示
    @State private var showSuccessMessage: Bool = false

    /// 成功提示文本
    @State private var successMessage: String = ""

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏（对齐 :3-8）
            toolbar

            // JSON 编辑器（对齐 :9-16）
            jsonEditor

            // 错误提示（对齐 :17-19）
            if !jsonError.isEmpty {
                errorLabel
            }
        }
        .background(Theme.background)
        .overlay(alignment: .top) {
            if showSuccessMessage {
                successBanner
            }
        }
        .task {
            await reload()
        }
    }

    // MARK: - 工具栏（对齐 :3-8）

    private var toolbar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button(action: {
                Task { await saveJson() }
            }) {
                if saving {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }
                Text("保存 JSON")
                    .font(Theme.captionFont())
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(saving || isLoading)

            Button(action: formatJson) {
                Text("格式化")
                    .font(Theme.captionFont())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(saving)

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                Text("加载中…")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    // MARK: - JSON 编辑器（对齐 :9-16）

    private var jsonEditor: some View {
        TextEditor(text: $jsonText)
            .font(.system(size: 13, design: .monospaced))
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding(.horizontal, Theme.Spacing.xs)
            .background(
                jsonError.isEmpty
                    ? Color(.systemBackground)
                    : Color(.systemBackground).opacity(0.8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(jsonError.isEmpty ? Color.clear : Theme.error.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - 错误提示（对齐 :17-19）

    private var errorLabel: some View {
        Text(jsonError)
            .font(Theme.captionFont())
            .foregroundColor(Theme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(Theme.error.opacity(0.05))
    }

    // MARK: - 成功提示

    private var successBanner: some View {
        Text(successMessage)
            .font(Theme.captionFont())
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.success)
            .cornerRadius(Theme.CornerRadius.small)
            .padding(.top, Theme.Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - 数据加载（对齐原版 :40-51 reload）

    /// 从 API 加载叙事知识，提取 facts 序列化为 JSON 文本
    private func reload() async {
        isLoading = true
        jsonError = ""

        do {
            let knowledge: StoryKnowledge = try await APIClient.shared.request(
                APIEndpoint.Knowledge.get(novelId: novelId)
            )

            // 对齐 :43-46 — 提取 version, premise_lock, chapters, facts
            storyVersion = knowledge.version
            premiseLock = knowledge.premiseLock
            chaptersSnapshot = knowledge.chapters

            // 对齐 :46 — JSON.stringify(data.facts || [], null, 2)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let factsData = try encoder.encode(knowledge.facts)
            jsonText = String(data: factsData, encoding: .utf8) ?? "[]"
        } catch {
            // 对齐 :48-50 — message.error(formatApiError(e, '加载失败'))
            jsonError = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 格式化 JSON（对齐原版 :53-61 formatJson）

    /// 格式化 JSON 文本：解析后重新序列化
    private func formatJson() {
        guard let data = jsonText.data(using: .utf8) else {
            jsonError = "JSON 格式错误: 无法解析文本"
            return
        }

        do {
            // 对齐 :54-55 — JSON.parse(jsonText)
            let parsed = try JSONSerialization.jsonObject(with: data, options: [])

            // 对齐 :56 — JSON.stringify(parsed, null, 2)
            let prettyData = try JSONSerialization.data(
                withJSONObject: parsed,
                options: [.prettyPrinted, .sortedKeys]
            )
            jsonText = String(data: prettyData, encoding: .utf8) ?? jsonText
            jsonError = ""
        } catch {
            // 对齐 :58-60 — jsonError = `JSON 格式错误: ${e.message}`
            jsonError = "JSON 格式错误: \(error.localizedDescription)"
        }
    }

    // MARK: - 保存 JSON（对齐原版 :63-91 saveJson）

    /// 校验 JSON 数组格式并保存到后端
    private func saveJson() async {
        // 对齐 :64-65 — JSON.parse(jsonText)
        guard let data = jsonText.data(using: .utf8) else {
            jsonError = "JSON 格式错误: 无法解析文本"
            return
        }

        // 对齐 :66-69 — 校验 Array.isArray
        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: [])
            guard let array = parsed as? [Any] else {
                jsonError = "JSON 必须是数组格式"
                return
            }

            // 将解析后的数组转回 Data，再解码为 [KnowledgeTriple]
            let arrayData = try JSONSerialization.data(withJSONObject: array, options: [])
            let facts: [KnowledgeTriple] = try CangjieDecoder.shared.decode([KnowledgeTriple].self, from: arrayData)

            jsonError = ""
            saving = true

            // 对齐 :72-78 — PUT /novels/{slug}/knowledge with { version, premise_lock, chapters, facts }
            let body = StoryKnowledge(
                version: storyVersion,
                premiseLock: premiseLock,
                chapters: chaptersSnapshot,
                facts: facts
            )

            let _: StoryKnowledge = try await APIClient.shared.request(
                APIEndpoint.Knowledge.update(novelId: novelId),
                body: body
            )

            // 对齐 :79 — message.success('已保存')
            showSuccess(message: "已保存")

            // 对齐 :80 — emit('reload')
            onReload()

            // 对齐 :81 — await reload()
            await reload()
        } catch let decodingError as DecodingError {
            // 对齐 :83-84 — JSON 格式错误
            jsonError = "JSON 格式错误: \(decodingError.localizedDescription)"
        } catch {
            // 对齐 :85-86 — message.error(formatApiError(e, '保存失败'))
            jsonError = "保存失败: \(error.localizedDescription)"
        }

        saving = false
    }

    // MARK: - 辅助

    /// 显示成功提示（2秒后自动消失）
    private func showSuccess(message: String) {
        successMessage = message
        withAnimation(.easeInOut(duration: 0.25)) {
            showSuccessMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showSuccessMessage = false
            }
        }
    }
}
