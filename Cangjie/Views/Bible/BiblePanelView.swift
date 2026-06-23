//
//  BiblePanelView.swift
//  Cangjie
//
//  Bible 设定集 TabView 分页（世界观/角色/地点/时间线/文风），调 BibleStore。
//  对齐 Vue3 Bible 面板的分页交互。
//

import SwiftUI

/// Bible 设定集面板
struct BiblePanelView: View {

    let novelId: String

    @StateObject private var bibleStore = BibleStore()

    var body: some View {
        VStack(spacing: 0) {
            if bibleStore.isLoading {
                VStack(spacing: Theme.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载设定集…")
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            } else if let bible = bibleStore.bible {
                TabView {
                    // 角色页
                    charactersTab(bible.characters)
                        .tabItem {
                            Label("角色 (\(bible.characters.count))", systemImage: "person.2.fill")
                        }

                    // 世界设定页
                    worldSettingsTab(bible.worldSettings)
                        .tabItem {
                            Label("世界观 (\(bible.worldSettings.count))", systemImage: "globe.asia.australia.fill")
                        }

                    // 地点页
                    locationsTab(bible.locations)
                        .tabItem {
                            Label("地点 (\(bible.locations.count))", systemImage: "mappin.and.ellipse")
                        }

                    // 时间线页
                    timelineTab(bible.timelineNotes)
                        .tabItem {
                            Label("时间线 (\(bible.timelineNotes.count))", systemImage: "clock.fill")
                        }

                    // 文风页
                    styleTab(bible.styleNotes, style: bible.style)
                        .tabItem {
                            Label("文风", systemImage: "textformat")
                        }
                }
                .tabViewStyle(.automatic)
            } else {
                emptyState
            }
        }
        .navigationTitle("设定集")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await bibleStore.loadBible(novelId: novelId)
        }
        .alert("错误", isPresented: .constant(bibleStore.errorMessage != nil)) {
            Button("确定") { bibleStore.errorMessage = nil }
        } message: {
            Text(bibleStore.errorMessage ?? "")
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(Theme.textTertiary)

            Text("暂无设定集")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)

            Text("请在新书向导中生成 Bible 设定集")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - 角色 Tab

    private func charactersTab(_ characters: [CharacterDTO]) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(characters) { character in
                    CharacterProfileCard(character: character)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 世界设定 Tab

    private func worldSettingsTab(_ settings: [WorldSettingDTO]) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(settings) { setting in
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Image(systemName: "globe.asia.australia.fill")
                                .foregroundColor(Theme.primary)
                            Text(setting.name)
                                .font(Theme.headlineFont())
                            Spacer()
                            Text(setting.settingType)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.info.opacity(0.2))
                                .cornerRadius(4)
                        }
                        if !setting.description.isEmpty {
                            Text(setting.description)
                                .font(Theme.bodyFont())
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 地点 Tab

    private func locationsTab(_ locations: [LocationDTO]) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(locations) { location in
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(Theme.primary)
                            Text(location.name)
                                .font(Theme.headlineFont())
                            Spacer()
                            Text(location.locationType)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.warning.opacity(0.2))
                                .cornerRadius(4)
                        }
                        if !location.description.isEmpty {
                            Text(location.description)
                                .font(Theme.bodyFont())
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 时间线 Tab

    private func timelineTab(_ notes: [TimelineNoteDTO]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(notes) { note in
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        // 时间线节点
                        VStack {
                            Circle()
                                .fill(Theme.primary)
                                .frame(width: 10, height: 10)
                            Rectangle()
                                .fill(Theme.textTertiary.opacity(0.3))
                                .frame(width: 2)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.timePoint)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.primary)
                            Text(note.event)
                                .font(Theme.bodyFont())
                            if !note.description.isEmpty {
                                Text(note.description)
                                    .font(Theme.captionFont())
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 文风 Tab

    private func styleTab(_ notes: [StyleNoteDTO], style: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if !style.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("文风总述")
                            .font(Theme.headlineFont())
                        Text(style)
                            .font(Theme.bodyFont())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .cardStyle()
                }

                if !notes.isEmpty {
                    Text("风格笔记")
                        .font(Theme.headlineFont())
                        .padding(.top, Theme.Spacing.sm)

                    ForEach(notes) { note in
                        HStack {
                            Text(note.category)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.primary)
                                .frame(width: 80, alignment: .leading)
                            Text(note.content)
                                .font(Theme.bodyFont())
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }
}
