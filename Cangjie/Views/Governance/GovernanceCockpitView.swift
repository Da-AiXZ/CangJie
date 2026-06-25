//
//  GovernanceCockpitView.swift
//  Cangjie
//
//  叙事治理驾驶舱：契约列表/故事线/债务记录/治理报告/预算。
//  TabView 分页，调 GovernanceStore。
//  对齐 Vue3 NarrativeGovernanceCockpit.vue 的交互。
//

import SwiftUI

/// 叙事治理驾驶舱
struct GovernanceCockpitView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var store = GovernanceStore()

    var body: some View {
        TabView {
            // 契约
            contractTab
                .tabItem {
                    Label("契约", systemImage: "doc.text.fill")
                }

            // 故事线
            storylinesTab
                .tabItem {
                    Label("故事线", systemImage: "lineweight")
                }

            // 债务记录
            debtsTab
                .tabItem {
                    Label("债务", systemImage: "creditcard.fill")
                }

            // 治理报告
            reportsTab
                .tabItem {
                    Label("报告", systemImage: "chart.doc.horizontal")
                }

            // 预算预览
            budgetTab
                .tabItem {
                    Label("预算", systemImage: "scalemass.fill")
                }
        }
        .navigationTitle("叙事治理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadState(novelId: novelId)
            }
        }
    }

    // MARK: - 契约 Tab

    private var contractTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let contract = store.contract {
                    if let promise = contract.titlePromise, !promise.isEmpty {
                        contractCard(title: "标题承诺", content: promise, icon: "text.quote")
                    }
                    if let question = contract.coreQuestion, !question.isEmpty {
                        contractCard(title: "核心问题", content: question, icon: "questionmark.circle")
                    }
                    if let anchors = contract.themeAnchors, !anchors.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Label("主题锚点", systemImage: "anchor.fill")
                                .font(Theme.headlineFont())
                            ForEach(anchors, id: \.self) { anchor in
                                Text("• \(anchor)")
                                    .font(Theme.bodyFont())
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .cardStyle()
                    }
                    if let payoffs = contract.forbiddenEarlyPayoffs, !payoffs.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Label("禁止提前兑现", systemImage: "hand.raised.fill")
                                .font(Theme.headlineFont())
                                .foregroundColor(Theme.warning)
                            ForEach(payoffs, id: \.self) { payoff in
                                Text("• \(payoff)")
                                    .font(Theme.bodyFont())
                                    .foregroundColor(Theme.warning)
                            }
                        }
                        .cardStyle()
                    }
                } else {
                    emptyState("暂无治理契约")
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 故事线 Tab

    private var storylinesTab: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if store.storylines.isEmpty {
                    emptyState("暂无故事线")
                } else {
                    ForEach(store.storylines) { storyline in
                        storylineCard(storyline)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 债务 Tab

    private var debtsTab: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if store.debts.isEmpty {
                    emptyState("暂无叙事债务")
                } else {
                    ForEach(store.debts) { debt in
                        debtCard(debt)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 报告 Tab

    private var reportsTab: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if store.reports.isEmpty {
                    emptyState("暂无治理报告")
                } else {
                    ForEach(store.reports) { report in
                        reportCard(report)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 预算 Tab

    private var budgetTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let preview = store.budgetPreview, let budget = preview.budget {
                    if let tags = budget.mustServePromiseTags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Label("本章必须服务的承诺标签", systemImage: "tag.fill")
                                .font(Theme.headlineFont())
                            ForEach(tags, id: \.self) { tag in
                                Text("• \(tag)")
                                    .font(Theme.bodyFont())
                            }
                        }
                        .cardStyle()
                    }

                    if let reveal = budget.availableRevealBudget {
                        budgetItem(label: "可用揭示预算", value: "\(reveal)")
                    }
                    if let load = budget.debtLoad {
                        budgetItem(label: "当前债务负载", value: "\(load)")
                    }
                } else {
                    emptyState("选择章节查看预算预览")
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 卡片组件

    private func contractCard(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label(title, systemImage: icon)
                .font(Theme.headlineFont())
            Text(content)
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)
        }
        .cardStyle()
    }

    private func storylineCard(_ storyline: Storyline) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(storyline.title)
                    .font(Theme.headlineFont())
                Spacer()
                if let status = storyline.status {
                    Text(status)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(storylineStatusColor(status).opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if let aliases = storyline.aliases, !aliases.isEmpty {
                Text("别名：\(aliases.joined(separator: "、"))")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            if let tags = storyline.promiseTags, !tags.isEmpty {
                HStack {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.primary)
                    }
                }
            }

            HStack {
                if let introduced = storyline.introducedChapter {
                    Text("引入：第\(introduced)章")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                if let resolved = storyline.resolvedChapter {
                    Text("闭合：第\(resolved)章")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .cardStyle()
    }

    private func debtCard(_ debt: DebtRecord) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(debt.type ?? "未知类型")
                    .font(Theme.headlineFont())
                Spacer()
                if let severity = debt.severity {
                    Text(severity)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(debtSeverityColor(severity).opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if let desc = debt.description, !desc.isEmpty {
                Text(desc)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
            }

            HStack {
                if let chapter = debt.chapter {
                    Text("第\(chapter)章")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                if let status = debt.status {
                    Text(status)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .cardStyle()
    }

    private func reportCard(_ report: GovernanceReport) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("报告 #\(report.id.prefix(8))")
                    .font(Theme.headlineFont())
                Spacer()
                if let status = report.status {
                    Text(status)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            if let chapter = report.chapterNumber {
                Text("第\(chapter)章")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }

            if let issues = report.issues, !issues.isEmpty {
                Text("违规项：\(issues.count)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.warning)
            }
        }
        .cardStyle()
    }

    private func budgetItem(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.bodyFont())
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.primary)
        }
        .cardStyle()
    }

    // MARK: - 辅助

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(Theme.textTertiary)
            Text(message)
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private func storylineStatusColor(_ status: String) -> Color {
        switch status {
        case "active", "open": return Theme.success
        case "resolved", "closed": return Theme.textTertiary
        case "abandoned": return Theme.error
        default: return Theme.textSecondary
        }
    }

    private func debtSeverityColor(_ severity: String) -> Color {
        switch severity {
        case "critical", "high": return Theme.error
        case "medium": return Theme.warning
        case "low": return Theme.info
        default: return Theme.textSecondary
        }
    }
}
