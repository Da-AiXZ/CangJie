//
//  ChapterCastManagerView.swift
//  Cangjie
//
//  本章角色锁，对齐原版 components/workbench/ChapterCastManager.vue:1-241。
//  统计4列+选角合同列表+新角色准入+上下文锁预览。
//

import SwiftUI

/// 本章角色锁视图
///
/// 对齐原版 `components/workbench/ChapterCastManager.vue`。
struct ChapterCastManagerView: View {

    /// 小说 ID（对齐 :137 props.slug）
    let novelId: String

    /// 章节号（对齐 :138 props.chapterNumber）
    var chapterNumber: Int? = nil

    /// 大纲（对齐 :139 props.outline）
    var outline: String = ""

    /// 选中角色回调（对齐 :153 emit select-character）
    var onSelectCharacter: ((String) -> Void)? = nil

    // MARK: - 状态

    @StateObject private var castStore = CastStore()

    // MARK: - 计算属性

    /// 统计4列（对齐 :163-167 tierCounts）
    private var tierCounts: (major: Int, normal: Int, minor: Int) {
        let cast = castStore.scheduleResponse?.cast ?? []
        return (
            major: cast.filter { $0.importance == "major" }.count,
            normal: cast.filter { $0.importance == "normal" }.count,
            minor: cast.filter { $0.importance == "minor" }.count
        )
    }

    /// 需校准数（对齐 :169 reviewCount）
    private var reviewCount: Int {
        (castStore.scheduleResponse?.cast ?? []).filter { $0.needsReview == true }.count
    }

    /// 选角合同列表（对齐 :158 suggestions）
    private var suggestions: [ScheduledCharacterItem] {
        castStore.scheduleResponse?.cast ?? []
    }

    /// 新角色准入（对齐 :159 newCharacterCandidates）
    private var newCharacterCandidates: [AnyCodable] {
        castStore.scheduleResponse?.newCharacterCandidates ?? []
    }

    /// 上下文锁预览（对齐 :160 generatedContext）
    private var generatedContext: String {
        castStore.scheduleResponse?.generatedContext ?? ""
    }

