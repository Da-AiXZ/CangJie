//
//  DialogueCorpusView.swift
//  Cangjie
//
//  对话语料库（A-8），对齐原版 components/workbench/DialogueCorpus.vue。
//  章节/说话人/关键词筛选 + 选中角色高亮 + 对话列表。
//

import SwiftUI

// MARK: - 对话语料库视图

/// 对话语料库，对齐原版 components/workbench/DialogueCorpus.vue。
///
/// 正文自动抽取对话，用于声线对照。
/// 支持章节/说话人/关键词筛选 + 选中角色高亮。
struct DialogueCorpusView: View {

    /// 对话列表数据
    let dialogues: [DialogueEntry]

    /// 是否正在加载
    var isLoading: Bool = false

    /// 刷新回调
    var onRefresh: (() -> Void)? = nil

    /// deskChapterNumber 联动（选中章节）
    var deskChapterNumber: Int? = nil

    /// desk tick 刷新通知名
    var deskTickNotification: Notification.Name? = nil

    // 筛选状态
    @State private var filterChapter: Int? = nil
    @State private var filterSpeaker: String = ""
    @State private var searchText: String = ""
    @State private var selectedSpeaker: String? = nil

    /// 章节选项
    private var chapterOptions: [Int] {
        let chapters = Set(dialogues.map { $0.chapter })
        return Array(chapters).sorted()
    }

    /// 说话人选项
    private var speakerOptions: [String] {
        let speakers = Set(dialogues.map { $0.speaker })
        return Array(speakers).sorted()
    }

    /// 过滤后的对话
    private var filteredDialogues: [DialogueEntry] {
        return dialogues.filter { entry in
            // 章节筛选
            if let ch = filterChapter, entry.chapter != ch { return false }
            // 说话人筛选
            if !filterSpeaker.isEmpty && entry.speaker != filterSpeaker { return false }
            // 关键词搜索
            if !searchText.isEmpty {
                let keyword = searchText.lowercased()
                if !entry.content.lowercased().contains(keyword) &&
                   !entry.context.lowercased().contains(keyword) {
                    return false
                }
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("对白语料")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("正文自动抽取，用于声线对照")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }

                Spacer()

                Button {
                    onRefresh?()
                } label: {
                    HStack(spacing: 4) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                        }
                        Text("刷新")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // 筛选栏
            HStack(spacing: 8) {
                // 章节筛选
                Menu {
                    Button("全书") { filterChapter = nil }
                    ForEach(chapterOptions, id: \.self) { ch in
                        Button("第\(ch)章") { filterChapter = ch }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filterChapter != nil ? "第\(filterChapter!)章" : "章节")
                            .font(.system(size: 12))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(6)
                }

                // 说话人筛选
                Menu {
                    Button("全部") { filterSpeaker = ""; selectedSpeaker = nil }
                    ForEach(speakerOptions, id: \.self) { speaker in
                        Button(speaker) {
                            filterSpeaker = speaker
                            selectedSpeaker = speaker
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filterSpeaker.isEmpty ? "说话人" : filterSpeaker)
                            .font(.system(size: 12))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(selectedSpeaker != nil ? Theme.primary : Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedSpeaker != nil ? Theme.primary.opacity(0.08) : Theme.secondaryBackground)
                    .cornerRadius(6)
                }

                // 搜索框
                TextField("搜索…", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // 内容区
            if isLoading && dialogues.isEmpty {
                ProgressView("加载中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if dialogues.isEmpty {
                Text("暂无对话数据，生成章节后自动提取")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredDialogues.isEmpty {
                Text("无匹配对话")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 对话列表
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredDialogues) { entry in
                            dialogueItem(entry)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Theme.background)
        .onAppear {
            // deskChapterNumber 联动
            if let deskCh = deskChapterNumber {
                filterChapter = deskCh
            }
        }
    }

    // MARK: - 对话条目

    @ViewBuilder
    private func dialogueItem(_ entry: DialogueEntry) -> some View {
        let isHighlighted = selectedSpeaker == entry.speaker

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.speaker)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isHighlighted ? Theme.primary : Theme.textPrimary)

                Text("第\(entry.chapter)章")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)

                Spacer()

                ForEach(entry.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Theme.info.opacity(0.1))
                        .foregroundColor(Theme.info)
                        .cornerRadius(3)
                }
            }

            Text(entry.content)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(3)

            if !entry.context.isEmpty {
                Text(entry.context)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHighlighted ? Theme.primary.opacity(0.06) : Theme.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHighlighted ? Theme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
