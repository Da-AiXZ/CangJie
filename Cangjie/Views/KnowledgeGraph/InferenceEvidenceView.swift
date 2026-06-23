//
//  InferenceEvidenceView.swift
//  Cangjie
//
//  推断证据详情：点击三元组后展开，显示来源章节片段+推理链。
//

import SwiftUI

/// 推断证据详情视图
struct InferenceEvidenceView: View {

    let triple: KnowledgeTriple

    @EnvironmentObject var kgStore: KnowledgeGraphStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // 三元组摘要
                    tripleSummary

                    // 推断证据
                    if !triple.provenance.isEmpty {
                        provenanceSection
                    }

                    // 相关章节
                    if !triple.relatedChapters.isEmpty {
                        relatedChaptersSection
                    }

                    // 属性
                    if !triple.attributes.isEmpty {
                        attributesSection
                    }

                    // 标签
                    if !triple.tags.isEmpty {
                        tagsSection
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.background)
            .navigationTitle("推断证据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - 三元组摘要

    private var tripleSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("三元组")
                .font(Theme.headlineFont())

            HStack(spacing: 8) {
                Text(triple.subject)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.primary)

                Text(triple.predicate)
                    .font(.system(size: 13))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.info.opacity(0.2))
                    .cornerRadius(4)

                Text(triple.object)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }

            if !triple.note.isEmpty {
                Text(triple.note)
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .cardStyle()
    }

    // MARK: - 推断证据

    private var provenanceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("推断溯源", systemImage: "link.circle.fill")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.primary)

            ForEach(triple.provenance.indices, id: \.self) { index in
                let item = triple.provenance[index]
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(Theme.primary)
                        Text("证据 \(index + 1)")
                            .font(.system(size: 12, weight: .medium))
                    }

                    Text(item.stringValue)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.leading, 24)
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.small)
            }
        }
        .cardStyle()
    }

    // MARK: - 相关章节

    private var relatedChaptersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("相关章节", systemImage: "book.fill")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.primary)

            HStack {
                ForEach(triple.relatedChapters, id: \.self) { chapter in
                    Text("第\(chapter)章")
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.info.opacity(0.15))
                        .cornerRadius(4)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 属性

    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("额外属性", systemImage: "list.bullet.rectangle")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.primary)

            ForEach(triple.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                    Text(value.stringValue)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 标签

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("标签", systemImage: "tag.fill")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.primary)

            HStack {
                ForEach(triple.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.statusBypassed.opacity(0.15))
                        .cornerRadius(4)
                }
            }
        }
        .cardStyle()
    }
}
