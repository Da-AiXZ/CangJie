//
//  StoryPipelineObservabilityView.swift
//  Cangjie
//
//  故事管道可观测性，对齐原版 components/autopilot/StoryPipelineObservability.vue:1-308。
//  十步管线轨道 + 章后8步网格 + 事件轨迹 + aftermathOnly模式。
//

import SwiftUI

/// 故事管道可观测性视图
///
/// 对齐原版 `components/autopilot/StoryPipelineObservability.vue`。
/// 展示 StoryPipeline 十步进度 + 章后管线8步细分 + 事件轨迹。
struct StoryPipelineObservabilityView: View {

    /// 自动驾驶状态（对齐 :125-128 props.status）
    let status: AutopilotStatus?

    /// 仅显示章后管线（对齐 :127 props.aftermathOnly）
    var aftermathOnly: Bool = false

    // MARK: - 轮询 tick（对齐 :132-135 usePolling 1s）

    @State private var tick: Int = 0
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    // MARK: - 计算属性

    /// 当前波次索引（对齐 :137-140 currentIx）
    private var currentIx: Int {
        guard let n = status?.storyPipelineWaveIndex else { return 0 }
        return n >= 1 && n <= 10 ? n : 0
    }

    /// 波次进入时间（对齐 :142-145 enteredAt）
    private var enteredAt: Double? {
        guard let t = status?.storyPipelineWaveEnteredAt, t.isFinite else { return nil }
        return t
    }

    /// 停留时间显示（对齐 :148-157 dwellLine）
    private var dwellLine: String {
        guard let ea = enteredAt, currentIx >= 1 else { return "" }
        let s = max(0, Int(Date().timeIntervalSince1970 - ea))
        if s < 60 { return "本步已停留 \(s) 秒" }
        let m = s / 60
        let r = s % 60
        return "本步已停留 \(m) 分 \(r) 秒"
    }

    /// 事件列表（对齐 :172-175 events）
    private var events: [StoryPipelineEvent] {
        return status?.storyPipelineEvents ?? []
    }

    /// 显示事件（最后12条倒序，对齐 :177-180 displayEvents）
    private var displayEvents: [StoryPipelineEvent] {
        return events.suffix(12).reversed()
    }

    /// 节点卡（wave 3/4 时显示，对齐 :182-196 genCard）
    private var genCard: (label: String, detail: String, wordHint: String) {
        let ix = currentIx
        let chapterTarget = status?.chapterTargetWords ?? 0
        let label: String = ix == 3 ? "剧本生成" : ix == 4 ? "正文撰写" : ""
        let detail: String = ix == 3
            ? (status?.writingSubstepLabel ?? "生成导演剧本")
            : ix == 4 ? "实时撰写正文中（目标 \(chapterTarget > 0 ? "\(chapterTarget)" : "?") 字）" : ""
        let wordHint = chapterTarget > 0 ? "目标 \(chapterTarget) 字" : ""
        return (label, detail, wordHint)
    }

    /// aftermathRunning（对齐 :231-234）
    private var aftermathRunning: Bool {
        let sub = status?.writingSubstep ?? ""
        return currentIx == 8 || sub == "audit_aftermath" || sub == "chapter_aftermath" || sub == "chapter_aftermath_done"
    }

    /// aftermathLiveStatus（对齐 :208）
    private var aftermathLiveStatus: String {
        return status?.aftermathLiveStatus ?? ""
    }

    /// showAftermathCard（对齐 :282-286）
    private var showAftermathCard: Bool {
        if currentIx == 8 { return true }
        if currentIx > 8 && aftermathSteps.contains(where: { $0.state == .done || $0.state == .fail }) { return true }
        return aftermathRunning
    }

    /// aftermathSummary（对齐 :288-298）
    private var aftermathSummary: String {
        let failed = aftermathSteps.filter { $0.state == .fail }.count
        let done = aftermathSteps.filter { $0.state == .done }.count
        if aftermathRunning && aftermathLiveStatus != "done" {
            let current = aftermathSteps.first(where: { $0.state == .current })
            return current?.label ?? status?.writingSubstepLabel ?? "实时处理中"
        }
        if failed > 0 { return "\(failed) 项需复查" }
        if done > 0 { return "\(done)/\(aftermathSteps.count) 已确认" }
        return "等待章后结果"
    }

    // MARK: - 章后8步（对齐 :245-280 aftermathSteps）

    enum AftermathState: String {
        case done, current, pending, fail
    }

    struct AftermathStep: Identifiable {
        let index: Int
        let id: String
        let label: String
        let detail: String
        let state: AftermathState
    }

