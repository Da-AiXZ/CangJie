//
//  StylePresetSelectorView.swift
//  Cangjie
//
//  文风预设选择器（A-7），对齐原版 components/panels/StylePresetSelector.vue。
//  6 预设卡片网格 + 选中高亮 + 完整公约详情。
//

import SwiftUI

// MARK: - 文风预设选择器

/// 文风预设选择器，对齐原版 components/panels/StylePresetSelector.vue。
///
/// 6 预设卡片网格 + 选中高亮 + 完整公约详情。
/// 使用 MARKET_STYLE_PRESETS 常量。
struct StylePresetSelectorView: View {

    /// 当前选中值（双向绑定）
    @Binding var selectedValue: String

    /// 预设列表
    private let presets = MARKET_STYLE_PRESETS

    /// 当前选中的预设
    private var selectedPreset: MarketStylePreset? {
        return presets.first { $0.value == selectedValue }
    }

    var body: some View {
        VStack(spacing: 16) {
            // 预设卡片网格 — StylePresetSelector.vue:3-22
            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 160)),
                GridItem(.flexible(minimum: 160)),
            ], spacing: 10) {
                ForEach(presets) { preset in
                    presetCard(preset)
                }
            }

            // 完整公约详情 — StylePresetSelector.vue:24-33
            if let selected = selectedPreset {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("完整文风公约")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.textTertiary)

                        Spacer()

                        Text(selected.label)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.info.opacity(0.12))
                            .cornerRadius(4)
                    }

                    Text(selected.body)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Theme.secondaryBackground)
                .cornerRadius(10)
            }
        }
    }

    // MARK: - 预设卡片

    @ViewBuilder
    private func presetCard(_ preset: MarketStylePreset) -> some View {
        let isSelected = selectedValue == preset.value

        Button {
            selectedValue = preset.value
        } label: {
            VStack(spacing: 8) {
                HStack {
                    Text(preset.icon)
                        .font(.system(size: 24))

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(getPresetPreview(preset.body))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.primary.opacity(0.08) : Theme.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Theme.primary : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 辅助

    /// 提取预览文本，对齐原版 StylePresetSelector.vue:61-68 getPresetPreview
    private func getPresetPreview(_ body: String) -> String {
        // 提取【文风公约·xxx】后的第一句
        if let range = body.range(of: #"【文风公约·[^】]+】"#, options: .regularExpression) {
            let afterBracket = String(body[range.upperBound...])
            let firstSentence = afterBracket.split(whereSeparator: { $0 == "。" || $0 == "；" }).first ?? ""
            let trimmed = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 50 {
                return String(trimmed.prefix(50)) + "…"
            }
            return trimmed
        }
        let preview = String(body.prefix(50))
        return preview + (body.count > 50 ? "…" : "")
    }
}
