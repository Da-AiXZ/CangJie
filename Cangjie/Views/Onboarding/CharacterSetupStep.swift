//
//  CharacterSetupStep.swift
//  Cangjie
//
//  向导第2步：角色创建（核心角色列表 + AI 生成 + 手动添加，
//  含名字/角色/核心信念/禁忌/声线/POV防火墙）。
//  对齐 Vue3 NovelSetupGuide.vue Step 2 的人物配置。
//

import SwiftUI

/// 角色创建步骤
struct CharacterSetupStep: View {

    @EnvironmentObject var store: OnboardingStore

    @State private var showAddSheet = false

    // 新角色表单
    @State private var newName = ""
    @State private var newDescription = ""
    @State private var newGender = ""
    @State private var newAge = ""
    @State private var newPersonality = ""
    @State private var newCoreMotivation = ""

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // 已有角色列表
                if let bible = store.bible, !bible.characters.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(bible.characters) { character in
                            characterCard(character)
                        }
                    }
                } else {
                    // 空状态
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textTertiary)

                        Text("暂无角色，点击下方添加")
                            .font(Theme.bodyFont())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, Theme.Spacing.xl)
                }

                // 添加角色按钮
                Button {
                    showAddSheet = true
                } label: {
                    Label("添加角色", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(Theme.Spacing.lg)
        }
        .sheet(isPresented: $showAddSheet) {
            addCharacterSheet
        }
    }

    // MARK: - 角色卡片

    private func characterCard(_ character: CharacterDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(character.name)
                    .font(Theme.headlineFont())

                if !character.gender.isEmpty || !character.age.isEmpty {
                    Text("[\(character.gender) \(character.age)]")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if let revealChapter = character.revealChapter {
                    Text("POV 第\(revealChapter)章揭示")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.warning.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if !character.description.isEmpty {
                Text(character.description)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
            }

            // 详细字段
            VStack(alignment: .leading, spacing: 4) {
                if !character.personality.isEmpty {
                    detailRow(label: "性格", value: character.personality)
                }
                if !character.coreMotivation.isEmpty {
                    detailRow(label: "核心动机", value: character.coreMotivation)
                }
                if !character.coreBelief.isEmpty {
                    detailRow(label: "核心信念", value: character.coreBelief)
                }
                if !character.verbalTic.isEmpty {
                    detailRow(label: "声线", value: character.verbalTic)
                }
                if !character.mentalState.isEmpty && character.mentalState != "NORMAL" {
                    detailRow(label: "心理状态", value: character.mentalState)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }

    // MARK: - 详情行

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - 添加角色 Sheet

    private var addCharacterSheet: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名字", text: $newName)
                    TextField("简介", text: $newDescription, axis: .vertical)
                        .lineLimit(3...6)

                    HStack {
                        TextField("性别", text: $newGender)
                        TextField("年龄", text: $newAge)
                    }
                }

                Section("性格与动机") {
                    TextField("性格特征", text: $newPersonality)
                    TextField("核心动机", text: $newCoreMotivation)
                }
            }
            .navigationTitle("添加角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        clearForm()
                        showAddSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        Task { await submitCharacter() }
                    }
                    .disabled(newName.isEmpty)
                }
            }
        }
    }

    // MARK: - 表单操作

    private func clearForm() {
        newName = ""
        newDescription = ""
        newGender = ""
        newAge = ""
        newPersonality = ""
        newCoreMotivation = ""
    }

    private func submitCharacter() async {
        let request = AddCharacterRequest(
            name: newName,
            description: newDescription,
            gender: newGender.isEmpty ? nil : newGender,
            age: newAge.isEmpty ? nil : newAge,
            personality: newPersonality.isEmpty ? nil : newPersonality,
            background: nil,
            coreMotivation: newCoreMotivation.isEmpty ? nil : newCoreMotivation
        )

        await store.addCharacter(request)
        clearForm()
        showAddSheet = false
    }
}
