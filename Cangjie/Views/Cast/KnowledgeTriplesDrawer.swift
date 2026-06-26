//
//  KnowledgeTriplesDrawer.swift
//  Cangjie
//
//  三元组抽屉编辑器，从底部滑入（.sheet，iOS 16 兼容）。
//  对齐原版 Cast.vue:180-191 / LocationGraph.vue:86-97 三元组抽屉。
//

import SwiftUI

/// 三元组抽屉视图
///
/// 支持 focus-entity-name 过滤（选中角色/地点后只看相关三元组）。
/// default-entity-filter 区分 character/location。
struct KnowledgeTriplesDrawer: View {
    let novelId: String
    let triples: [KnowledgeTriple]
    var focusEntityName: String?
    var defaultEntityType: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedEntityType: String?

    // 筛选后的三元组
    private var filteredTriples: [KnowledgeTriple] {
        var result = triples

        // focus-entity-name 过滤
        if let focus = focusEntityName, !focus.isEmpty {
            result = result.filter {
                $0.subject == focus || $0.object == focus
            }
        }

        // 实体类型过滤
        if let type = selectedEntityType {
            result = result.filter { $0.entityType == type }
        }

        // 搜索过滤
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.subject.lowercased().contains(query) ||
                $0.object.lowercased().contains(query) ||
                $0.predicate.lowercased().contains(query)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    TextField("搜索三元组…", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Picker("", selection: $selectedEntityType) {
                        Text("全部").tag(String?.none)
                        Text("角色").tag(String?.some("character"))
                        Text("地点").tag(String?.some("location"))
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                }
                .padding(12)

                if let focus = focusEntityName, !focus.isEmpty {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(Theme.primary)
                        Text("筛选：\(focus)")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Button("清除") {
                            searchText = ""
                            selectedEntityType = nil
                        }
                        .font(.system(size: 10))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                // 三元组列表
                if filteredTriples.isEmpty {
                    Text("无匹配三元组")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredTriples) { triple in
                            tripleDetailRow(triple)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("三元组编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            // 应用默认实体类型筛选
            if let defaultType = defaultEntityType {
                selectedEntityType = defaultType
            }
        }
    }

    // MARK: - 三元组详情行

    @ViewBuilder
    private func tripleDetailRow(_ triple: KnowledgeTriple) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(triple.subject)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)
                Text(triple.predicate)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(4)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)
                Text(triple.object)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }

            HStack(spacing: 8) {
                if let type = triple.entityType {
                    labelTag(type == "character" ? "角色" : "地点", color: Theme.info)
                }
                if let importance = triple.importance {
                    labelTag(importance, color: Theme.warning)
                }
                if let chapter = triple.chapterId {
                    labelTag("第\(chapter)章", color: Theme.textTertiary)
                }
                if let sourceType = triple.sourceType {
                    labelTag(sourceType, color: Theme.textTertiary)
                }
            }

            if let desc = triple.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func labelTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.1))
            .cornerRadius(3)
    }
}
