//
//  OutlineStep.swift
//  Cangjie
//
//  向导第3步：宏观规划。
//  SSE 流式渲染大纲（部/卷/幕结构），可编辑后确认。
//  对齐 Vue3 continuous_planning_routes.py 的 SSE 事件格式。
//

import SwiftUI

/// 宏观规划步骤
struct OutlineStep: View {

    @EnvironmentObject var store: OnboardingStore

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if store.isProcessing {
                    // 生成中
                    generatingView
                } else if let structure = store.macroPlanStructure {
                    // 生成完成
                    generatedView(structure)
                } else {
                    // 初始状态
                    startView
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .onAppear {
            if store.macroPlanStructure == nil && !store.isProcessing {
                Task {
                    await store.startMacroPlanning()
                }
            }
        }
    }

    // MARK: - 初始状态

    private var startView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 56))
                .foregroundColor(Theme.primary)

            Text("正在准备宏观规划…")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)

            ProgressView()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // MARK: - 生成中

    private var generatingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 头部
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("正在生成宏观结构…")
                        .font(Theme.headlineFont())
                    Text("AI 正在编排 部 → 卷 → 幕 的故事结构")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // SSE 事件流渲染
            if !store.macroPlanEvents.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(store.macroPlanEvents.indices, id: \.self) { index in
                        let event = store.macroPlanEvents[index]
                        macroEventView(event, isLast: index == store.macroPlanEvents.count - 1)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
            } else {
                // 骨架屏
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.textTertiary.opacity(0.2))
                            .frame(height: 24)
                            .shimmer()
                    }
                }
            }
        }
    }

    // MARK: - 宏观规划事件渲染

    /// 根据事件类型渲染不同视图
    private func macroEventView(_ event: MacroPlanEvent, isLast: Bool) -> some View {
        switch event.type {
        case "status":
            return AnyView(
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(event.message ?? "")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }
            )

        case "chunk":
            return AnyView(
                Text(event.text ?? "")
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textPrimary)
                    + (isLast ? Text("▎").foregroundColor(Theme.primary) : Text(""))
            )

        case "node":
            return AnyView(
                HStack(spacing: Theme.Spacing.xs) {
                    // 节点类型图标
                    Image(systemName: nodeIcon(event.nodeType ?? ""))
                        .foregroundColor(nodeColor(event.nodeType ?? ""))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title ?? "未命名")
                            .font(Theme.bodyFont())
                            .fontWeight(.medium)
                        if let desc = event.description, !desc.isEmpty {
                            Text(desc)
                                .font(Theme.captionFont())
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.vertical, 2)
            )

        case "done":
            return AnyView(
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.success)
                    Text("宏观规划完成")
                        .font(Theme.bodyFont())
                        .fontWeight(.medium)
                }
            )

        case "error":
            return AnyView(
                Label(event.error ?? "生成失败", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.error)
            )

        default:
            return AnyView(EmptyView())
        }
    }

    // MARK: - 生成完成

    private func generatedView(_ structure: [AnyCodable]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // 成功提示
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.success)
                Text("宏观结构已生成，共 \(structure.count) 个顶层节点")
                    .font(Theme.headlineFont())
            }

            // 结构树
            ForEach(structure.indices, id: \.self) { index in
                let part = structure[index]
                structureNodeView(part)
            }

            // 提示
            Text("结构可在工作台的故事结构面板中进一步编辑")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - 结构节点渲染

    private func structureNodeView(_ node: AnyCodable) -> some View {
        let dict = node.dictionaryValue ?? [:]
        let title = dict["title"] as? String ?? ""
        let description = dict["description"] as? String ?? ""
        let nodeType = dict["type"] as? String ?? ""

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: nodeIcon(nodeType))
                    .foregroundColor(nodeColor(nodeType))
                Text(title)
                    .font(Theme.headlineFont())
            }

            if !description.isEmpty {
                Text(description)
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - 辅助

    /// 节点类型图标
    private func nodeIcon(_ type: String) -> String {
        switch type {
        case "part": return "book.fill"
        case "volume": return "books.vertical.fill"
        case "act": return "rectangle.split.3x1.fill"
        default: return "circle.fill"
        }
    }

    /// 节点类型颜色
    private func nodeColor(_ type: String) -> Color {
        switch type {
        case "part": return Theme.primary
        case "volume": return Theme.info
        case "act": return Theme.warning
        default: return Theme.textSecondary
        }
    }
}
