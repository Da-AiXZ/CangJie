//
//  ForeshadowRadarView.swift
//  Cangjie
//
//  伏笔雷达（autopilot只读版），对齐原版 components/autopilot/ForeshadowLedger.vue:1-308。
//  统计3列 + 3Tab弹窗 + 轮询 + 请求取消。复用ForeshadowEntry模型，View层映射。
//

import SwiftUI

/// 伏笔雷达视图（autopilot只读版）
///
/// 对齐原版 `components/autopilot/ForeshadowLedger.vue`。
/// 与 workbench 版 ForeshadowLedgerPanel 区分：本组件是只读摘要，无 CRUD。
/// 复用 ForeshadowEntry 模型，View层做映射（对齐 :242-251 映射逻辑）。
struct ForeshadowRadarView: View {

    /// 小说 ID（对齐 :176 props.novelId）
    let novelId: String

    /// 最多显示几条最近伏笔（对齐 :177 props.maxRecent，默认5）
    var maxRecent: Int = 5

    /// 刷新信号（对齐 :178 props.refreshKey，变化时重新拉数据）
    var refreshKey: Int = 0

    // MARK: - 状态

    @StateObject private var store = ForeshadowStore()

    /// 是否显示全部弹窗（对齐 :182 showLedgerModal）
    @State private var showLedgerModal: Bool = false

    /// 轮询 timer（对齐 :271-274 usePolling）
    @State private var pollTick: Int = 0
    private let pollTimer = Timer.publish(every: 15.0, on: .main, in: .common).autoconnect()

    // MARK: - 映射模型（对齐 :165-173 Foreshadow 接口，View层映射）

    /// 映射后的伏笔项（对齐 :242-251 映射逻辑）
    private struct RadarForeshadow: Identifiable, Equatable {
        let id: String
        let description: String
        let importance: String  // 原版硬编码 'medium'
        let plantedChapter: Int
        let isCollected: Bool
        let collectedChapter: Int?
        let createdAt: String
    }

    /// 从 ForeshadowEntry 映射为 RadarForeshadow（对齐 :242-251）
    private var radarForeshadows: [RadarForeshadow] {
        return store.entries.map { entry in
            RadarForeshadow(
                id: entry.id,
                description: entry.question,                    // :244 description: entry.question
                importance: "medium",                            // :245 importance: 'medium' as const
                plantedChapter: entry.chapter,                   // :246 planted_chapter: entry.chapter
                isCollected: entry.status == "consumed",         // :247 is_collected: entry.status === 'consumed'
                collectedChapter: entry.consumedAtChapter,       // :248 collected_chapter: entry.consumed_at_chapter ?? undefined
                createdAt: entry.createdAt                       // :249 created_at: entry.created_at
            )
        }
    }

    // MARK: - 统计计算（对齐 :189-204）

    private var totalCount: Int { radarForeshadows.count }
    private var collectedCount: Int { radarForeshadows.filter { $0.isCollected }.count }
    private var pendingCount: Int { totalCount - collectedCount }
    private var collectionRate: Int {
        guard totalCount > 0 else { return 0 }
        return Int(Double(collectedCount) / Double(totalCount) * 100)
    }
    private var avgInterval: Int {
        let collected = radarForeshadows.filter { $0.isCollected && $0.collectedChapter != nil }
        guard !collected.isEmpty else { return 0 }
        let intervals = collected.map { ($0.collectedChapter ?? 0) - $0.plantedChapter }
        return intervals.reduce(0, +) / intervals.count
    }

    // MARK: - 分类列表（对齐 :215-217）

    private var allForeshadows: [RadarForeshadow] { radarForeshadows }
    private var pendingForeshadows: [RadarForeshadow] { radarForeshadows.filter { !$0.isCollected } }
    private var collectedForeshadows: [RadarForeshadow] { radarForeshadows.filter { $0.isCollected } }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 对齐 :3-23 header
            header

