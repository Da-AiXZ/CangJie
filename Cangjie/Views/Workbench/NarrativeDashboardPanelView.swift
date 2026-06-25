//
//  NarrativeDashboardPanelView.swift
//  Cangjie
//
//  叙事仪表盘，对齐原版 NarrativeDashboardPanel.vue:1-915。
//  5个section：叙事时刻/活跃线体/未兑承诺/角色当下/引擎记忆。
//

import SwiftUI

/// 叙事仪表盘面板 — NarrativeDashboardPanel.vue:1-251
struct NarrativeDashboardPanelView: View {
    // MARK: - Props — NarrativeDashboardPanel.vue:286-293

    let slug: String
    let currentChapterNumber: Int

    @StateObject private var store = NarrativeDashboardStore()

    var body: some View {
        VStack(spacing: 0) {
            // ── Header — NarrativeDashboardPanel.vue:5-30
            header

            // ── Body — NarrativeDashboardPanel.vue:32-249
            ScrollView {
                VStack(spacing: 0) {
                    // ① 叙事时刻
                    momentSection
                    Divider()
                    // ② 活跃线体
                    activeStorylinesSection
                    Divider()
                    // ③ 未兑承诺
                    pendingPromisesSection
                    Divider()
                    // ④ 角色当下
                    characterSection
                    Divider()
                    // ⑤ 引擎记忆（折叠）
                    engineMemorySection
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }
        }
        .task {
            await store.load(slug: slug)
        }
        .onChange(of: slug) { _ in
            Task { await store.load(slug: slug) }
        }
        .onChange(of: currentChapterNumber) { _ in
            Task { await store.load(slug: slug) }
        }
    }

    // MARK: - Header — NarrativeDashboardPanel.vue:5-30

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("叙事简报")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    if currentChapterNumber > 0 {
                        Text("第 \(currentChapterNumber) 章")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.info.opacity(0.12))
                            .cornerRadius(8)
                            .foregroundColor(Theme.info)
                    }
                }
                Text("三系统联合感知 · 实时快照")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Button {
                Task { await store.load(slug: slug) }
            } label: {
                if store.loading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    // MARK: - ① 叙事时刻 — NarrativeDashboardPanel.vue:36-100

    private var momentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header — NarrativeDashboardPanel.vue:38-43
            HStack {
                Text("叙事时刻")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                // 阶段徽章 — NarrativeDashboardPanel.vue:40-43
                Text(getStoryPhaseLabel(store.phase))
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(getStoryPhaseColor(store.phase).opacity(0.12))
                    .foregroundColor(getStoryPhaseColor(store.phase))
                    .cornerRadius(6)
            }

            // Progress stats — NarrativeDashboardPanel.vue:46-54
            if store.maxChapter > 0 || store.progressPct > 0 {
                HStack(spacing: 4) {
                    if currentChapterNumber > 0 && store.maxChapter > 0 {
                        Text("第 \(currentChapterNumber) / \(store.maxChapter) 章")
                    }
                    if store.progressPct > 0 {
                        Text("· 进度 \(store.progressPct)%")
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            }

            // Global progress bar — NarrativeDashboardPanel.vue:56-66
            if store.progressPct > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.textTertiary.opacity(0.2))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(getStoryPhaseColor(store.phase))
                            .frame(width: geo.size.width * CGFloat(store.progressPct) / 100, height: 3)
                    }
                }
                .frame(height: 3)
            }

            // Phase axis: dots row — NarrativeDashboardPanel.vue:68-96
            phaseAxis

            // Phase hint — NarrativeDashboardPanel.vue:98
            let hint = getStoryPhaseHint(store.phase)
            if !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .italic()
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    /// 阶段轴 — NarrativeDashboardPanel.vue:68-96
    private var phaseAxis: some View {
        VStack(spacing: 5) {
            // 点+线
            HStack(spacing: 0) {
                ForEach(Array(STORY_PHASE_STAGES.enumerated()), id: \.element.id) { i, step in
                    let isDone = isStoryPhasePast(step.value, current: store.phase)
                    let isActive = store.currentPhase == step.value

                    Circle()
                        .fill(isDone ? Theme.success : (isActive ? Theme.primary : Theme.textTertiary.opacity(0.3)))
                        .frame(width: isActive ? 12 : 9, height: isActive ? 12 : 9)
                        .overlay(
                            isActive ?
                            Circle()
                                .stroke(Theme.primary.opacity(0.2), lineWidth: 3)
                                .frame(width: 18, height: 18)
                            : nil
                        )

                    if i < STORY_PHASE_STAGES.count - 1 {
                        Rectangle()
                            .fill(isDone ? Theme.success : Theme.textTertiary.opacity(0.2))
                            .frame(height: 2)
                    }
                }
            }
            // 标签
            HStack {
                ForEach(STORY_PHASE_STAGES) { step in
                    let isDone = isStoryPhasePast(step.value, current: store.phase)
                    let isActive = store.currentPhase == step.value
                    Text(step.label)
                        .font(.system(size: 10))
                        .foregroundColor(isDone ? Theme.success : (isActive ? Theme.primary : Theme.textTertiary))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - ② 活跃线体 — NarrativeDashboardPanel.vue:102-135

    private var activeStorylinesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("活跃线体")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                let actives = store.activeStorylines(currentChapterNumber: currentChapterNumber)
                if !actives.isEmpty {
                    Text("\(actives.count) 条")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(Theme.primary)
                }
                Spacer()
            }

            let actives = store.activeStorylines(currentChapterNumber: currentChapterNumber)
            if actives.isEmpty {
                Text("本章暂无活跃故事线")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                ForEach(actives) { sl in
                    storylineRow(sl)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    /// 故事线行 — NarrativeDashboardPanel.vue:112-130
    private func storylineRow(_ sl: StorylineDTO) -> some View {
        let role = sl.role ?? sl.storylineType ?? "sub"
        let total = sl.milestones?.count ?? 0
        let curr = sl.currentMilestoneIndex ?? 0
        let progress = total > 0 ? min(100, Int(Double(curr) / Double(total) * 100)) : 0

        return HStack(spacing: 8) {
            // 角色标签 — NarrativeDashboardPanel.vue:113-118
            Text(getStorylineRoleCompactLabel(role))
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(getStorylineRoleColor(role).opacity(0.12))
                .foregroundColor(getStorylineRoleColor(role))
                .cornerRadius(8)

            // 名称 — NarrativeDashboardPanel.vue:119-121
            Text(sl.name ?? "未命名故事线")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)

            // 里程碑进度条 — NarrativeDashboardPanel.vue:122-129
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.textTertiary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(getStorylineRoleColor(role))
                        .frame(width: geo.size.width * CGFloat(progress) / 100)
                }
            }
            .frame(width: 56, height: 4)

            // 里程碑标签 — NarrativeDashboardPanel.vue:129
            if total > 0 {
                Text("\(curr)/\(total)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 28, alignment: .trailing)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - ③ 未兑承诺 — NarrativeDashboardPanel.vue:137-175

    private var pendingPromisesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("未兑承诺")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                if store.pendingForeshadows.isEmpty {
                    Text("已清")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.success.opacity(0.12))
                        .cornerRadius(8)
                        .foregroundColor(Theme.success)
                } else if store.hasCriticalPromise(currentChapterNumber: currentChapterNumber) {
                    Text("\(store.pendingForeshadows.count)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.error.opacity(0.12))
                        .cornerRadius(8)
                        .foregroundColor(Theme.error)
                } else {
                    Text("\(store.pendingForeshadows.count)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.warning.opacity(0.12))
                        .cornerRadius(8)
                        .foregroundColor(Theme.warning)
                }
                Spacer()
            }

            if store.urgentForeshadows.isEmpty {
                Text("暂无待兑现的叙事承诺")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                ForEach(store.urgentForeshadows) { entry in
                    promiseRow(entry)
                }
                if store.pendingForeshadows.count > 5 {
                    Text("还有 \(store.pendingForeshadows.count - 5) 条待兑现")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    /// 承诺行 — NarrativeDashboardPanel.vue:148-167
    private func promiseRow(_ entry: ForeshadowEntry) -> some View {
        let urgency = foreshadowUrgencyClass(entry, currentChapterNumber: currentChapterNumber)
        let urgencyColor: Color = {
            switch urgency {
            case .danger: return Theme.error
            case .warning: return Theme.warning
            case .muted: return Theme.textTertiary
            }
        }()

        return HStack(alignment: .top, spacing: 7) {
            // 紧急度圆点 — NarrativeDashboardPanel.vue:154-157
            Circle()
                .fill(urgencyColor)
                .frame(width: 7, height: 7)
                .padding(.top, 4)

            // 来源章节 — NarrativeDashboardPanel.vue:158
            Text("[ch.\(entry.chapter)]")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.textTertiary)
                .padding(.top, 1)

            // 承诺问题 — NarrativeDashboardPanel.vue:159
            Text(entry.question)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()

            // 剩余章数 — NarrativeDashboardPanel.vue:161-166
            if let due = entry.suggestedResolveChapter, currentChapterNumber > 0 {
                let remaining = max(0, due - currentChapterNumber)
                Text("\(remaining)章")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(urgencyColor)
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - ④ 角色当下 — NarrativeDashboardPanel.vue:177-211

    private var characterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("角色当下")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Button {
                    // 决策#12/#13: 复用 StoryEvolutionPanel.openCharacterAnchorNotification
                    NotificationCenter.default.post(
                        name: StoryEvolutionPanel.openCharacterAnchorNotification,
                        object: nil
                    )
                } label: {
                    Text("档案 →")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.primary)
                }
            }

            if store.mainCharacters.isEmpty {
                Text("尚未配置角色心理画像")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                ForEach(store.mainCharacters) { psyche in
                    characterRow(psyche)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    /// 角色行 — NarrativeDashboardPanel.vue:185-207
    private func characterRow(_ psyche: CharacterPsyche) -> some View {
        Button {
            NotificationCenter.default.post(
                name: StoryEvolutionPanel.openCharacterAnchorNotification,
                object: nil
            )
        } label: {
            HStack(alignment: .top, spacing: 10) {
                // Emoji — NarrativeDashboardPanel.vue:195
                Text(getCharacterRoleIcon(psyche.role))
                    .font(.system(size: 20))
                    .foregroundColor(getCharacterRoleColor(psyche.role))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        // 角色名 — NarrativeDashboardPanel.vue:198
                        Text(psyche.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        // 心理状态Tag — NarrativeDashboardPanel.vue:199-203
                        let mentalState = store.characterMentalState(name: psyche.name)
                        if !mentalState.isEmpty {
                            Text(mentalState)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Theme.warning.opacity(0.12))
                                .cornerRadius(6)
                                .foregroundColor(Theme.warning)
                        }
                    }
                    // 核心信念 — NarrativeDashboardPanel.vue:204
                    if !psyche.coreBelief.isEmpty {
                        Text(psyche.coreBelief)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - ⑤ 引擎记忆（折叠）— NarrativeDashboardPanel.vue:213-246

    @State private var engineMemoryExpanded: Bool = false

    private var engineMemorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $engineMemoryExpanded) {
                VStack(spacing: 0) {
                    // 全书锚点 — NarrativeDashboardPanel.vue:222-225
                    engineRow(
                        key: "全书锚点",
                        value: store.hasMainStoryline ? "已装载" : "需配置",
                        color: store.hasMainStoryline ? Theme.success : Theme.textTertiary
                    )
                    // 角色声线 — NarrativeDashboardPanel.vue:226-229
                    engineRow(
                        key: "角色声线",
                        value: "\(store.psyches.count) 位已配置",
                        color: Theme.primary
                    )
                    // 叙事债务 — NarrativeDashboardPanel.vue:230-233
                    engineRow(
                        key: "叙事债务",
                        value: "\(store.pendingForeshadows.count) 条待兑",
                        color: store.pendingForeshadows.isEmpty ? Theme.success : Theme.warning
                    )
                    // 紧急伏笔 — NarrativeDashboardPanel.vue:234-242
                    engineRow(
                        key: "紧急伏笔",
                        value: store.urgentCount(currentChapterNumber: currentChapterNumber) > 0 ? "\(store.urgentCount(currentChapterNumber: currentChapterNumber)) 条紧急" : "无紧急",
                        color: store.urgentCount(currentChapterNumber: currentChapterNumber) > 0 ? Theme.error : Theme.textTertiary
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            } label: {
                Text("引擎记忆")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    /// 引擎记忆行 — NarrativeDashboardPanel.vue:221-242
    private func engineRow(key: String, value: String, color: Color) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(color.opacity(0.12))
                .cornerRadius(6)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}
