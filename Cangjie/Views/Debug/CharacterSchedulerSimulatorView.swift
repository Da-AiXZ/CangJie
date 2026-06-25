//
//  CharacterSchedulerSimulatorView.swift
//  Cangjie
//
//  角色上下文调度模拟器（Debug工具），对齐原版 components/debug/CharacterSchedulerSimulator.vue:1-810。
//  纯前端模拟器，无API调用。展示 AppearanceScheduler + CharacterRegistry 排序算法。
//  硬编码3个角色mock数据，支持大纲提及开关 + 最大角色数滑块 + 排序 + 上下文生成 + Token估算。
//

import SwiftUI

/// 角色上下文调度模拟器（Debug工具）
///
/// 对齐原版 `components/debug/CharacterSchedulerSimulator.vue`。
/// 纯前端模拟器，所有数据硬编码，无API调用。
/// 路由：原版 `/debug/scheduler`（router/index.ts:22），iOS 用 SidebarDestination.debug。
struct CharacterSchedulerSimulatorView: View {

    // MARK: - 角色数据模型（对齐原版 :212-220 Character 接口）

    /// 模拟角色，对齐原版 CharacterSchedulerSimulator.vue:212-220
    private struct SimCharacter: Identifiable, Equatable {
        let id: String
        let name: String
        let importance: String          // 显示文本：主角/主要配角/次要角色
        let importanceLevel: ImportanceLevel
        let activityCount: Int
        let mentalState: String
        let idleBehavior: String
    }

    /// 重要性等级，对齐原版 :216 importanceLevel: 'protagonist' | 'major' | 'minor'
    private enum ImportanceLevel: String, CaseIterable {
        case protagonist   // 主角
        case major         // 主要配角
        case minor         // 次要角色

        /// 优先级数值，对齐原版 :258-262 importancePriority 映射
        /// protagonist=0, major=1, minor=2
        var priority: Int {
            switch self {
            case .protagonist: return 0
            case .major:       return 1
            case .minor:       return 2
            }
        }
    }

    /// 带排序原因的角色，对齐原版 :272-311 sortedQueue 中 Character & { reason: string }
    private struct QueuedCharacter: Identifiable, Equatable {
        let character: SimCharacter
        var reason: String

        var id: String { character.id }
    }

    // MARK: - 硬编码角色库（对齐原版 :222-250）

    /// 角色库，对齐原版 :222-250 allCharacters
    private let allCharacters: [SimCharacter] = [
        SimCharacter(
            id: "char-001",
            name: "林羽",
            importance: "主角",
            importanceLevel: .protagonist,
            activityCount: 50,
            mentalState: "NORMAL",
            idleBehavior: "摸剑柄"
        ),
        SimCharacter(
            id: "char-002",
            name: "艾达",
            importance: "次要角色",
            importanceLevel: .minor,
            activityCount: 1,
            mentalState: "冷漠",
            idleBehavior: "擦拭机械臂"
        ),
        SimCharacter(
            id: "char-003",
            name: "苏晴",
            importance: "主要配角",
            importanceLevel: .major,
            activityCount: 30,
            mentalState: "担忧",
            idleBehavior: "咬嘴唇"
        ),
    ]

    // MARK: - 控制参数（对齐原版 :252-255）

    /// 大纲中提及艾达，对齐原版 :253 mentionedAda = ref(true)
    @State private var mentionedAda: Bool = true

    /// 大纲中提及苏晴，对齐原版 :254 mentionedSuQing = ref(false)
    @State private var mentionedSuQing: Bool = false

    /// 最大召回角色数，对齐原版 :255 maxCharacters = ref(2)
    @State private var maxCharacters: Int = 2

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // 标题区（对齐 :2-11）
                headerSection

                // 控制面板（对齐 :14-56）
                controlPanel

                // 角色卡片网格（对齐 :58-114）
                charactersPanel

                // 调度队列（对齐 :116-144）
                queuePanel

                // 生成的上下文 Prompt（对齐 :146-161）
                contextPanel

