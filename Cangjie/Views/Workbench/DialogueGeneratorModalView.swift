//
//  DialogueGeneratorModalView.swift
//  Cangjie
//
//  对话沙盒，对齐原版 components/workbench/DialogueGeneratorModal.vue:1-207。
//  角色选择+锚点展示+场景输入+生成对话+复制。
//

import SwiftUI

/// 对话沙盒视图
///
/// 对齐原版 `components/workbench/DialogueGeneratorModal.vue`。
struct DialogueGeneratorModalView: View {

    /// 小说 ID（对齐 :92 props.novelId）
    let novelId: String

    /// 是否显示（对齐 :95 v-model show）
    @Binding var show: Bool

    // MARK: - 状态

    @StateObject private var bibleStore = BibleStore()
    private let apiClient = APIClient.shared

    @State private var selectedCharacterId: String?
    @State private var characterAnchor: CharacterAnchor?
    @State private var scenePrompt: String = ""
    @State private var generating: Bool = false
    @State private var generatedDialogue: String = ""
    @State private var generatedCharacterName: String = ""
    @State private var loadingCharacters: Bool = false
    @State private var loadError: String?

    // MARK: - 计算属性

    /// 角色选项（对齐 :108-113 characterOptions）
    private var characterOptions: [CharacterDTO] {
        return bibleStore.bible?.characters ?? []
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // 对齐 :5-13 角色选择
                Section("选择角色") {
                    if loadingCharacters {
                        ProgressView("加载角色列表…")
                    } else {
                        Picker("角色", selection: $selectedCharacterId) {
                            Text("选择要生成对话的角色").tag(nil as String?)
                            ForEach(characterOptions) { char in
                                Text(char.name).tag(Optional(char.id))
                            }
                        }
                        .onChange(of: selectedCharacterId) { newId in
                            if let id = newId {
                                Task { await loadCharacterAnchor(id) }
                            } else {
                                characterAnchor = nil
                            }
                        }
                    }
                }

                // 对齐 :16-30 角色锚点展示
                if let anchor = characterAnchor {
                    Section("🎭 角色锚点") {
                        LabeledContent("心理状态") {
                            Text(anchor.mentalState)
                                .font(.system(size: 12))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(mentalStateColor(anchor.mentalState).opacity(0.15))
                                .cornerRadius(4)
                                .foregroundColor(mentalStateColor(anchor.mentalState))
                        }
                        LabeledContent("口头禅") {
                            Text("「\(anchor.verbalTic)」")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        LabeledContent("待机动作") {
                            Text(anchor.idleBehavior)
                                .font(.system(size: 12))
                        }
                    }
                }

                // 对齐 :33-40 场景描述
                Section("场景描述") {
                    TextEditor(text: $scenePrompt)
                        .frame(minHeight: 60)
                }

                // 对齐 :43-54 生成按钮
                Section {
                    Button {
                        Task { await generateDialogue() }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("生成对话")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(selectedCharacterId == nil || scenePrompt.isEmpty || generating)
                }

                // 对齐 :57-80 生成结果
                if !generatedDialogue.isEmpty {
                    Section("生成结果") {
                        TextEditor(text: $generatedDialogue)
                            .frame(minHeight: 120)

                        HStack {
                            Button {
                                Task { await generateDialogue() }
                            } label: {
                                Label("重新生成", systemImage: "arrow.clockwise")
                            }

                            Spacer()

                            Button {
                                UIPasteboard.general.string = generatedDialogue
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }

                if let err = loadError {
                    Section {
                        Text(err)
                            .foregroundColor(Theme.error)
                    }
                }
            }
            .navigationTitle("💬 对话沙盒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { show = false }
                }
            }
        }
        .onAppear {
            if characterOptions.isEmpty {
                loadCharacters()
            }
        }
    }

    // MARK: - 加载角色列表（对齐 :116-128 loadCharacters）

    private func loadCharacters() {
        guard !novelId.isEmpty else { return }
        loadingCharacters = true
        Task {
            await bibleStore.loadBible(novelId: novelId)
            loadingCharacters = false
        }
    }

    // MARK: - 加载角色锚点（对齐 :131-144 loadCharacterAnchor）

    private func loadCharacterAnchor(_ charId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.Sandbox.characterAnchor(novelId: novelId, characterId: charId)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                characterAnchor = try? CangjieDecoder.shared.decode(CharacterAnchor.self, from: data)
            }
        } catch {
            loadError = "加载角色锚点失败"
        }
    }

    // MARK: - 生成对话（对齐 :147-172 generateDialogue）

    private func generateDialogue() async {
        guard let charId = selectedCharacterId, !scenePrompt.isEmpty else { return }
        generating = true
        loadError = nil

        do {
            // 对齐 :155-162 sandboxApi.generateDialogue
            // 请求体包含 novel_id, character_id, scene_prompt, mental_state, verbal_tic, idle_behavior
            let requestBody: [String: Any] = [
                "novel_id": novelId,
                "character_id": charId,
                "scene_prompt": scenePrompt,
                "mental_state": characterAnchor?.mentalState ?? "",
                "verbal_tic": characterAnchor?.verbalTic ?? "",
                "idle_behavior": characterAnchor?.idleBehavior ?? ""
            ]
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.Sandbox.generateDialogue(novelId: novelId),
                body: AnyCodable(requestBody)
            )
            if let dict = raw.dictionaryValue {
                generatedDialogue = dict["dialogue"]?.stringStringValue ?? ""
                generatedCharacterName = dict["character_name"]?.stringStringValue ?? ""
            }
        } catch {
            loadError = "生成对话失败"
        }

        generating = false
    }

    // MARK: - 心理状态颜色（对齐 :193-199 getMentalStateColor）

    private func mentalStateColor(_ state: String) -> Color {
        let lower = state.lowercased()
        if lower.contains("平静") || lower.contains("冷静") { return Theme.success }
        if lower.contains("焦虑") || lower.contains("紧张") { return Theme.warning }
        if lower.contains("愤怒") || lower.contains("恐惧") { return Theme.error }
        return Theme.info
    }
}