    /// stepState（对齐 :225-229）
    private func stepState(_ value: Bool?, failWhenFalse: Bool = false) -> AftermathState {
        if value == true { return .done }
        if value == false && failWhenFalse { return .fail }
        return .pending
    }

    /// activeAftermathIndex（对齐 :236-243）
    private var activeAftermathIndex: Int {
        guard aftermathRunning && aftermathLiveStatus != "done" else { return 0 }
        guard let ea = enteredAt else { return 1 }
        let elapsed = max(0, Int(Date().timeIntervalSince1970 - ea))
        return min(8, elapsed / 3 + 1)
    }

    /// aftermathSteps（对齐 :245-280）
    private var aftermathSteps: [AftermathStep] {
        let s = status
        let liveFailed = aftermathLiveStatus == "failed"
        var steps: [AftermathStep] = [
            AftermathStep(index: 1, id: "summary", label: "摘要事件", detail: "摘要 / 事件 / 场景信号", state: stepState(s?.narrativeSyncOk, failWhenFalse: liveFailed)),
            AftermathStep(index: 2, id: "beats", label: "叙事节拍", detail: "beat_sections 对齐", state: stepState(s?.narrativeSyncOk, failWhenFalse: liveFailed)),
            AftermathStep(index: 3, id: "vector", label: "向量索引", detail: "语义检索落库", state: stepState(s?.vectorStored)),
            AftermathStep(index: 4, id: "foreshadow", label: "伏笔账本", detail: "埋线 / 兑现记录", state: stepState(s?.foreshadowStored)),
            AftermathStep(index: 5, id: "kg", label: "KG 三元组", detail: "实体关系抽取", state: stepState(s?.triplesExtracted)),
            AftermathStep(index: 6, id: "causal", label: "因果边", detail: "动作后果链路", state: stepState(s?.causalEdgesStored)),
            AftermathStep(index: 7, id: "character", label: "角色状态", detail: "立场 / 情绪投影", state: stepState(s?.characterMutationsStored ?? s?.characterReconcileOk)),
            AftermathStep(index: 8, id: "debt", label: "叙事债务", detail: "承诺 / 风险更新", state: stepState(s?.debtUpdated ?? s?.evolutionSnapshotOk)),
        ]

        if aftermathRunning && aftermathLiveStatus != "done" {
            let ix = activeAftermathIndex
            steps = steps.map { step in
                if step.state == .done || step.state == .fail { return step }
                if step.index < ix { return AftermathStep(index: step.index, id: step.id, label: step.label, detail: step.detail, state: .done) }
                if step.index == ix { return AftermathStep(index: step.index, id: step.id, label: step.label, detail: step.detail, state: .current) }
                return step
            }
        }
        return steps
    }

    // MARK: - stepClass / doneCheck（对齐 :159-170）

    private func stepClass(_ ix: Int) -> String {
        let c = currentIx
        if c <= 0 { return "muted" }
        if ix == c { return "current" }
        if ix < c { return "done" }
        return "pending"
    }

    private func doneCheck(_ ix: Int) -> Bool {
        return currentIx > 0 && ix < currentIx
    }

