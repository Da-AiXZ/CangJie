//
//  TriplesTableView.swift
//  Cangjie
//
//  三元组表格 List（主语/谓词/宾语/置信度/来源章节）。
//  支持搜索筛选，点击展开推断证据。
//

import SwiftUI

/// 三元组表格视图
struct TriplesTableView: View {

    let triples: [KnowledgeTriple]
    var onTap: (KnowledgeTriple) -> Void

    @State private var searchText: String = ""

    /// 筛选后的三元组
    private var filteredTriples: [KnowledgeTriple] {
        guard !searchText.isEmpty else { return triples }
        return triples.filter { triple in
            triple.subject.localizedCaseInsensitiveContains(searchText) ||
            triple.predicate.localizedCaseInsensitiveContains(searchText) ||
            triple.object.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar

            // 三元组列表
            List {
                ForEach(filteredTriples) { triple in
                    tripleRow(triple)
                        .onTapGesture {
                            onTap(triple)
                        }
                }
            }
            .listStyle(.plain)
        }
        .background(Theme.background)
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textTertiary)
            TextField("搜索主语/谓词/宾语…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 三元组行

    private func tripleRow(_ triple: KnowledgeTriple) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 三元组
            HStack(spacing: 6) {
                Text(triple.subject)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(entityColor(triple.entityType))

                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)

                Text(triple.predicate)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.primary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)

                Text(triple.object)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }

            // 元数据
            HStack(spacing: Theme.Spacing.md) {
                // 置信度
                if let confidence = triple.confidence {
                    HStack(spacing: 2) {
                        Image(systemName: "gauge.medium")
                            .font(.system(size: 9))
                        Text(String(format: "%.0f%%", confidence * 100))
                    }
                    .font(.system(size: 10))
                    .foregroundColor(confidenceColor(confidence))
                }

                // 来源章节
                if let chapter = triple.chapterId {
                    HStack(spacing: 2) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 9))
                        Text("第\(chapter)章")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                }

                // 来源类型
                if let source = triple.sourceType {
                    Text(sourceLabel(source))
                        .font(.system(size: 9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(sourceColor(source).opacity(0.2))
                        .cornerRadius(3)
                }

                // 重要程度
                if let importance = triple.importance {
                    Text(importance)
                        .font(.system(size: 9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(importanceColor(importance).opacity(0.2))
                        .cornerRadius(3)
                }

                // 标星指示 — 对齐原版 TripleDTO.is_starred (knowledgeGraph.ts:47)
                if triple.isStarred == true {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.warning)
                }

                Spacer()

                // 展开指示
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 颜色辅助

    private func entityColor(_ type: String?) -> Color {
        switch type ?? "" {
        case "character": return Theme.primary
        case "location": return Theme.warning
        case "item", "prop": return Theme.info
        default: return Theme.textPrimary
        }
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return Theme.success }
        if confidence >= 0.5 { return Theme.warning }
        return Theme.error
    }

    private func sourceLabel(_ source: String) -> String {
        switch source {
        case "manual": return "手动"
        case "bible_generated": return "Bible"
        case "chapter_inferred": return "推断"
        case "ai_generated": return "AI"
        default: return source
        }
    }

    private func sourceColor(_ source: String) -> Color {
        switch source {
        case "manual": return Theme.primary
        case "bible_generated": return Theme.info
        case "chapter_inferred": return Theme.warning
        case "ai_generated": return Theme.statusBypassed
        default: return Theme.textSecondary
        }
    }

    private func importanceColor(_ importance: String) -> Color {
        switch importance {
        case "high", "critical": return Theme.error
        case "medium": return Theme.warning
        case "low": return Theme.textSecondary
        default: return Theme.textSecondary
        }
    }
}
