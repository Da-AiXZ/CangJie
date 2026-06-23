//
//  DialogueSandboxPanel.swift
//  Cangjie
//
//  对话沙盒（白名单角色+对话锚点+AI生成对话测试），调对应 Store。
//

import SwiftUI

struct DialogueSandboxPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var dialogues: [DialogueEntry] = []
    @State private var selectedCharacter: String = ""
    @State private var scenario: String = ""
    @State private var generatedDialogue: String = ""
    @State private var isGenerating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // 对话白名单
                if !dialogues.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("对话白名单", systemImage: "text.bubble.fill").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                        ForEach(dialogues.prefix(5)) { d in
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(d.speaker)（第\(d.chapter)章）").font(.system(size: 11, weight: .medium))
                                Text(d.content).font(.system(size: 10)).foregroundColor(Theme.textSecondary).lineLimit(2)
                            }
                        }
                    }
                }

                Divider()

                // AI 对话生成
                VStack(alignment: .leading, spacing: 4) {
                    Label("AI 对话测试", systemImage: "wand.and.stars").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)

                    TextField("角色 ID", text: $selectedCharacter)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    TextField("场景描述（可选）", text: $scenario, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .lineLimit(2...4)

                    Button {
                        Task { await generate() }
                    } label: {
                        Label(isGenerating ? "生成中…" : "生成对话", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(selectedCharacter.isEmpty || isGenerating)

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
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                do {
                    let response: DialogueWhitelistResponse = try await APIClient.shared.request(
                        APIEndpoint.Sandbox.dialogueWhitelist(novelId: novelId)
                    )
                    dialogues = response.dialogues
                } catch {}
            }
        }
    }

    private func generate() async {
        guard let novelId = appState.currentNovelId, !selectedCharacter.isEmpty else { return }
        isGenerating = true
        let request = GenerateDialogueRequest(characterId: selectedCharacter, scenario: scenario.isEmpty ? nil : scenario, context: nil, maxTurns: 3)
        do {
            let response: GenerateDialogueResponse = try await APIClient.shared.request(
                APIEndpoint.Sandbox.generateDialogue(novelId: novelId), body: request
            )
            generatedDialogue = response.dialogue
        } catch {
            generatedDialogue = "生成失败：\(error.localizedDescription)"
        }
        isGenerating = false
    }
}