                // 算法说明（对齐 :163-203）
                algorithmPanel
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.secondaryBackground)
        .navigationTitle("角色调度模拟器")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 标题区（对齐 :2-11）

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("🎯")
                    .font(.system(size: 28))
                Text("角色上下文调度模拟器")
                    .font(Theme.headlineFont())
                    .foregroundColor(Theme.textPrimary)
            }

            Text("基于 ")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textTertiary)
            +
            Text("AppearanceScheduler")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.primary)
            +
            Text(" 和 ")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textTertiary)
            +
            Text("CharacterRegistry")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.primary)
            +
            Text(" 的排序算法")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - 控制面板（对齐 :14-56）

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // 面板标题
            panelTitle("⚙️", "调度参数")

            // 大纲提及开关（对齐 :22-36）
            VStack(spacing: Theme.Spacing.sm) {
                Toggle("大纲中提及艾达", isOn: $mentionedAda)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)

                Toggle("大纲中提及苏晴", isOn: $mentionedSuQing)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
            }

            Divider()

            // 最大角色数滑块（对齐 :38-55）
            VStack(spacing: Theme.Spacing.xxs) {
                HStack {
                    Text("最大召回角色数量:")
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textSecondary)
                    Text("\(maxCharacters)")
                        .font(Theme.headlineFont())
                        .foregroundColor(Theme.primary)
                }

                Slider(value: Binding(
                    get: { Double(maxCharacters) },
                    set: { maxCharacters = Int($0) }
                ), in: 1...3, step: 1)
                .accentColor(Theme.primary)

                HStack {
                    Text("1")
                    Spacer()
                    Text("2")
                    Spacer()
                    Text("3")
                }
                .font(Theme.captionFont())
                .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - 角色卡片面板（对齐 :58-114）

    private var charactersPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            panelTitle("👥", "角色库")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.md),
                GridItem(.flexible(), spacing: Theme.Spacing.md),
            ], spacing: Theme.Spacing.md) {
                ForEach(allCharacters) { char in
                    characterCard(char)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    /// 单个角色卡片（对齐 :66-113）
    private func characterCard(_ char: SimCharacter) -> some View {
        let mentioned = isMentioned(char.name)
        let selected = isSelected(char)
        let inQueue = isInQueue(char)

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // 头部：名称 + 重要性 badge（对齐 :76-81）
            HStack {
                Text(char.name)
                    .font(Theme.headlineFont())
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text(char.importance)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 3)
                    .background(importanceColor(char.importanceLevel))
                    .cornerRadius(10)
            }

            // 统计信息（对齐 :83-92）
            VStack(spacing: 4) {
                HStack {
                    Text("活动度:")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                    Text("\(char.activityCount)")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textPrimary)
                }

                HStack {
                    Text("心理状态:")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                    Text(char.mentalState)
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textPrimary)
                }
            }

            // 待机动作（对齐 :94-99）
            HStack {
                Text("待机动作:")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textTertiary)
                Text(char.idleBehavior)
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.info)
            }

            // Badges（对齐 :101-111）
            HStack(spacing: Theme.Spacing.xxs) {
                if mentioned {
                    badgeView("✓ 大纲提及", color: Theme.warning)
                }
                if selected {
                    badgeView("✓ 进入上下文", color: Theme.success)
                } else if inQueue {
                    badgeView("✗ 已截断", color: Theme.statusIdle)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(cardBackground(mentioned: mentioned, selected: selected, excluded: !selected && inQueue))
        .cornerRadius(Theme.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .stroke(cardBorderColor(mentioned: mentioned, selected: selected), lineWidth: 2)
        )
        .opacity(!selected && inQueue ? 0.5 : 1.0)
    }

    // MARK: - 调度队列面板（对齐 :116-144）

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            panelTitle("📋", "调度队列")

            VStack(spacing: Theme.Spacing.xs) {
                ForEach(Array(sortedQueue.enumerated()), id: \.element.id) { index, item in
                    queueItem(index: index, item: item)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    /// 单个队列项（对齐 :124-142）
    private func queueItem(index: Int, item: QueuedCharacter) -> some View {
        let isSelectedItem = index < maxCharacters

        return HStack(spacing: Theme.Spacing.sm) {
            // 序号（对齐 :133）
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(isSelectedItem ? Theme.primary : Theme.statusIdle)
                .clipShape(Circle())

            // 名称 + 原因（对齐 :134-136）
            VStack(alignment: .leading, spacing: 2) {
                Text(item.character.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if !item.reason.isEmpty {
                    Text(item.reason)
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                }
            }

            Spacer()

            // 状态（对齐 :138-141）
            Text(isSelectedItem ? "✓ 入选" : "✗ 超出配额")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelectedItem ? Theme.success : Theme.statusIdle)
        }
        .padding(Theme.Spacing.sm)
        .background(
            isSelectedItem
                ? Theme.tertiaryBackground
                : Theme.tertiaryBackground.opacity(0.5)
        )
        .cornerRadius(Theme.CornerRadius.small)
        .overlay(
            Rectangle()
                .frame(width: 4)
                .foregroundColor(isSelectedItem ? Theme.primary : Theme.statusIdle),
            alignment: .leading
        )
        .opacity(isSelectedItem ? 1.0 : 0.5)
    }

    // MARK: - 上下文 Prompt 面板（对齐 :146-161）

    private var contextPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            panelTitle("📝", "生成的上下文 Prompt")

            // 上下文输出（对齐 :153-155）
            Text(generatedContext)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.md)
                .background(Color(.systemBackground))
                .cornerRadius(Theme.CornerRadius.small)

            // 统计（对齐 :157-160）
            HStack(spacing: Theme.Spacing.md) {
                Text("选中角色: \(selectedCharacters.count)")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textTertiary)
                Text("预计 Token: \(estimatedTokens)")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - 算法说明面板（对齐 :163-203）

    private var algorithmPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            panelTitle("🧠", "排序算法逻辑")

            VStack(spacing: Theme.Spacing.sm) {
                algorithmStep(1, "第一优先级：大纲提及", "大纲中提到的角色享有最高优先级，直接排在队列前面")
                algorithmStep(2, "第二优先级：角色重要性", "主角 > 主要配角 > 重要配角 > 次要角色 > 背景角色")
                algorithmStep(3, "第三优先级：活动度", "出场次数越多，优先级越高（保持角色活跃度）")
                algorithmStep(4, "截断策略", "根据 Token 配额限制，从队列头部截取前 N 个角色")
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    /// 单个算法步骤（对齐 :171-201）
    private func algorithmStep(_ number: Int, _ title: String, _ desc: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Theme.primary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(desc)
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.small)
    }

    // MARK: - 排序算法（对齐原版 :264-326）

    /// 判断角色是否在大纲中提及（对齐 :265-269）
    private func isMentioned(_ name: String) -> Bool {
        if name == "艾达" { return mentionedAda }
        if name == "苏晴" { return mentionedSuQing }
        return false
    }

    /// 排序后的队列（对齐 :272-311 sortedQueue computed）
    private var sortedQueue: [QueuedCharacter] {
        var mentioned: [QueuedCharacter] = []
        var notMentioned: [QueuedCharacter] = []

        // 分类：提及 vs 未提及（对齐 :277-288）
        for char in allCharacters {
            let mentionedFlag = isMentioned(char.name)
            let reason = mentionedFlag ? "大纲提及" : ""
            let queued = QueuedCharacter(character: char, reason: reason)

            if mentionedFlag {
                mentioned.append(queued)
            } else {
                notMentioned.append(queued)
            }
        }

        // 对未提及的角色排序：重要性 > 活动度（对齐 :290-307）
        notMentioned.sort { a, b in
            let priorityDiff = a.character.importanceLevel.priority - b.character.importanceLevel.priority
            if priorityDiff != 0 {
                // 在排序过程中设置 reason（对齐 :293-295）
                // 注意：sort 闭包中无法修改 captured 变量，我们在排序后单独设置
                return priorityDiff < 0
            }

            let activityDiff = b.character.activityCount - a.character.activityCount
            if activityDiff != 0 {
                return activityDiff < 0
            }

            return false
        }

        // 为排序后的未提及角色设置 reason（对齐 :294-295, :301-302）
        // 原版在 sort 闭包中设置 reason：priorityDiff!=0 → "重要性"，activityDiff!=0 → "活动度"
        // Swift sort 闭包中无法修改元素，因此在排序后根据排序结果推断 reason
        let notMentionedChars = notMentioned.map { $0.character }
        for i in notMentioned.indices {
            let char = notMentioned[i].character
            // 仅在 notMentioned 范围内检查是否有同优先级的角色
            let samePriorityCount = notMentionedChars.filter { $0.importanceLevel.priority == char.importanceLevel.priority }.count
            if samePriorityCount > 1 {
                // 有同优先级角色 → 通过活动度区分（对齐 :301-302）
                notMentioned[i].reason = "活动度: \(char.activityCount)"
            } else {
                // 无同优先级角色 → 通过重要性区分（对齐 :294-295）
                notMentioned[i].reason = "重要性: \(char.importance)"
            }
        }

        // 合并：提及的角色 + 排序后的未提及角色（对齐 :309-310）
        return mentioned + notMentioned
    }

    /// 选中的角色（对齐 :314-316 selectedCharacters）
    private var selectedCharacters: [QueuedCharacter] {
        Array(sortedQueue.prefix(maxCharacters))
    }

    /// 判断角色是否被选中（对齐 :319-321）
    private func isSelected(_ char: SimCharacter) -> Bool {
        selectedCharacters.contains { $0.character.id == char.id }
    }

    /// 判断角色是否在队列中（对齐 :324-326）
    private func isInQueue(_ char: SimCharacter) -> Bool {
        sortedQueue.contains { $0.character.id == char.id }
    }

    // MARK: - 上下文生成（对齐 :328-347）

    /// 生成的上下文 Prompt（对齐 :329-347 generatedContext computed）
    private var generatedContext: String {
        var context = "【角色设定约束】\n\n"

        for item in selectedCharacters {
            let char = item.character
            context += "角色：\(char.name)\n"
            context += "描述：\(char.importance)\n"
            context += "心理状态：\(char.mentalState)\n"
            context += "待机动作：\(char.idleBehavior)\n"

            // 如果角色刚登场，添加连续性约束（对齐 :338-341）
            if char.activityCount <= 1 {
                context += "[连续性约束] \(char.name) 刚在上一章出场，需保持人设一致性。\n"
            }

            context += "\n"
        }

        return context
    }

    /// 预估 Token 数（对齐 :350-353 estimatedTokens computed）
    /// 粗略估算：1 token ≈ 4 字符
    private var estimatedTokens: Int {
        Int(ceil(Double(generatedContext.count) / 4.0))
    }

    // MARK: - 辅助视图

    /// 面板标题（对齐 :414-422 panel-title）
    private func panelTitle(_ icon: String, _ title: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(icon)
                .font(.system(size: 18))
            Text(title)
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textPrimary)
        }
    }

    /// Badge 视图
    private func badgeView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 3)
            .background(color)
            .cornerRadius(6)
    }

    /// 重要性 badge 颜色（对齐原版 CSS :563-576）
    private func importanceColor(_ level: ImportanceLevel) -> Color {
        switch level {
        case .protagonist: return Color(red: 0xE1/255, green: 0x70/255, blue: 0x55/255) // #e17055
        case .major:       return Color(red: 0xFD/255, green: 0xCB/255, blue: 0x6E/255) // #fdcb6e
        case .minor:       return Color(red: 0x63/255, green: 0x6E/255, blue: 0x72/255) // #636e72
        }
    }

    /// 卡片背景色
    private func cardBackground(mentioned: Bool, selected: Bool, excluded: Bool) -> Color {
        if mentioned {
            return Theme.tertiaryBackground.opacity(0.8)
        }
        return Theme.tertiaryBackground
    }

    /// 卡片边框色（对齐原版 CSS :529-537）
    private func cardBorderColor(mentioned: Bool, selected: Bool) -> Color {
        if selected { return Theme.primary }     // #00cec9 → Theme.primary
        if mentioned { return Theme.warning }    // #fdcb6e → Theme.warning
        return Color.clear
    }
}
