//
//  PropManagerPanel.swift
//  Cangjie
//
//  道具管理（道具列表+事件流+持有者变更），调 PropStore。
//

import SwiftUI

struct PropManagerPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = PropStore()
    @State private var selectedProp: PropDTO?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                if store.props.isEmpty {
                    Text("暂无道具").font(Theme.captionFont()).foregroundColor(Theme.textTertiary).padding()
                } else {
                    ForEach(store.props) { prop in
                        propRow(prop)
                    }
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadProps(novelId: novelId)
            }
        }
        .sheet(item: $selectedProp) { prop in
            propDetailSheet(prop)
        }
    }

    private func propRow(_ prop: PropDTO) -> some View {
        Button { selectedProp = prop } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "shippingbox.fill").foregroundColor(categoryColor(prop.propCategory))
                    Text(prop.name).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(prop.lifecycleState).font(.system(size: 9)).foregroundColor(lifecycleColor(prop.lifecycleState))
                }
                if !prop.description.isEmpty {
                    Text(prop.description).font(.system(size: 10)).foregroundColor(Theme.textTertiary).lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func propDetailSheet(_ prop: PropDTO) -> some View {
        NavigationStack {
            List {
                Section("道具信息") {
                    LabeledContent("名称", value: prop.name)
                    LabeledContent("类别", value: prop.propCategory)
                    LabeledContent("状态", value: prop.lifecycleState)
                    if let ch = prop.introducedChapter { LabeledContent("引入章节", value: "第\(ch)章") }
                }
                Section("事件流") {
                    ForEach(store.currentPropEvents) { event in
                        VStack(alignment: .leading) {
                            Text(event.eventType).font(.system(size: 12, weight: .medium))
                            Text("第\(event.chapterNumber)章 · \(event.source)").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                            if !event.description.isEmpty { Text(event.description).font(.system(size: 11)).foregroundColor(Theme.textSecondary) }
                        }
                    }
                }
            }
            .navigationTitle(prop.name)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if let novelId = appState.currentNovelId {
                    await store.loadPropEvents(novelId: novelId, propId: prop.id)
                }
            }
        }
    }

    private func categoryColor(_ c: String) -> Color {
        switch c { case "WEAPON": return Theme.error; case "ARMOR": return Theme.info; case "CONSUMABLE": return Theme.success; default: return Theme.textSecondary }
    }
    private func lifecycleColor(_ s: String) -> Color {
        switch s { case "DORMANT": return Theme.textTertiary; case "ACTIVE": return Theme.success; case "RESOLVED": return Theme.info; default: return Theme.textSecondary }
    }
}
