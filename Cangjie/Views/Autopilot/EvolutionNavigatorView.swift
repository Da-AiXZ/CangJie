//
//  EvolutionNavigatorView.swift
//  Cangjie
//
//  故事导航器（故事阶段+故事线树+汇流轴），对齐 StoryNavigator.vue:1-646。
//

import SwiftUI

struct EvolutionNavigatorView: View {
    let slug: String
    let evolutionBundle: StoryEvolutionReadModel?
    let evolutionLoading: Bool
    var onSelectStoryline: ((Int, Int) -> Void)? = nil

    @State private var phase: StoryPhaseDTO? = nil
    @State private var allStorylines: [StorylineDTO] = []
    @State private var confluenceList: [ConfluencePoint] = []

    private let phaseStages = [
        ("setup", "起"), ("rising", "升"), ("midpoint", "转"),
        ("climax", "高潮"), ("resolution", "结"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            phaseSection
            Divider()
            storylinesSection
            if !confluenceList.isEmpty {
                Divider()
                confluenceSection
            }
        }
        .background(Theme.secondaryBackground)
        .onAppear { loadData() }
        .onChange(of: evolutionBundle) { _ in loadData() }
    }

    // MARK: - 故事阶段 — StoryNavigator.vue:5-35
    private var phaseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("📊").font(.system(size: 12))
                Text("故事阶段").font(.system(size: 12, weight: .semibold))
            }
            if let phase = phase {
                HStack(spacing: 8) {
                    ForEach(phaseStages, id: \.0) { value, label in
                        VStack(spacing: 2) {
                            Circle()
                                .fill(isPhasePast(value, currentPhase: phase.phase ?? "") ? Theme.primary : Theme.textTertiary.opacity(0.3))
                                .frame(width: value == phase.phase ? 12 : 8, height: value == phase.phase ? 12 : 8)
                            Text(label).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                        }
                    }
                }
                if let progress = phase.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(Theme.primary)
                }
            } else {
                Text("暂无阶段数据").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
            }
        }
        .padding(12)
    }

    // MARK: - 故事线树 — StoryNavigator.vue:38-122
    private var storylinesSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("📖").font(.system(size: 12))
                    Text("故事线").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("+") { }
                        .buttonStyle(.borderless).font(.system(size: 11))
                }

                if allStorylines.isEmpty {
                    Text("暂无故事线").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                        .padding(.vertical, 12)
                } else {
                    // 主线
                    ForEach(mainStorylines) { sl in
                        storylineItem(sl, isMain: true)
                        // 子故事线
                        ForEach(childrenOf(sl)) { child in
                            storylineItem(child, isMain: false, indent: true)
                        }
                    }
                    // 孤立故事线
                    ForEach(orphanLines) { sl in
                        storylineItem(sl, isMain: false)
                    }
                }
            }
            .padding(12)
        }
    }

    private func storylineItem(_ sl: StorylineDTO, isMain: Bool, indent: Bool = false) -> some View {
        Button {
            let start = sl.estimatedChapterStart ?? 1
            let end = sl.estimatedChapterEnd ?? start + 9
            onSelectStoryline?(start, end)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if indent { Text("└─").font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.textTertiary) }
                    if isMain {
                        Text("主线")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Theme.success).cornerRadius(3)
                    }
                    Text(sl.name ?? "故事线 \(sl.id.prefix(8))")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    if let status = sl.status {
                        Text(status)
                            .font(.system(size: 8))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                if let start = sl.estimatedChapterStart, let end = sl.estimatedChapterEnd {
                    Text("第 \(start)–\(end) 章")
                        .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(6)
        .background(isMain ? Theme.success.opacity(0.06) : Theme.tertiaryBackground.opacity(0.5))
        .cornerRadius(4)
        .overlay(
            Rectangle()
                .fill(isMain ? Theme.success : Theme.warning)
                .frame(width: 2), alignment: .leading
        )
    }

    // MARK: - 汇流轴 — StoryNavigator.vue:125-150
    private var confluenceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⑂").font(.system(size: 12))
                Text("汇流轴").font(.system(size: 12, weight: .semibold))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(confluenceList, id: \.id) { cp in
                        VStack(spacing: 2) {
                            Circle()
                                .fill(cp.resolved ? Theme.textTertiary.opacity(0.4) : Theme.primary)
                                .frame(width: 22, height: 22)
                            Text("第\(cp.targetChapter)章")
                                .font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(12)
    }

    // MARK: - 数据
    private var mainStorylines: [StorylineDTO] {
        allStorylines.filter { $0.role == "main" || $0.role == nil }
    }
    private func childrenOf(_ parent: StorylineDTO) -> [StorylineDTO] {
        allStorylines.filter { $0.parentId == parent.id }
    }
    private var orphanLines: [StorylineDTO] {
        allStorylines.filter { $0.role != "main" && $0.role != nil && $0.parentId == nil }
    }

    private func isPhasePast(_ phase: String, currentPhase: String) -> Bool {
        let order = ["setup", "rising", "midpoint", "climax", "resolution"]
        guard let p1 = order.firstIndex(of: phase), let p2 = order.firstIndex(of: currentPhase) else { return false }
        return p1 < p2
    }

    /// 加载数据 — StoryNavigator.vue:428-454 loadData
    /// P2-16修复：从 evolutionBundle.plotSpine 解析 confluence_points
    private func loadData() {
        if let bundle = evolutionBundle {
            phase = bundle.lifeCycle
            allStorylines = bundle.plotSpine?.storylines ?? []
            // P2-16修复：从 plotSpine 解析 confluence_points
            if let plotSpineDict = bundle.plotSpine?.plotArc?.value as? [String: Any],
               let confluencePoints = plotSpineDict["confluence_points"] as? [[String: Any]] {
                confluenceList = confluencePoints.compactMap { dict in
                    guard let id = dict["id"] as? String,
                          let targetChapter = dict["target_chapter"] as? Int else { return nil }
                    return ConfluencePoint(
                        id: id,
                        targetChapter: targetChapter,
                        resolved: dict["resolved"] as? Bool ?? false,
                        mergeType: dict["merge_type"] as? String ?? "intersect",
                        contextSummary: dict["context_summary"] as? String ?? ""
                    )
                }
            }
        }
    }
}

// MARK: - ConfluencePoint 辅助
struct ConfluencePoint: Identifiable {
    let id: String
    let targetChapter: Int
    let resolved: Bool
    let mergeType: String
    let contextSummary: String
}
