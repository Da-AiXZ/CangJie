//
//  DialogueSandboxPanel.swift
//  Cangjie
//
//  对话沙盒（语料筛选+生成器+anchor读写+角色选择器），对齐 DialogueCorpus.vue:1-311 + sandbox.ts。
//

import SwiftUI

struct DialogueSandboxPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var novelStore: NovelStore
    @State private var dialogues: [DialogueEntry] = []
    @State private var totalCount: Int = 0
    @State private var loading = false

    // 筛选 — DialogueCorpus.vue:105-107
    @State private var filterChapter: Int? = nil
    @State private var filterSpeaker: String = ""
    @State private var searchText: String = ""

    // 角色选择 — DialogueCorpus.vue:92-96
    @State private var selectedCharacterId: String? = nil
    @State private var resolvedCharacterName: String = ""
    @State private var charOptions: [CharacterDTO] = []

    // AI 生成
    @State private var generatedDialogue: String = ""
    @State private var isGenerating = false

    // Anchor 读写 — sandbox.ts:57-72
    @State private var anchor: CharacterAnchor?
    @State private var anchorLoading = false
    @State private var showAnchorEdit = false
    @State private var anchorMentalState = ""
    @State private var anchorVerbalTic = ""
    @State private var anchorIdleBehavior = ""

    private var currentChapterNumber: Int? {
        // P2-13修复：从 NovelStore 获取当前章节号，不硬编码nil
        novelStore.currentChapter?.number
    }

    // 筛选后对话 — DialogueCorpus.vue:133-153
    private var filteredDialogues: [DialogueEntry] {
        var list = dialogues
        if let ch = filterChapter {
            list = list.filter { $0.chapter == ch }
        }
        if !filterSpeaker.isEmpty {
            list = list.filter { $0.speaker == filterSpeaker }
        }
        if !searchText.isEmpty {
            list = list.filter { $0.content.contains(searchText) }
        }
        return list
    }

    // 章节选项 — DialogueCorpus.vue:113-120
    private var chapterOptions: [Int] {
        Array(Set(dialogues.map { $0.chapter })).sorted()
    }

    // 说话人选项 — DialogueCorpus.vue:123-130
    private var speakerOptions: [String] {
        Array(Set(dialogues.map { $0.speaker })).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // 对话白名单区域
                dialogueWhitelistSection

                Divider()

                // AI 对话生成
                aiGenerationSection

                Divider()

                // 角色锚点
                anchorSection
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await loadAll(novelId: novelId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WorkbenchStore.deskTickNotification)) { _ in
            if let novelId = appState.currentNovelId {
                Task { await loadAll(novelId: novelId) }
            }
        }
        .onChange(of: appState.currentNovelId) { newId in
            if let novelId = newId {
                Task { await loadAll(novelId: novelId) }
            }
        }
        .sheet(isPresented: $showAnchorEdit) {
            anchorEditModal
        }
    }

    private func loadAll(novelId: String) async {
        await loadDialogues(novelId: novelId)
        await loadCharOptions(novelId: novelId)
    }

    // MARK: - 对话白名单 — DialogueCorpus.vue:1-82
    private var dialogueWhitelistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("对白语料").font(.system(size: 14, weight: .bold))
                    Text("正文自动抽取，用于声线对照").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                }
                Spacer()
                Button {
                    if let novelId = appState.currentNovelId {
                        Task { await loadDialogues(novelId: novelId) }
                    }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise").font(.system(size: 11))
                }
                .buttonStyle(.bordered).controlSize(.small)
            }

            // 筛选栏 — DialogueCorpus.vue:12-37
            HStack(spacing: 8) {
                Picker("章节", selection: $filterChapter) {
                    Text("全书").tag(Int?.none)
                    ForEach(chapterOptions, id: \.self) { ch in
                        Text("第\(ch)章").tag(Int?.some(ch))
                    }
                }
                .pickerStyle(.menu).controlSize(.small).frame(width: 110)

                Picker("说话人", selection: $filterSpeaker) {
                    Text("全部").tag("")
                    ForEach(speakerOptions, id: \.self) { sp in
                        Text(sp).tag(sp)
                    }
                }
                .pickerStyle(.menu).controlSize(.small).frame(width: 100)

                TextField("搜索...", text: $searchText)
                    .textFieldStyle(.roundedBorder).controlSize(.small)
            }

            // 对话列表 — DialogueCorpus.vue:56-71
            if loading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if totalCount == 0 {
                Text("暂无对话数据，生成章节后自动提取")
                    .font(.system(size: 11)).foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity).padding()
            } else if filteredDialogues.isEmpty {
                Text("无匹配对话")
                    .font(.system(size: 11)).foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity).padding()
            } else {
                ForEach(filteredDialogues) { d in
                    dialogueItem(d)
                }
                // 底部统计 — DialogueCorpus.vue:75-79
                Text("\(filteredDialogues.count) / \(totalCount) 条对话")
                    .font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dialogueItem(_ d: DialogueEntry) -> some View {
        let isHighlight = !resolvedCharacterName.isEmpty && d.speaker.trimmingCharacters(in: .whitespaces) == resolvedCharacterName
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("第\(d.chapter)章")
                    .font(.system(size: 9))
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Theme.tertiaryBackground).cornerRadius(10)
                Text(d.speaker)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.success)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Theme.success.opacity(0.12)).cornerRadius(10)
            }
            Text(d.content)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(3)
        }
        .padding(8)
        .background(isHighlight ? Theme.primary.opacity(0.04) : Theme.secondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHighlight ? Theme.primary : Color.clear, lineWidth: 1)
        )
        .cornerRadius(4)
    }

    // MARK: - AI 对话生成 — DialogueSandboxPanel.swift 原有
    private var aiGenerationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI 对话测试", systemImage: "wand.and.stars")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)

            // 角色选择器 — 决策9
            Picker("角色", selection: $selectedCharacterId) {
                Text("选择角色").tag(String?.none)
                ForEach(charOptions) { ch in
                    Text(ch.name).tag(String?.some(ch.id))
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedCharacterId) { newId in
                Task {
                    if let id = newId, let novelId = appState.currentNovelId {
                        await loadAnchor(novelId: novelId, characterId: id)
                        await syncCharacterName(novelId: novelId, characterId: id)
                    }
                }
            }

            Button {
                Task { await generate() }
            } label: {
                Label(isGenerating ? "生成中…" : "生成对话", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedCharacterId == nil || isGenerating)

            if !generatedDialogue.isEmpty {
                Text(generatedDialogue)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.tertiaryBackground)
                    .cornerRadius(Theme.CornerRadius.small)
            }
        }
    }

    // MARK: - 角色锚点 — sandbox.ts:57-72
    private var anchorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("角色锚点", systemImage: "anchor.fill")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                Spacer()
                if anchor != nil {
                    Button("编辑") { showAnchorEdit = true }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }

            if anchorLoading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if let anchor = anchor {
                VStack(alignment: .leading, spacing: 4) {
                    anchorRow("心理状态", anchor.mentalState)
                    anchorRow("口头禅", anchor.verbalTic)
                    anchorRow("闲置行为", anchor.idleBehavior)
                }
            } else if selectedCharacterId != nil {
                Text("无锚点数据，点击「编辑」创建")
                    .font(.system(size: 11)).foregroundColor(Theme.textTertiary)
            } else {
                Text("选择角色后查看锚点")
                    .font(.system(size: 11)).foregroundColor(Theme.textTertiary)
            }
        }
    }

    private func anchorRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 10)).foregroundColor(Theme.textTertiary)
            Text(value.isEmpty ? "—" : value).font(.system(size: 11))
        }
    }

    // MARK: - Anchor 编辑弹窗 — sandbox.ts:63-72
    private var anchorEditModal: some View {
        NavigationStack {
            Form {
                Section("角色锚点") {
                    TextField("心理状态", text: $anchorMentalState, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(2...4)
                    TextField("口头禅", text: $anchorVerbalTic, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(2...4)
                    TextField("闲置行为", text: $anchorIdleBehavior, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(2...4)
                }
            }
            .navigationTitle("编辑角色锚点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAnchorEdit = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await saveAnchor() } }
                }
            }
        }
    }

    // MARK: - 数据加载

    private func loadDialogues(novelId: String) async {
        loading = true
        do {
            let response: DialogueWhitelistResponse = try await APIClient.shared.request(
                APIEndpoint.Sandbox.dialogueWhitelist(novelId: novelId)
            )
            dialogues = response.dialogues
            totalCount = response.totalCount
        } catch {
            dialogues = []
            totalCount = 0
        }
        loading = false
    }

    private func loadCharOptions(novelId: String) async {
        do {
            charOptions = try await APIClient.shared.request(
                APIEndpoint.Bible.characters(novelId: novelId)
            )
        } catch {
            charOptions = []
        }
    }

    private func syncCharacterName(novelId: String, characterId: String) async {
        if let ch = charOptions.first(where: { $0.id == characterId }) {
            resolvedCharacterName = ch.name.trimmingCharacters(in: .whitespaces)
            filterSpeaker = resolvedCharacterName
        } else {
            resolvedCharacterName = ""
            filterSpeaker = ""
        }
    }

    private func loadAnchor(novelId: String, characterId: String) async {
        anchorLoading = true
        do {
            anchor = try await APIClient.shared.request(
                APIEndpoint.Sandbox.characterAnchor(novelId: novelId, characterId: characterId)
            )
            if let a = anchor {
                anchorMentalState = a.mentalState
                anchorVerbalTic = a.verbalTic
                anchorIdleBehavior = a.idleBehavior
            }
        } catch {
            anchor = nil
        }
        anchorLoading = false
    }

    private func saveAnchor() async {
        guard let novelId = appState.currentNovelId, let characterId = selectedCharacterId else { return }
        let request = PatchCharacterAnchorRequest(
            mentalState: anchorMentalState,
            verbalTic: anchorVerbalTic,
            idleBehavior: anchorIdleBehavior
        )
        do {
            let updated: CharacterAnchor = try await APIClient.shared.request(
                APIEndpoint.Sandbox.patchCharacterAnchor(novelId: novelId, characterId: characterId),
                body: request
            )
            anchor = updated
            showAnchorEdit = false
        } catch {
            // 静默失败
        }
    }

    private func generate() async {
        guard let novelId = appState.currentNovelId, let characterId = selectedCharacterId else { return }
        isGenerating = true
        // P0-9.3：GenerateDialogueRequest 字段对齐原版 sandbox.ts:30-37
        // novel_id/character_id/scene_prompt（必填）+ mental_state/verbal_tic/idle_behavior（可选，从角色锚点获取）
        let request = GenerateDialogueRequest(
            novelId: novelId,
            characterId: characterId,
            scenePrompt: "",
            mentalState: anchor?.mentalState,
            verbalTic: anchor?.verbalTic,
            idleBehavior: anchor?.idleBehavior
        )
        do {
            let response: GenerateDialogueResponse = try await APIClient.shared.request(
                APIEndpoint.Sandbox.generateDialogue, body: request
            )
            generatedDialogue = response.dialogue
        } catch {
            generatedDialogue = "生成失败：\(error.localizedDescription)"
        }
        isGenerating = false
    }
}