    /// fmtRel（对齐 :300-307）
    private func fmtRel(_ t: Double) -> String {
        guard t > 0 else { return "—" }
        let s = max(0, Int(Date().timeIntervalSince1970 - t))
        if s < 45 { return "\(s)s 前" }
        if s < 3600 { return "\(s / 60)m 前" }
        return "\(s / 3600)h 前"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 对齐 :3-9 header（aftermathOnly时隐藏）
            if !aftermathOnly {
                HStack {
                    HStack(spacing: 8) {
                        Text("StoryPipeline · 一章十步")
                            .font(.system(size: 13, weight: .bold))
                        Text("实时")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.success.opacity(0.2))
                            .cornerRadius(999)
                            .foregroundColor(Theme.success)
                    }
                    Spacer()
                    if !dwellLine.isEmpty {
                        Text(dwellLine)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            // 对齐 :11-24 十步轨道（aftermathOnly时隐藏）
            if !aftermathOnly {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(STORY_PIPELINE_WAVES) { wave in
                            stepCard(wave)
                        }
                    }
                }
            }

            // 对齐 :27-37 节点卡（wave 3/4 时显示）
            if !aftermathOnly && (currentIx == 3 || currentIx == 4) && !genCard.label.isEmpty {
                beatCard
            }

            // 对齐 :39-61 章后管线网格
            if showAftermathCard {
                aftermathCard
            }

            // 对齐 :63-76 事件轨迹（aftermathOnly时隐藏）
            if !aftermathOnly && events.count > 1 {
                eventTrackSection
            } else if !aftermathOnly && events.count == 1 {
                Text(events[0].label ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(aftermathOnly ? 0 : 12)
        .onReceive(timer) { _ in tick += 1 }
    }

    // MARK: - 十步卡片（对齐 :13-23）

    private func stepCard(_ wave: StoryPipelineWave) -> some View {
        let cls = stepClass(wave.index)
        let isDone = doneCheck(wave.index)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text("\(wave.index)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(cls == "current" ? Theme.primary : cls == "done" ? Theme.success : Theme.textTertiary)
                if isDone {
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.success)
                }
            }
            Text(wave.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(cls == "current" ? Theme.primary : cls == "done" ? Theme.textPrimary : Theme.textTertiary)
        }
        .frame(width: 86, alignment: .leading)
        .padding(8)
        .background(
            Group {
                if cls == "current" {
                    Theme.primary.opacity(0.1)
                } else if cls == "done" {
                    Theme.success.opacity(0.05)
                } else {
                    Theme.secondaryBackground
                }
            }
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cls == "current" ? Theme.primary.opacity(0.3) : cls == "done" ? Theme.success.opacity(0.2) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .opacity(cls == "pending" || cls == "muted" ? 0.58 : 1.0)
    }

    // MARK: - 节点卡（对齐 :27-37）

    private var beatCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(genCard.label)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.primary.opacity(0.15))
                    .cornerRadius(999)
                    .foregroundColor(Theme.primary)
                if !genCard.wordHint.isEmpty {
                    Text(genCard.wordHint)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            Text(genCard.detail)
                .font(.system(size: 11))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
        }
        .padding(8)
        .background(Theme.primary.opacity(0.08))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.primary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - 章后管线网格（对齐 :39-61）

    private var aftermathCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("章后管线 · 叙事 / 向量 / KG")
                    .font(.system(size: 11, weight: .heavy))
                Spacer()
                Text(aftermathSummary)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
            }

            // 4列网格
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(aftermathSteps) { step in
                    aftermathStepCell(step)
                }
            }
        }
        .padding(10)
        .background(Theme.primary.opacity(0.04))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.primary.opacity(0.15), lineWidth: 1))
    }

    private func aftermathStepCell(_ step: AftermathStep) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(step.index)")
                .font(.system(size: 9, weight: .heavy))
                .frame(width: 18, height: 18)
                .background(stepColor(step.state).opacity(0.15))
                .foregroundColor(stepColor(step.state))
                .cornerRadius(999)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text(step.label)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(step.state == .current ? Theme.primary : Theme.textPrimary)
                    if step.state == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.success)
                    } else if step.state == .fail {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.warning)
                    } else if step.state == .current {
                        Circle()
                            .fill(Theme.primary)
                            .frame(width: 7, height: 7)
                    }
                }
                Text(step.detail)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(7)
        .background(stepBg(step.state))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(stepBorder(step.state), lineWidth: 1)
        )
        .opacity(step.state == .pending ? 0.72 : 1.0)
    }

    private func stepColor(_ state: AftermathState) -> Color {
        switch state {
        case .done: return Theme.success
        case .current: return Theme.primary
        case .fail: return Theme.warning
        case .pending: return Theme.textTertiary
        }
    }

    private func stepBg(_ state: AftermathState) -> Color {
        switch state {
        case .done: return Theme.success.opacity(0.06)
        case .current: return Theme.primary.opacity(0.08)
        case .fail: return Theme.warning.opacity(0.07)
        case .pending: return Theme.secondaryBackground
        }
    }

    private func stepBorder(_ state: AftermathState) -> Color {
        switch state {
        case .done: return Theme.success.opacity(0.28)
        case .current: return Theme.primary.opacity(0.3)
        case .fail: return Theme.warning.opacity(0.34)
        case .pending: return Color.gray.opacity(0.2)
        }
    }

    // MARK: - 事件轨迹（对齐 :63-76）

    private var eventTrackSection: some View {
        DisclosureGroup("事件轨迹（\(events.count)）") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(displayEvents.enumerated()), id: \.offset) { _, ev in
                    HStack(spacing: 6) {
                        Text(fmtRel(ev.t))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                        if let wave = ev.wave {
                            Text("波次 \(wave)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.primary)
                        }
                        if let label = ev.label {
                            Text(label)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        if let sub = ev.substep {
                            Text(sub)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .font(.system(size: 11))
    }
}