            // 对齐 :25-48 body
            VStack(spacing: 14) {
                // 对齐 :27-40 统计卡片
                statsGrid

                // 对齐 :43-48 空状态
                if radarForeshadows.isEmpty && !store.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.textTertiary)
                        Text("暂无伏笔记录")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
        }
        .padding(14)
        .background(Theme.secondaryBackground)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        .task {
            // 对齐 :300-303 onMounted → startPolling
            await loadForeshadows()
        }
        .onReceive(pollTimer) { _ in
            // 对齐 :271-274 usePolling
            if novelId.isNotEmpty {
                Task { await loadForeshadows() }
            }
        }
        .onChange(of: refreshKey) { newKey in
            // 对齐 :296-298 watch refreshKey
            if newKey > 0 {
                Task { await loadForeshadows() }
            }
        }
        .onChange(of: novelId) { _ in
            // 对齐 :290-293 watch novelId
            Task { await loadForeshadows() }
        }
        .sheet(isPresented: $showLedgerModal) {
            // 对齐 :52-150 全部伏笔弹窗
            ledgerSheet
        }
    }

    // MARK: - Header（对齐 :3-23）

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📖 伏笔雷达")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            Text("只读摘要 · 编辑见侧栏伏笔账本")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)

            HStack(spacing: 10) {
                // 对齐 :12-14 已回收Tag
                Text("已回收 \(collectedCount)")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.success.opacity(0.15))
                    .cornerRadius(999)
                    .foregroundColor(Theme.success)

                // 对齐 :15-17 待回收Tag
                Text("待回收 \(pendingCount)")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.warning.opacity(0.15))
                    .cornerRadius(999)
                    .foregroundColor(Theme.warning)

                Spacer()

                // 对齐 :18-20 查看全部按钮
                Button("查看全部") {
                    showLedgerModal = true
                }
                .font(.system(size: 12))
            }
        }
    }

    // MARK: - 统计卡片（对齐 :27-40）

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statCard(label: "总计", value: "\(totalCount)")
            statCard(label: "回收率", value: "\(collectionRate)%")
            statCard(label: "平均间隔", value: "\(avgInterval) 章")
        }
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.tertiaryBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    // MARK: - 全部伏笔弹窗（对齐 :52-150）

    private var ledgerSheet: some View {
        NavigationStack {
            TabView {
                // 对齐 :59-92 全部Tab
                foreshadowList(title: "全部", items: allForeshadows)
                    .tabItem { Text("全部") }

                // 对齐 :93-120 待回收Tab
                foreshadowList(title: "待回收", items: pendingForeshadows)
                    .tabItem { Text("待回收") }

                // 对齐 :121-148 已回收Tab
                foreshadowList(title: "已回收", items: collectedForeshadows)
                    .tabItem { Text("已回收") }
            }
            .navigationTitle("伏笔账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showLedgerModal = false }
                }
            }
        }
    }

    // MARK: - 伏笔列表（对齐 :62-91）

    private func foreshadowList(title: String, items: [RadarForeshadow]) -> some View {
        ScrollView {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Text("暂无数据")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        foreshadowItemCard(item)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - 伏笔项卡片（对齐 :62-91）

    private func foreshadowItemCard(_ item: RadarForeshadow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 对齐 :69-79 header
            HStack {
                // 对齐 :70-76 重要性Tag
                Text(importanceLabel(item.importance))
                    .font(.system(size: 12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.info.opacity(0.1))
                    .cornerRadius(4)
                    .foregroundColor(Theme.info)

                Spacer()

                // 对齐 :77-79 收回状态
                Text(item.isCollected ? "✓ 已回收" : "⏳ 待回收")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }

            // 对齐 :81 描述
            Text(item.description)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)

            // 对齐 :82-89 meta
            HStack(spacing: 4) {
                Text("第 \(item.plantedChapter) 章埋设")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                if item.isCollected, let cc = item.collectedChapter {
                    Text("· 第 \(cc) 章回收")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(12)
        .background(Theme.tertiaryBackground)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        .opacity(item.isCollected ? 0.7 : 1.0)
    }

    // MARK: - 重要性标签（对齐 :220-221 getForeshadowImportanceLabel）

    private func importanceLabel(_ importance: String) -> String {
        switch importance {
        case "critical": return "危急"
        case "high": return "重要"
        case "medium": return "一般"
        case "low": return "次要"
        default: return importance
        }
    }

    // MARK: - 加载（对齐 :224-264 loadForeshadows）

    private func loadForeshadows() async {
        await store.loadEntries(novelId: novelId)
    }
}

// MARK: - String 扩展

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}
