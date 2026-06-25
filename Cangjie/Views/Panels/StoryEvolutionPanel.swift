//
//  StoryEvolutionPanel.swift
//  Cangjie
//
//  故事演化（司令塔+状态机+时间轴+世界线4 Tab），对齐 StoryEvolutionPanel.vue:1-1362。
//  返工修复：P0-1(loadSetupAnchors第5路) P0-2(12种锚点) P0-4(promiseHitRate)
//  P1-5(状态连续性) P1-6(世界线简要) P1-7(角色档案按钮) P1-8(combinedRisks)
//  P2-15(角色状态修改) L-1(applyOverrides章节号) L-3(issues展示)
//

import SwiftUI

struct StoryEvolutionPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var workbenchStore: WorkbenchStore
    @StateObject private var store = EvolutionStore()

    @State private var activeTab: String = "command"
    @State private var selectedStorylineRange: (start: Int, end: Int)? = nil
    @State private var selectedItem: StorySelectedItem? = nil
    @State private var selectedCharStatusId: String? = nil
    @State private var selectedCharStatus: String = "alive"

    /// 通知名 — P1-7：打开角色档案（对齐原版 WORKBENCH_OPEN_SETTINGS_PANEL_EVENT）
    static let openCharacterAnchorNotification = Notification.Name("OpenCharacterAnchor")

    private let characterStatusOptions = ["alive", "dead", "missing", "ambiguous", "severely_injured"]

    private let tabs = [
        ("command", "司令塔", "pulse"),
        ("state", "状态机", "gearshape.2"),
        ("timeline", "时间轴", "timeline"),
        ("worldline", "世界线", "point.3.connected.trianglepath.dotted"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            contentArea
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadAll(novelId: novelId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WorkbenchStore.deskTickNotification)) { _ in
            if let novelId = appState.currentNovelId {
                Task { await store.loadAll(novelId: novelId) }
            }
        }
        .onChange(of: appState.currentNovelId) { newId in
            if let novelId = newId {
                Task { await store.loadAll(novelId: novelId) }
            }
        }
    }

    // MARK: - Tab Bar — StoryEvolutionPanel.vue:19-50
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { key, label, icon in
                Button { activeTab = key } label: {
                    VStack(spacing: 2) {
                        Image(systemName: icon).font(.system(size: 11))
                        Text(label).font(.system(size: 9, weight: activeTab == key ? .semibold : .regular))
                    }
                    .foregroundColor(activeTab == key ? Theme.primary : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .overlay(
                        Rectangle().fill(activeTab == key ? Theme.primary : Color.clear).frame(height: 2),
                        alignment: .bottom
                    )
                }
                .buttonStyle(.plain)
            }
            // P1-7：角色档案按钮 — StoryEvolutionPanel.vue:49
            Button {
                NotificationCenter.default.post(name: Self.openCharacterAnchorNotification, object: nil)
            } label: {
                Text("角色档案").font(.system(size: 9, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.trailing, 8)
        }
        .overlay(Rectangle().fill(Theme.textTertiary.opacity(0.2)).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Content
    @ViewBuilder
    private var contentArea: some View {
        switch activeTab {
        case "command": commandTab
        case "state": stateTab
        case "timeline": timelineTab
        case "worldline": worldlineTab
        default: commandTab
        }
    }

    // MARK: - 司令塔 Tab — StoryEvolutionPanel.vue:63-222
    private var commandTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // ── Hero 区域 — StoryEvolutionPanel.vue:63-87
                VStack(alignment: .leading, spacing: 8) {
                    Text("演进司令塔").font(.system(size: 16, weight: .bold))
                    Text("以写前约束、连续性证据和分支存档为核心，快速判断下一章是否可以推进。")
                        .font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                    HStack(spacing: 16) {
                        // 承诺命中 — StoryEvolutionPanel.vue:71-77
                        VStack(spacing: 2) {
                            Text("承诺命中").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                            Text(governanceHitRate)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.primary)
                            // 进度条
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.tertiaryBackground).frame(height: 4)
                                    Capsule().fill(Theme.primary)
                                        .frame(width: geo.size.width * CGFloat(governanceHitPercent) / 100, height: 4)
                                }
                            }
                            .frame(width: 80, height: 4)
                        }
                        // 状态快照 — StoryEvolutionPanel.vue:78-82
                        VStack(spacing: 2) {
                            Text("状态快照").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                            if let snap = store.snapshots.first {
                                Text("第\(snap.chapterNumber)章").font(.system(size: 14, weight: .bold))
                                Text(snapshotStatusLabel).font(.system(size: 9)).foregroundColor(snapshotStatusColor(snap.status))
                            } else {
                                Text("未生成").font(.system(size: 12)).foregroundColor(Theme.textTertiary)
                                Text("等待章节保存").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                            }
                        }
                        // 世界线摘要 — StoryEvolutionPanel.vue:83-87（P1-6修复）
                        VStack(spacing: 2) {
                            Text("世界线").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                            Text(worldlineSummary).font(.system(size: 14, weight: .bold))
                            Text(worldlineHeadName).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                        }
                        Spacer()
                    }
                }
                .padding(12)
                .background(Theme.secondaryBackground)
                .cornerRadius(8)

                // ── 引导落点 — StoryEvolutionPanel.vue:90-112（P0-2修复：12种锚点）
                setupAnchorsSection

                // ── 预算+治理+状态连续性+世界线 四宫格 — StoryEvolutionPanel.vue:114-198
                VStack(spacing: 8) {
                    // 自动写前约束 — StoryEvolutionPanel.vue:115-137
                    budgetPanel

                    // 叙事治理 — StoryEvolutionPanel.vue:139-156（L-3修复：issues展示）
                    governancePanel

                    // 状态连续性 — StoryEvolutionPanel.vue:158-174（P1-5修复）
                    stateContinuityPanel

                    // 世界线简要 — StoryEvolutionPanel.vue:176-198（P1-6修复）
                    worldlineBriefPanel
                }

                // ── 风险与修复队列 — StoryEvolutionPanel.vue:201-222（P1-8修复：combinedRisks）
                riskQueuePanel
            }
            .padding(12)
        }
    }

    // MARK: - 引导落点 — StoryEvolutionPanel.vue:90-112 + setupAnchorRows computed (524-666)
    private var setupAnchorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("引导落点").font(.system(size: 13, weight: .semibold))
                    Text("建档与引导阶段写入的关键约束，后续演进不得漂移。")
                        .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                }
                Spacer()
                Text(setupAnchorsLoading ? "读取中" : "\(setupAnchorRows.count) 项")
                    .font(.system(size: 9)).foregroundColor(setupAnchorRows.isEmpty ? Theme.textTertiary : Theme.success)
            }

            if setupAnchorRows.isEmpty {
                Text("暂无可展示的引导落点；完成作品设定、人物、地图或剧情总纲后会在这里汇总。")
                    .font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(setupAnchorRows, id: \.key) { anchor in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(anchor.title).font(.system(size: 11, weight: .semibold))
                                Spacer()
                                Text(anchor.meta)
                                    .font(.system(size: 8))
                                    .foregroundColor(anchorColor(anchor.type))
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(anchorColor(anchor.type).opacity(0.12))
                                    .cornerRadius(3)
                            }
                            Text(anchor.detail).font(.system(size: 9)).foregroundColor(Theme.textSecondary).lineLimit(3)
                        }
                        .padding(8)
                        .background(Theme.tertiaryBackground)
                        .cornerRadius(6)
                        .overlay(Rectangle().fill(anchorColor(anchor.type)).frame(width: 2), alignment: .leading)
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 锚点行结构 — StoryEvolutionPanel.vue:524-666 setupAnchorRows
    private struct SetupAnchorRow {
        let key: String
        let title: String
        let meta: String
        let detail: String
        let type: String // default|info|success|warning|error
    }

    /// 构建12种锚点 — StoryEvolutionPanel.vue:524-666（P0-2修复）
    private var setupAnchorRows: [SetupAnchorRow] {
        var rows: [SetupAnchorRow] = []
        let novel = store.setupNovel
        let bible = store.setupBible
        let outline = store.setupPlotOutline

        // 1. genre-world — vue:536-544
        if !(novel?.lockedGenre.isEmpty ?? true) || !(novel?.lockedWorldPreset.isEmpty ?? true) {
            rows.append(SetupAnchorRow(
                key: "genre-world", title: "类型与世界基调",
                meta: novel?.lockedGenre.isEmpty ?? true ? "赛道" : novel!.lockedGenre,
                detail: clipText(novel?.lockedWorldPreset.isEmpty ?? true ? novel?.premise : novel!.lockedWorldPreset, 150) ?? "已在建档阶段锁定类型方向。",
                type: "info"
            ))
        }

        // 2. premise — vue:546-554
        if let premise = novel?.premise, !premise.isEmpty {
            rows.append(SetupAnchorRow(
                key: "premise", title: "初始粗纲", meta: "Premise",
                detail: clipText(premise, 170) ?? "",
                type: "default"
            ))
        }

        // 3. structure — vue:556-564
        if !(novel?.lockedStoryStructure.isEmpty ?? true) || !(novel?.lockedPacingControl.isEmpty ?? true) {
            let parts = [novel?.lockedStoryStructure, novel?.lockedPacingControl].compactMap { $0 }.filter { !$0.isEmpty }
            rows.append(SetupAnchorRow(
                key: "structure", title: "故事骨架与节奏", meta: "结构",
                detail: clipText(parts.joined(separator: "；"), 150) ?? "",
                type: "success"
            ))
        }

        // 4. plot-outline — vue:566-574
        if let outline = outline, !outline.mainStoryOverview.isEmpty || !outline.coreConflict.isEmpty {
            rows.append(SetupAnchorRow(
                key: "plot-outline", title: "主线总纲",
                meta: "\(outline.stagePlan.count) 阶段",
                detail: clipText(outline.mainStoryOverview.isEmpty ? outline.coreConflict : outline.mainStoryOverview, 170) ?? "",
                type: "info"
            ))
        }

        // 5. core-conflict — vue:576-584
        if let outline = outline, !outline.coreConflict.isEmpty {
            rows.append(SetupAnchorRow(
                key: "core-conflict", title: "核心冲突", meta: "冲突",
                detail: clipText(outline.coreConflict, 150) ?? "",
                type: "warning"
            ))
        }

        // 6. ending — vue:586-594
        if let outline = outline, !outline.expectedEnding.isEmpty {
            rows.append(SetupAnchorRow(
                key: "ending", title: "结局走向", meta: "收束",
                detail: clipText(outline.expectedEnding, 150) ?? "",
                type: "success"
            ))
        }

        // 7. characters — vue:596-610
        if let bible = bible, !bible.characters.isEmpty {
            let summary = bible.characters.prefix(5).map { char in
                "\(char.name)\(char.coreMotivation.isEmpty ? (char.description.isEmpty ? "" : "：\(char.description)") : "：\(char.coreMotivation)")"
            }.joined(separator: "；")
            rows.append(SetupAnchorRow(
                key: "characters", title: "核心人物",
                meta: "\(bible.characters.count) 人",
                detail: clipText(summary, 170) ?? "",
                type: "default"
            ))
        }

        // 8. world-settings — vue:612-626
        if let bible = bible, !bible.worldSettings.isEmpty {
            let summary = bible.worldSettings.prefix(4).map { setting in
                "\(setting.name)\(setting.description.isEmpty ? "" : "：\(setting.description)")"
            }.joined(separator: "；")
            rows.append(SetupAnchorRow(
                key: "world-settings", title: "世界观落点",
                meta: "\(bible.worldSettings.count) 条",
                detail: clipText(summary, 170) ?? "",
                type: "info"
            ))
        }

        // 9. locations — vue:628-642
        if let bible = bible, !bible.locations.isEmpty {
            let summary = bible.locations.prefix(4).map { loc in
                "\(loc.name)\(loc.description.isEmpty ? "" : "：\(loc.description)")"
            }.joined(separator: "；")
            rows.append(SetupAnchorRow(
                key: "locations", title: "关键地点",
                meta: "\(bible.locations.count) 处",
                detail: clipText(summary, 150) ?? "",
                type: "default"
            ))
        }

        // 10. style — vue:644-653
        if let bible = bible {
            let styleSummary = bible.style.isEmpty ? "" : bible.style
            if !styleSummary.isEmpty || !(novel?.lockedWritingStyle.isEmpty ?? true) {
                rows.append(SetupAnchorRow(
                    key: "style", title: "文风公约", meta: "Style",
                    detail: clipText(styleSummary.isEmpty ? novel?.lockedWritingStyle : styleSummary, 170) ?? "",
                    type: "success"
                ))
            }
        }

        // 11. special-requirements — vue:655-663
        if let novel = novel, !novel.lockedSpecialRequirements.isEmpty {
            rows.append(SetupAnchorRow(
                key: "special-requirements", title: "特殊要求", meta: "约束",
                detail: clipText(novel.lockedSpecialRequirements, 150) ?? "",
                type: "warning"
            ))
        }

        return Array(rows.prefix(10))
    }

    private var setupAnchorsLoading: Bool { store.setupAnchorsLoading }

    // MARK: - 预算面板 — StoryEvolutionPanel.vue:115-137
    private var budgetPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("自动写前约束").font(.system(size: 12, weight: .semibold))
                Text("下一章可用叙事预算").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                Spacer()
                Text("内置").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
            }
            VStack(spacing: 3) {
                HStack {
                    Text("叙事预算").font(.system(size: 10, weight: .medium))
                    Spacer()
                    Text(budgetSummary).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                }
                HStack {
                    Text("必须服务").font(.system(size: 10, weight: .medium))
                    Spacer()
                    Text(budgetPromiseTags).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                }
                HStack {
                    Text("连续性").font(.system(size: 10, weight: .medium))
                    Spacer()
                    Text("写作管线会在生成前自动检查角色状态、未完成动作和重复事件。")
                        .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(10)
        .background(Theme.tertiaryBackground)
        .cornerRadius(6)
    }

    private var budgetSummary: String {
        guard let budget = store.governanceState?.chapterBudgetPreview else {
            return "等待治理层生成下一章预算"
        }
        return "第 \(budget.chapterNumber) 章 · 揭秘 \(budget.allowedRevealLevel) · 新线 \(budget.maxNewStorylines) · 债务 \(budget.maxDebtClosures)"
    }

    private var budgetPromiseTags: String {
        let tags = store.governanceState?.chapterBudgetPreview?.mustServePromiseTags ?? []
        return tags.isEmpty ? "无强制承诺标签" : tags.joined(separator: "、")
    }

    // MARK: - 叙事治理 — StoryEvolutionPanel.vue:139-156（L-3修复：issues展示）
    private var governancePanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("叙事治理").font(.system(size: 12, weight: .semibold))
                Text("承诺兑现与结构债务").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                Spacer()
                Text(store.governanceState?.latestReport?.severity ?? "ready")
                    .font(.system(size: 9))
                    .foregroundColor(governanceSeverityColor)
            }
            if let issues = store.governanceState?.latestReport?.issues, !issues.isEmpty {
                ForEach(issues) { issue in
                    HStack {
                        Text(issue.title).font(.system(size: 10, weight: .medium))
                        Spacer()
                        Text(issue.detail).font(.system(size: 9)).foregroundColor(Theme.textTertiary).lineLimit(1)
                    }
                }
            } else {
                Text("没有最新治理风险。").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
            }
        }
        .padding(10)
        .background(Theme.tertiaryBackground)
        .cornerRadius(6)
    }

    // MARK: - 状态连续性 — StoryEvolutionPanel.vue:158-174（P1-5修复）
    private var stateContinuityPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("状态连续性").font(.system(size: 12, weight: .semibold))
                Text("角色、场景与动作证据").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                Spacer()
                Text(store.snapshots.first?.status ?? "empty")
                    .font(.system(size: 9))
                    .foregroundColor(snapshotStatusColor(store.snapshots.first?.status ?? ""))
            }
            ForEach(evidenceRows, id: \.label) { item in
                HStack {
                    Text(item.label).font(.system(size: 10, weight: .medium))
                    Spacer()
                    Text(item.value).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(10)
        .background(Theme.tertiaryBackground)
        .cornerRadius(6)
    }

    private var evidenceRows: [(label: String, value: String)] {
        guard let snap = store.snapshots.first else { return [("状态", "暂无证据")] }
        return [
            ("Source refs", "\(snap.sourceRefs.count) 条"),
            ("Conflicts", "\(snap.conflicts.count) 条"),
            ("Active", store.evolutionBundle?.evolutionSurface?.activeSnapshot?.summary ?? "暂无水化摘要"),
            ("Actions", "\(snap.deltaActions.count) 条标准动作"),
        ]
    }

    // MARK: - 世界线简要 — StoryEvolutionPanel.vue:176-198（P1-6修复）
    private var worldlineBriefPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("世界线").font(.system(size: 12, weight: .semibold))
                Text("检查点、分叉与 HEAD").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                Spacer()
                Button("打开") { activeTab = "worldline" }
                    .buttonStyle(.bordered).controlSize(.mini)
            }
            HStack {
                Text("检查点").font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(worldlineNodeCount) 个").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
            }
            HStack {
                Text("分支").font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(worldlineBranchCount) 条").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
            }
            HStack {
                Text("HEAD").font(.system(size: 10, weight: .medium))
                Spacer()
                Text(worldlineHeadName).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
            }
        }
        .padding(10)
        .background(Theme.tertiaryBackground)
        .cornerRadius(6)
    }

    // MARK: - 风险与修复队列 — StoryEvolutionPanel.vue:201-222（P1-8修复：combinedRisks）
    private var riskQueuePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("风险与修复队列").font(.system(size: 12, weight: .semibold))
                Text("优先处理会阻断生成或污染连续性的项目").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                Spacer()
                Text("\(combinedRisks.count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(combinedRisks.isEmpty ? Theme.success : Theme.warning)
            }
            if combinedRisks.isEmpty {
                Text("当前没有需要拦截的演进风险。")
                    .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
            } else {
                ForEach(Array(combinedRisks.enumerated()), id: \.offset) { _, risk in
                    HStack(spacing: 6) {
                        Text(risk.kind)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(riskColor(risk.type))
                            .cornerRadius(3)
                        Text(risk.title).font(.system(size: 10, weight: .medium))
                        Spacer()
                        Text(risk.detail).font(.system(size: 9)).foregroundColor(Theme.textTertiary).lineLimit(1)
                    }
                    .padding(6)
                    .background(Theme.tertiaryBackground)
                    .cornerRadius(4)
                    .overlay(Rectangle().fill(riskColor(risk.type)).frame(width: 2), alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 合并治理问题+快照冲突 — StoryEvolutionPanel.vue:725-734 combinedRisks
    private struct CombinedRisk {
        let kind: String
        let title: String
        let detail: String
        let type: String // error|warning
    }

    private var combinedRisks: [CombinedRisk] {
        var risks: [CombinedRisk] = []
        // 治理问题
        if let issues = store.governanceState?.latestReport?.issues {
            for issue in issues {
                let type = (issue.severity == "high" || issue.severity == "critical") ? "error" : "warning"
                risks.append(CombinedRisk(kind: "治理", title: issue.title, detail: issue.suggestion ?? issue.detail, type: type))
            }
        }
        // 快照冲突
        if let snap = store.snapshots.first {
            for conflict in snap.conflicts {
                let dict = conflict.value as? [String: Any] ?? [:]
                let conflictType = (dict["conflict_type"] as? String) ?? (dict["type"] as? String) ?? "Conflict"
                let message = (dict["message"] as? String) ?? ""
                let level = (dict["level"] as? String) ?? "warning"
                let type = level == "blocking" ? "error" : "warning"
                risks.append(CombinedRisk(kind: "状态", title: conflictType, detail: message, type: type))
            }
        }
        return Array(risks.prefix(12))
    }

    // MARK: - 状态机 Tab — StoryEvolutionPanel.vue:226-311
    private var stateTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let snap = store.snapshots.first {
                    // 状态摘要 — StoryEvolutionPanel.vue:238-255
                    VStack(alignment: .leading, spacing: 6) {
                        Text("状态树").font(.system(size: 12, weight: .semibold))
                        Text("本章结束时的叙事世界状态").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                        HStack(spacing: 12) {
                            stateMetric("Schema", snap.schemaVersion)
                            stateMetric("状态", snap.status)
                            stateMetric("冲突", "\(snap.conflicts.count)")
                        }
                    }

                    Divider()

                    // 角色状态 — StoryEvolutionPanel.vue:256-270（P2-15修复：角色状态下拉选择）
                    VStack(alignment: .leading, spacing: 6) {
                        Text("角色状态").font(.system(size: 12, weight: .semibold))
                        if let endingDict = snap.endingState?.value as? [String: Any],
                           let characters = endingDict["characters"] as? [String: Any] {
                            ForEach(Array(characters.keys.sorted().prefix(16)), id: \.self) { charId in
                                if let charState = characters[charId] as? [String: Any] {
                                    HStack {
                                        Text((charState["name"] as? String) ?? charId)
                                            .font(.system(size: 11, weight: .medium))
                                        Spacer()
                                        Text((charState["status"] as? String) ?? "alive")
                                            .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                                        // 角色状态修改下拉 — StoryEvolutionPanel.vue:262-268
                                        Menu {
                                            ForEach(characterStatusOptions, id: \.self) { status in
                                                Button(status) {
                                                    Task { await updateCharacterStatus(characterId: charId, status: status, chapterNumber: snap.chapterNumber) }
                                                }
                                            }
                                        } label: {
                                            Text("状态").font(.system(size: 9, weight: .medium))
                                        }
                                        .menuStyle(.borderlessButton)
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // 状态流 — StoryEvolutionPanel.vue:274-295
                    VStack(alignment: .leading, spacing: 6) {
                        Text("状态流").font(.system(size: 12, weight: .semibold))
                        Text("\(snap.deltaActions.count) 个动作 · \(snap.conflicts.count) 个冲突")
                            .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                        if !snap.deltaActions.isEmpty {
                            ForEach(Array(snap.deltaActions.prefix(20)).enumerated().map { $0 }, id: \.offset) { _, action in
                                let dict = action.value as? [String: Any] ?? [:]
                                HStack(spacing: 4) {
                                    Text((dict["type"] as? String) ?? "action")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Theme.info).cornerRadius(3)
                                    Text((dict["action_id"] as? String) ?? action.stringStringValue ?? "")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                        // 冲突展示
                        ForEach(Array(snap.conflicts.prefix(10)).enumerated().map { $0 }, id: \.offset) { _, conflict in
                            let dict = conflict.value as? [String: Any] ?? [:]
                            HStack(spacing: 4) {
                                Text((dict["level"] as? String) ?? "warning")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background((dict["level"] as? String) == "blocking" ? Theme.error : Theme.warning)
                                    .cornerRadius(3)
                                Text((dict["message"] as? String) ?? "")
                                    .font(.system(size: 9)).foregroundColor(Theme.textSecondary)
                            }
                        }
                        if snap.deltaActions.isEmpty && snap.conflicts.isEmpty {
                            Text("暂无动作或冲突记录。").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                        }
                    }

                    Divider()

                    // 证据 — StoryEvolutionPanel.vue:297-311
                    VStack(alignment: .leading, spacing: 6) {
                        Text("证据").font(.system(size: 12, weight: .semibold))
                        Text("用于回放、审计与冲突解释").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                        ForEach(evidenceRows, id: \.label) { item in
                            HStack {
                                Text(item.label).font(.system(size: 10, weight: .medium))
                                Spacer()
                                Text(item.value).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                } else {
                    Text("保存章节后生成演进快照").font(Theme.captionFont()).foregroundColor(Theme.textTertiary).padding()
                }
            }
            .padding(12)
        }
    }

    // MARK: - 角色状态修改 — StoryEvolutionPanel.vue:479-495 updateCharacterStatus（P2-15修复）
    private func updateCharacterStatus(characterId: String, status: String, chapterNumber: Int) async {
        guard let novelId = appState.currentNovelId else { return }
        let escapedId = characterId.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
        let patch = JSONPatchOp(
            op: "replace",
            path: "/characters/\(escapedId)/status",
            value: AnyCodable(status)
        )
        let request = EvolutionOverrideRequest(branchId: "main", patches: [patch])
        await store.applyOverrides(novelId: novelId, chapterNumber: chapterNumber, request: request)
    }

    private func stateMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
        }
    }

    // MARK: - 时间轴 Tab — StoryEvolutionPanel.vue:315-359
    private var timelineTab: some View {
        HStack(spacing: 0) {
            EvolutionNavigatorView(
                slug: appState.currentNovelId ?? "",
                evolutionBundle: store.evolutionBundle,
                evolutionLoading: store.isLoading
            ) { start, end in
                selectedStorylineRange = (start, end)
            }
            .frame(width: 200)

            Divider()

            StoryTimelineView(
                slug: appState.currentNovelId ?? "",
                highlightRange: selectedStorylineRange,
                bundledChronicleRows: store.evolutionBundle?.chronotope?.rows
            ) { event in
                selectedItem = StorySelectedItem(type: "event", data: AnyCodable(event))
            } onSelectSnapshot: { snapshot in
                selectedItem = StorySelectedItem(type: "snapshot", data: AnyCodable(snapshot))
            } onRequestRefresh: {
                if let novelId = appState.currentNovelId {
                    Task { await store.loadBundle(novelId: novelId) }
                }
            }

            Divider()

            StoryDetailPanelView(
                slug: appState.currentNovelId ?? "",
                selectedItem: selectedItem
            ) {
                if let novelId = appState.currentNovelId {
                    Task { await store.loadSnapshots(novelId: novelId) }
                }
            }
            .frame(width: 240)
        }
    }

    // MARK: - 世界线 Tab — StoryEvolutionPanel.vue:54-59
    private var worldlineTab: some View {
        WorldlineDAGView()
    }

    // MARK: - 辅助计算

    private var governanceHitRate: String {
        let rate = store.governanceState?.latestReport?.promiseHitRate
        if let r = rate { return "\(Int(r * 100))%" }
        return "未评估"
    }

    private var governanceHitPercent: Int {
        let rate = store.governanceState?.latestReport?.promiseHitRate
        if let r = rate { return max(0, min(100, Int(r * 100))) }
        return 0
    }

    private var governanceSeverityColor: Color {
        let severity = store.governanceState?.latestReport?.severity ?? "info"
        if severity == "critical" || severity == "high" { return Theme.error }
        if severity == "medium" { return Theme.warning }
        if severity == "low" { return Theme.info }
        return Theme.success
    }

    private var snapshotStatusLabel: String {
        guard let snap = store.snapshots.first else { return "等待章节保存" }
        if snap.conflicts.count > 0 { return "\(snap.conflicts.count) 个冲突待处理" }
        return "连续性可回放"
    }

    private var worldlineSummary: String {
        "\(worldlineBranchCount) 分支 / \(worldlineNodeCount) 存档"
    }

    private var worldlineNodeCount: Int {
        if let dict = store.worldlineGraph?.value as? [String: Any],
           let nodes = dict["nodes"] as? [Any] {
            return nodes.count
        }
        return 0
    }

    private var worldlineBranchCount: Int {
        if let dict = store.worldlineGraph?.value as? [String: Any],
           let branches = dict["branches"] as? [Any] {
            return branches.count
        }
        return 0
    }

    private var worldlineHeadName: String {
        if let dict = store.worldlineGraph?.value as? [String: Any] {
            let headId = dict["head_id"] as? String
            if let nodes = dict["nodes"] as? [[String: Any]], let hid = headId {
                if let head = nodes.first(where: { $0["id"] as? String == hid }) {
                    return head["name"] as? String ?? "未设置"
                }
            }
        }
        return "未设置"
    }

    private func snapshotStatusColor(_ status: String) -> Color {
        switch status {
        case "active": return Theme.success
        case "stale": return Theme.warning
        case "blocked": return Theme.error
        default: return Theme.textSecondary
        }
    }

    private func anchorColor(_ type: String) -> Color {
        switch type {
        case "info": return Theme.info
        case "success": return Theme.success
        case "warning": return Theme.warning
        case "error": return Theme.error
        default: return Theme.textSecondary
        }
    }

    private func riskColor(_ type: String) -> Color {
        type == "error" ? Theme.error : Theme.warning
    }

    /// 文本截断 — StoryEvolutionPanel.vue:509-522
    private func clipText(_ value: String?, _ max: Int) -> String? {
        guard let text = value, !text.isEmpty else { return nil }
        let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        if cleaned.count <= max { return cleaned }
        return String(cleaned.prefix(max)) + "..."
    }
}

// MARK: - StorySelectedItem

struct StorySelectedItem: Equatable {
    let type: String // "event" | "snapshot"
    let data: AnyCodable

    static func == (lhs: StorySelectedItem, rhs: StorySelectedItem) -> Bool {
        lhs.type == rhs.type
    }
}
