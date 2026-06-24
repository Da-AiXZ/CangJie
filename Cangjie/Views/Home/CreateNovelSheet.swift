//
//  CreateNovelSheet.swift
//  Cangjie
//
//  新建小说表单 sheet：标题/简介/默认章数/每章字数/题材包选择。
//  提交后调 NovelStore.createNovel()，成功后回调进入 Onboarding。
//  对齐 Vue3 Home.vue 的 create-card 交互。
//

import SwiftUI

/// 新建小说表单 Sheet
struct CreateNovelSheet: View {

    /// 创建成功回调
    var onCreated: (NovelDTO) -> Void

    @EnvironmentObject var novelStore: NovelStore
    @Environment(\.dismiss) private var dismiss

    // MARK: - 表单状态

    @State private var title: String = ""
    @State private var premise: String = ""
    @State private var targetChapters: Int = 100
    @State private var targetWordsPerChapter: Int = 2500
    @State private var genre: String = ""
    @State private var worldPreset: String = ""
    @State private var storyStructure: String = ""
    @State private var pacingControl: String = ""
    @State private var writingStyle: String = ""
    @State private var specialRequirements: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    /// 篇幅档位
    @State private var lengthTier: String? = "standard"

    // MARK: - 篇幅选项

    private let lengthTierOptions = [
        ("short", "短篇", "约 30 万字"),
        ("standard", "标准", "约 100 万字"),
        ("epic", "史诗", "约 300 万字"),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // 基本信息
                Section("基本信息") {
                    TextField("书名（留空则从梗概截取）", text: $title)

                    ZStack(alignment: .topLeading) {
                        if premise.isEmpty {
                            Text("用一段话写清主线与爽点预期（不超过 2000 字）…")
                                .foregroundColor(Theme.textTertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $premise)
                            .frame(minHeight: 100)
                    }
                }

                // 题材包 — 对齐 MarketTaxonomyPicker.vue 6 个 Binding
                // 决策：删除硬编码 genre/worldPreset Picker，替换为 MarketTaxonomyPicker
                Section("市场分区") {
                    MarketTaxonomyPicker(
                        genre: $genre,
                        worldPreset: $worldPreset,
                        storyStructure: $storyStructure,
                        pacingControl: $pacingControl,
                        writingStyle: $writingStyle,
                        specialRequirements: $specialRequirements
                    )
                }

                // 目标篇幅
                Section("目标篇幅") {
                    ForEach(lengthTierOptions, id: \.0) { tier in
                        Button {
                            lengthTier = tier.0
                            // 根据档位推导章数与字数
                            switch tier.0 {
                            case "short":
                                targetChapters = 30
                                targetWordsPerChapter = 3000
                            case "standard":
                                targetChapters = 100
                                targetWordsPerChapter = 2500
                            case "epic":
                                targetChapters = 300
                                targetWordsPerChapter = 3000
                            default:
                                break
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tier.1)
                                        .font(Theme.bodyFont())
                                        .foregroundColor(Theme.textPrimary)
                                    Text(tier.2)
                                        .font(Theme.captionFont())
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                if lengthTier == tier.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 自定义章数
                Section("自定义（覆盖篇幅档位）") {
                    Stepper("章节数：\(targetChapters)", value: $targetChapters, in: 1...9999, step: 10)
                    Stepper("每章字数：\(targetWordsPerChapter)", value: $targetWordsPerChapter, in: 500...20000, step: 500)
                }

                // 错误提示
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.error)
                    }
                }
            }
            .navigationTitle("新建书目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await handleCreate() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("建档并进入向导")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canCreate || isCreating)
                }
            }
        }
    }

    // MARK: - 创建逻辑

    /// 是否可创建
    private var canCreate: Bool {
        return !premise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 执行创建
    private func handleCreate() async {
        isCreating = true
        errorMessage = nil

        let novelId = UUID().uuidString
        let request = CreateNovelRequest(
            novelId: novelId,
            title: title.isEmpty ? String(premise.prefix(20)) : title,
            author: "作者",
            targetChapters: targetChapters,
            premise: premise,
            genre: genre,
            worldPreset: worldPreset,
            storyStructure: storyStructure,
            pacingControl: pacingControl,
            writingStyle: writingStyle,
            specialRequirements: specialRequirements,
            lengthTier: lengthTier,
            targetWordsPerChapter: targetWordsPerChapter
        )

        do {
            let novel = try await novelStore.createNovel(request)
            onCreated(novel)
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }
}