    /// 调度日志（对齐 :161 schedulingLog）
    private var schedulingLog: [String] {
        castStore.scheduleResponse?.schedulingLog ?? []
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 对齐 :3-23 header
            header

            // 对齐 :25-121 滚动内容
            ScrollView {
                VStack(spacing: 10) {
                    // 对齐 :27-44 统计4列
                    statsGrid

                    // 对齐 :46-78 选角合同
                    if !suggestions.isEmpty {
                        castSection
                    }

                    // 对齐 :80-101 新角色准入
                    if !newCharacterCandidates.isEmpty {
                        candidatesSection
                    }

                    // 对齐 :103-112 上下文锁预览
                    if !generatedContext.isEmpty || !schedulingLog.isEmpty {
                        contextSection
                    }

                    // 对齐 :114-119 空状态
                    if !castStore.isScheduling && suggestions.isEmpty && newCharacterCandidates.isEmpty {
                        Text("暂无本章角色合同")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textTertiary)
                            .padding(.top, 16)
                    }
                }
                .padding(12)
            }
        }
        .background(Theme.background)
        .onChange(of: novelId) { _ in runSchedule() }
        .onChange(of: chapterNumber) { _ in runSchedule() }
        .task {
            runSchedule()
        }
    }

    // MARK: - Header（对齐 :3-23）

    private var header: some View {
        HStack(spacing: 8) {
            Text("本章角色锁")
                .font(.system(size: 13, weight: .bold))
            if let ch = chapterNumber {
                Text("第 \(ch) 章")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(999)
                    .foregroundColor(Theme.primary)
            }
            Spacer()

            // 对齐 :9-11 刷新内核
            Button {
                runSchedule()
            } label: {
                Label("刷新内核", systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .disabled(castStore.isScheduling || chapterNumber == nil)

            // 对齐 :12-22 落库对齐
            Button {
                runApply()
            } label: {
                Label("落库对齐", systemImage: "checkmark.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderedProminent)
            .disabled(suggestions.isEmpty || castStore.isScheduling || chapterNumber == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.2)), alignment: .bottom)
    }

    // MARK: - 统计4列（对齐 :27-44）

    private var statsGrid: some View {
        HStack(spacing: 8) {
            statCard(num: "\(tierCounts.major)", label: "T0 锚定", color: Theme.primary)
            statCard(num: "\(tierCounts.normal)", label: "T1 参与", color: Theme.warning)
            statCard(num: "\(tierCounts.minor)", label: "T2 过场", color: Theme.textTertiary)
            statCard(num: "\(reviewCount)", label: "需校准", color: Theme.error)
        }
    }

    private func statCard(num: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(num)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
        .overlay(Rectangle().frame(width: nil, height: 2).foregroundColor(color), alignment: .top)
    }

    // MARK: - 选角合同（对齐 :46-78）

    private var castSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("选角合同")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("后端 Character Narrative Kernel 自动生成")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }

            ForEach(suggestions) { item in
                castItemRow(item)
            }
        }
    }

    private func castItemRow(_ item: ScheduledCharacterItem) -> some View {
        Button {
            onSelectCharacter?(item.characterId)
        } label: {
            HStack(spacing: 9) {
                // 头像
                Text(item.name.prefix(1))
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(importanceColor(item.importance).opacity(0.12))
                    .foregroundColor(importanceColor(item.importance))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text(slotTierLabel(item.importance))
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(importanceColor(item.importance).opacity(0.1))
                            .cornerRadius(5)
                            .foregroundColor(importanceColor(item.importance))
                        if item.needsReview == true {
                            Text("校准")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Theme.error.opacity(0.1))
                                .cornerRadius(5)
                                .foregroundColor(Theme.error)
                        }
                    }
                    if let sf = item.sceneFunction {
                        Text(sceneFunctionLabel(sf))
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(8)
            .background(Theme.secondaryBackground)
            .cornerRadius(8)
            .overlay(
                Rectangle().frame(width: 3).foregroundColor(importanceColor(item.importance)),
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 新角色准入（对齐 :80-101）

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("新角色准入")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("默认自动采纳，只有高风险需要看")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }

            ForEach(Array(newCharacterCandidates.enumerated()), id: \.offset) { _, candidate in
                // CI#29 修复：dictionaryValue 返回 [String: Any]，值类型为 Any，改用 as? String
                let name = (candidate.dictionaryValue?["name"] as? String) ?? "未知"
                let recommendation = (candidate.dictionaryValue?["recommendation"] as? String) ?? ""
                let reason = (candidate.dictionaryValue?["reason"] as? String) ?? "内核已完成准入判断"
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(name)
                            .font(.system(size: 11, weight: .bold))
                        Spacer()
                        Text(recommendationLabel(recommendation))
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(candidateColor(recommendation).opacity(0.1))
                            .cornerRadius(5)
                            .foregroundColor(candidateColor(recommendation))
                    }
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(8)
                .background(Theme.secondaryBackground)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(candidateColor(recommendation).opacity(0.22), lineWidth: 1))
            }
        }
    }

    // MARK: - 上下文锁预览（对齐 :103-112）

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("上下文锁预览")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("随本章角色合同同步生成")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
            if !generatedContext.isEmpty {
                Text(generatedContext)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            if !schedulingLog.isEmpty {
                HStack(spacing: 5) {
                    ForEach(schedulingLog, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.tertiaryBackground)
                            .cornerRadius(999)
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - 标签辅助（对齐 :171-185 domain/chapterWriting）

    private func importanceColor(_ importance: String) -> Color {
        switch importance {
        case "major": return Theme.primary
        case "normal": return Theme.warning
        case "minor": return Theme.textTertiary
        default: return Theme.textSecondary
        }
    }

    private func slotTierLabel(_ importance: String) -> String {
        switch importance {
        case "major": return "T0 锚定"
        case "normal": return "T1 参与"
        case "minor": return "T2 过场"
        default: return importance
        }
    }

    private func sceneFunctionLabel(_ value: String) -> String {
        switch value {
        case "protagonist": return "主角"
        case "antagonist": return "对手"
        case "mentor": return "导师"
        case "ally": return "盟友"
        case "observer": return "旁观者"
        default: return value
        }
    }

    private func recommendationLabel(_ value: String) -> String {
        switch value {
        case "create": return "建档"
        case "ephemeral": return "临时"
        case "reject": return "拒绝"
        default: return value
        }
    }

    private func candidateColor(_ value: String) -> Color {
        switch value {
        case "create": return Theme.primary
        case "ephemeral": return Theme.warning
        case "reject": return Theme.error
        default: return Theme.textTertiary
        }
    }

    // MARK: - 调度（对齐 :191-234）

    private func runSchedule() {
        guard let ch = chapterNumber, !novelId.isEmpty else { return }
        Task {
            await castStore.scheduleCast(
                novelId: novelId,
                chapterNumber: ch,
                mode: .suggest,
                outline: outline.isEmpty ? nil : outline
            )
        }
    }

    private func runApply() {
        guard let ch = chapterNumber, !novelId.isEmpty else { return }
        Task {
            await castStore.scheduleCast(
                novelId: novelId,
                chapterNumber: ch,
                mode: .apply,
                outline: outline.isEmpty ? nil : outline
            )
        }
    }
}
