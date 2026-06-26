//
//  WorldbuildingPanel.swift
//  Cangjie
//
//  世界观五维度编辑（物理/社会/魔法/科技/文化），表单，调 BibleStore。
//

import SwiftUI

struct WorldbuildingPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var bibleStore = BibleStore()

    // E-5：Worldbuilding API 状态
    @State private var worldbuilding: Worldbuilding?
    @State private var isLoadingWorldbuilding: Bool = false
    @State private var worldbuildingError: String?

    private let apiClient = APIClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // E-5：Worldbuilding API 数据（维度展示）
                if let wb = worldbuilding {
                    worldbuildingDimensionsSection(wb)
                } else if isLoadingWorldbuilding {
                    ProgressView("加载世界观…")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let error = worldbuildingError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.error)
                        .padding()
                }

                Divider()

                // Bible 世界设定列表（原有功能保留）
                if let bible = bibleStore.bible {
                    // 世界设定列表
                    ForEach(bible.worldSettings) { setting in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "globe.asia.australia.fill").foregroundColor(Theme.primary)
                                Text(setting.name).font(Theme.headlineFont())
                                Spacer()
                                Text(setting.settingType).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                            }
                            if !setting.description.isEmpty {
                                Text(setting.description).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                            }
                        }
                    }

                    Divider()

                    // 文风
                    if !bible.style.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("文风公约").font(.system(size: 12, weight: .semibold))
                            Text(bible.style).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        }
                    }

                    // 风格笔记
                    ForEach(bible.styleNotes) { note in
                        HStack {
                            Text(note.category).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.primary).frame(width: 60, alignment: .leading)
                            Text(note.content).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        }
                    }
                } else {
                    Text("暂无世界观数据")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await bibleStore.loadBible(novelId: novelId)
                // E-5：加载 Worldbuilding API 数据
                await loadWorldbuilding(novelId: novelId)
            }
        }
    }

    // MARK: - E-5 Worldbuilding API

    /// 加载世界观数据 — worldbuilding.ts:49-52 GET /novels/{novelId}/worldbuilding
    private func loadWorldbuilding(novelId: String) async {
        isLoadingWorldbuilding = true
        do {
            worldbuilding = try await apiClient.request(
                APIEndpoint.Worldbuilding.get(novelId: novelId)
            )
            worldbuildingError = nil
        } catch {
            worldbuilding = nil
            worldbuildingError = "世界观加载失败"
        }
        isLoadingWorldbuilding = false
    }

    /// 保存世界观数据 — worldbuilding.ts:54-55 PUT /novels/{novelId}/worldbuilding
    private func saveWorldbuilding(novelId: String) async {
        guard let wb = worldbuilding else { return }
        do {
            let _: Worldbuilding = try await apiClient.request(
                APIEndpoint.Worldbuilding.update(novelId: novelId),
                body: wb
            )
            worldbuildingError = nil
        } catch {
            worldbuildingError = "世界观保存失败"
        }
    }

    /// 世界观维度展示
    @ViewBuilder
    private func worldbuildingDimensionsSection(_ wb: Worldbuilding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("世界观五维度")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                // E-5：保存按钮
                Button {
                    if let novelId = appState.currentNovelId {
                        Task { await saveWorldbuilding(novelId: novelId) }
                    }
                } label: {
                    Label("保存", systemImage: "checkmark.circle")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // 核心法则
            dimensionRow("核心法则", icon: "hammer.fill", color: Theme.primary)

            // 地理生态
            dimensionRow("地理生态", icon: "map.fill", color: Theme.info)

            // 社会结构
            dimensionRow("社会结构", icon: "building.2.fill", color: Theme.warning)

            // 历史文化
            dimensionRow("历史文化", icon: "book.closed.fill", color: Theme.success)

            // 沉浸感细节
            dimensionRow("沉浸感细节", icon: "eye.fill", color: Theme.textSecondary)
        }
    }

    private func dimensionRow(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
