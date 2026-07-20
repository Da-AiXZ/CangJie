import CangJieCore
import Foundation
import SwiftUI

private struct OpeningPlanApprovalReview: Identifiable {
    let approval: ApprovalRequest
    let planBody: String

    var id: UUID { approval.id }
}

private struct ChapterReviewReference: Identifiable {
    let versionID: UUID
    let contentHash: String

    var id: UUID { versionID }
}

private struct NovelProjectsPage: View {
    @ObservedObject var model: AppViewModel
    let onBack: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(model: AppViewModel, onBack: (() -> Void)? = nil) {
        self.model = model
        self.onBack = onBack
    }

    var body: some View {
        List {
            if model.projects.isEmpty {
                Section {
                    Text("还没有小说。和仓颉聊出第一个需要长期保存的正式成果后，它才会出现在这里。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("novel-projects-empty-state")
                }
            } else {
                Section("我的小说") {
                    ForEach(Array(model.projects.enumerated()), id: \.element.id) { index, project in
                        let progressDescription = model.novelProgressByProjectID[project.id]
                            ?? "进度暂不可用"
                        NavigationLink {
                            NovelProjectDetailPage(
                                model: model,
                                project: project,
                                progressDescription: progressDescription
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(project.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(progressDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .accessibilityIdentifier("novel-project-progress-\(index)")
                                Text("最近更新：\(project.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("novel-project-row-\(index)")
                        .accessibilityHint("只在左侧打开书籍详情，不会切换当前创作对话")
                    }
                }
            }

            Section {
                Button {
                    model.reloadProjects()
                } label: {
                    Label("刷新书架", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("projects-refresh-button")

                if let notice = model.transientNotice, notice.kind == .projectRefresh {
                    Label(notice.message, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("project-refresh-feedback")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("novel-projects-page")
        .navigationTitle("我的小说")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if let onBack {
                        onBack()
                    } else {
                        dismiss()
                    }
                } label: {
                    Label("返回仓颉", systemImage: "chevron.backward")
                }
                .accessibilityIdentifier("novel-projects-back-button")
            }
        }
    }
}

private struct NovelProjectDetailPage: View {
    @ObservedObject var model: AppViewModel
    let project: NovelProject
    let progressDescription: String
    @State private var readableContent: S1ReadableContentProjection?
    @Environment(\.dismiss) private var dismiss

    init(
        model: AppViewModel,
        project: NovelProject,
        progressDescription: String
    ) {
        self.model = model
        self.project = project
        self.progressDescription = progressDescription
        _readableContent = State(initialValue: nil)
    }

    var body: some View {
        List {
            Section {
                Text(project.title)
                    .font(.headline)
                    .accessibilityIdentifier("novel-project-detail-title")
                Text(project.premise.isEmpty ? "还没有可展示的简介" : project.premise)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("novel-project-detail-premise")
                Text("最近更新：\(project.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("novel-project-detail-updated-at")
            } header: {
                Text("这本书")
            }

            Section("当前做到哪") {
                Text(progressDescription)
                    .font(.headline)
                    .accessibilityIdentifier("novel-project-detail-progress")
                Text("这里现在只展示已经保存的小说信息。浏览不会切换当前创作对话，也不会启动模型、生成章节或执行项目操作。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("novel-project-detail-stage-note")
            }

            if let readableContent {
                Section("正文") {
                    NavigationLink {
                        NovelProjectBrowserReaderPage(content: readableContent)
                    } label: {
                        Label("打开正文", systemImage: "book.pages")
                    }
                    .accessibilityIdentifier("novel-project-detail-open-reader")
                    .accessibilityHint("只读打开这本书已保存的正文，不会切换当前创作对话")
                }
            }

        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("novel-project-detail-page")
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            readableContent = model.readableContentForBrowsing(projectID: project.id)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("返回书架", systemImage: "chevron.backward")
                }
                .accessibilityIdentifier("novel-project-detail-back-button")
            }
        }
    }

}

private struct NovelProjectBrowserReaderPage: View {
    let content: S1ReadableContentProjection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(content.projectTitle)
                        .font(.headline)
                        .accessibilityIdentifier("novel-project-browser-reader-project-title")
                    Text(content.chapterTitle)
                        .font(.title2.bold())
                        .accessibilityIdentifier("novel-project-browser-reader-chapter-title")
                    Text(content.statusDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("novel-project-browser-reader-status")
                }

                Divider()

                Text(content.body)
                    .font(.body)
                    .lineSpacing(8)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("novel-project-browser-reader-body")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("novel-project-browser-reader")
        .navigationTitle("阅读正文")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("返回详情", systemImage: "chevron.backward")
                }
                .accessibilityIdentifier("novel-project-browser-reader-back-button")
            }
        }
    }
}

private struct S1TasksPage: View {
    let onBack: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("当前状态") {
                    Text("当前没有正在进行的 AI 任务。这个版本只验证界面、导航和本地保存，尚未接入真正的模型任务。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ai-tasks-empty-state")
                }
            }
            .navigationTitle("AI 任务")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        Label("返回仓颉", systemImage: "chevron.backward")
                    }
                    .accessibilityIdentifier("ai-tasks-back-button")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai-tasks-page")
    }
}

private struct S1SettingsPage: View {
    @Binding var showsConversationTimestamps: Bool
    let onBack: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("对话列表") {
                    Toggle("显示更新时间", isOn: $showsConversationTimestamps)
                        .accessibilityIdentifier("settings-conversation-time-toggle")
                    Text("这个设置只改变左侧对话列表，立即生效并会在下次启动时保留。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings-conversation-time-note")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        Label("返回仓颉", systemImage: "chevron.backward")
                    }
                    .accessibilityIdentifier("settings-back-button")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-page")
    }
}

struct ContentView: View {
    @ObservedObject var model: AppViewModel
    @State private var reviewedOpeningPlan: OpeningPlanApprovalReview?
    @State private var reviewedChapter: ChapterReviewReference?
    @State private var selectedActivity: S1ActivityDestination = .conversation
    @State private var selectedPrimaryFocus: S1WorkspacePrimaryFocus = .conversation
    @State private var isPortraitNavigationPresented = false
    @AppStorage("s1.showsConversationTimestamps") private var showsConversationTimestamps = true
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let mode = S1WorkspaceLayoutContract.mode(
                width: Double(geometry.size.width),
                height: Double(geometry.size.height)
            )

            workspace(mode: mode, size: geometry.size)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onChange(of: model.hasReadableContent) { hasReadableContent in
            selectedPrimaryFocus = S1WorkspaceLayoutContract.normalizedFocus(
                selectedPrimaryFocus,
                hasReadableContent: hasReadableContent
            )
            if selectedPrimaryFocus != .results {
                model.isArtifactDrawerPresented = false
            }
        }
        .sheet(item: $reviewedOpeningPlan) { review in
            OpeningPlanApprovalDetailView(
                model: model,
                approval: review.approval,
                planBody: review.planBody
            )
        }
        .sheet(item: $reviewedChapter) { review in
            ChapterReviewDetailView(
                model: model,
                displayedVersionID: review.versionID,
                displayedContentHash: review.contentHash
            )
        }
    }

    @ViewBuilder
    private func workspace(mode: S1WorkspaceLayoutMode, size: CGSize) -> some View {
        switch mode {
        case .landscapeColumns:
            landscapeWorkspace(size: size)
        case .portraitSingleFocus:
            portraitWorkspace(size: size)
        }
    }

    @ViewBuilder
    private func landscapeWorkspace(size: CGSize) -> some View {
        if model.hasReadableContent {
            landscapeReadableWorkspace(size: size)
        } else {
            landscapeConversationWorkspace(size: size)
        }
    }

    private func landscapeConversationWorkspace(size: CGSize) -> some View {
        let activityWidth: CGFloat = 56
        let railWidth: CGFloat = 250
        let dividerWidth: CGFloat = 1
        let resultsWidth = model.isArtifactDrawerPresented
            ? min(320, max(280, size.width * 0.28))
            : 0
        let conversationLeading = activityWidth + dividerWidth + railWidth + dividerWidth
        let conversationTrailing = resultsWidth > 0 ? resultsWidth + dividerWidth : 0
        let conversationWidth = max(0, size.width - conversationLeading - conversationTrailing)

        return ZStack(alignment: .topLeading) {
            Color(uiColor: .systemGroupedBackground)

            conversation
                .frame(width: conversationWidth, height: size.height)
                .offset(x: conversationLeading)
                .allowsHitTesting(selectedActivity == .conversation)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("landscape-conversation-region")
                .accessibilityHidden(selectedActivity != .conversation)

            activityBar
                .frame(width: activityWidth, height: size.height)
                .allowsHitTesting(selectedActivity == .conversation)
                .accessibilityHidden(selectedActivity != .conversation)

            Color(uiColor: .separator)
                .frame(width: dividerWidth, height: size.height)
                .accessibilityHidden(true)
                .offset(x: activityWidth)

            conversationRail
                .frame(width: railWidth, height: size.height)
                .offset(x: activityWidth + dividerWidth)
                .allowsHitTesting(selectedActivity == .conversation)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("landscape-conversation-rail")
                .accessibilityHidden(selectedActivity != .conversation)

            Color(uiColor: .separator)
                .frame(width: dividerWidth, height: size.height)
                .accessibilityHidden(true)
                .offset(x: activityWidth + dividerWidth + railWidth)

            if resultsWidth > 0 {
                Color(uiColor: .separator)
                    .frame(width: dividerWidth, height: size.height)
                    .accessibilityHidden(true)
                    .offset(x: size.width - resultsWidth - dividerWidth)
                artifacts
                    .frame(width: resultsWidth, height: size.height)
                    .offset(x: size.width - resultsWidth)
                    .allowsHitTesting(selectedActivity == .conversation)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("landscape-results-region")
                    .accessibilityHidden(selectedActivity != .conversation)
            }

            if selectedActivity != .conversation {
                landscapeIndependentPageOverlay(
                    size: size,
                    leading: activityWidth + dividerWidth
                )
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace-landscape-columns")
    }

    private func landscapeReadableWorkspace(size: CGSize) -> some View {
        let activityWidth: CGFloat = 56
        let railWidth: CGFloat = 250
        let dividerWidth: CGFloat = 1
        let mainLeading = activityWidth + dividerWidth + railWidth + dividerWidth
        let mainWidth = max(0, size.width - mainLeading)
        let widthProjection = S1WorkspaceLayoutContract.readableWorkspaceWidths(
            availableWidth: Double(mainWidth),
            dividerWidth: Double(dividerWidth)
        )
        let readerWidth = CGFloat(widthProjection?.readerWidth ?? 0)
        let companionWidth = CGFloat(widthProjection?.companionWidth ?? 0)

        return ZStack(alignment: .topLeading) {
            Color(uiColor: .systemGroupedBackground)

            VStack(spacing: 0) {
                reader
            }
            .frame(width: readerWidth, height: size.height)
            .offset(x: mainLeading)
            .allowsHitTesting(selectedActivity == .conversation)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("landscape-reader-region")
            .accessibilityHidden(selectedActivity != .conversation)

            Color(uiColor: .separator)
                .frame(width: dividerWidth, height: size.height)
                .accessibilityHidden(true)
                .offset(x: mainLeading + readerWidth)

            readerCompanionRegion
                .frame(width: companionWidth, height: size.height)
                .offset(x: mainLeading + readerWidth + dividerWidth)
                .allowsHitTesting(selectedActivity == .conversation)
                .accessibilityHidden(selectedActivity != .conversation)

            activityBar
                .frame(width: activityWidth, height: size.height)
                .allowsHitTesting(selectedActivity == .conversation)
                .accessibilityHidden(selectedActivity != .conversation)

            Color(uiColor: .separator)
                .frame(width: dividerWidth, height: size.height)
                .accessibilityHidden(true)
                .offset(x: activityWidth)

            conversationRail
                .frame(width: railWidth, height: size.height)
                .offset(x: activityWidth + dividerWidth)
                .allowsHitTesting(selectedActivity == .conversation)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("landscape-conversation-rail")
                .accessibilityHidden(selectedActivity != .conversation)

            Color(uiColor: .separator)
                .frame(width: dividerWidth, height: size.height)
                .accessibilityHidden(true)
                .offset(x: activityWidth + dividerWidth + railWidth)

            if selectedActivity != .conversation {
                landscapeIndependentPageOverlay(
                    size: size,
                    leading: activityWidth + dividerWidth
                )
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace-landscape-columns")
    }

    private var readerCompanionRegion: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                readerCompanionTab(title: "仓颉", showsResults: false)
                readerCompanionTab(title: "这次结果", showsResults: true)
            }
            .padding(8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            Divider()

            if model.isArtifactDrawerPresented {
                artifacts
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("reader-companion-results")
            } else {
                conversation
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("reader-companion-conversation")
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-companion-region")
    }

    private func readerCompanionTab(title: String, showsResults: Bool) -> some View {
        let isSelected = model.isArtifactDrawerPresented == showsResults
        return Button {
            isComposerFocused = false
            selectedPrimaryFocus = showsResults ? .results : .conversation
            model.isArtifactDrawerPresented = showsResults
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 9)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            showsResults ? "reader-companion-results-tab" : "reader-companion-conversation-tab"
        )
        .accessibilityValue(isSelected ? "当前页面" : "未选择")
    }
    private func landscapeIndependentPageOverlay(size: CGSize, leading: CGFloat) -> some View {
        let panelWidth = min(380, max(320, size.width * 0.34))

        return ZStack(alignment: .topLeading) {
            Button {
                dismissIndependentLeftSurface()
            } label: {
                Color.black.opacity(0.16)
                    .frame(width: max(0, size.width - leading), height: size.height)
            }
            .buttonStyle(.plain)
            .offset(x: leading)
            .accessibilityLabel("关闭左侧页面")
            .accessibilityIdentifier("landscape-left-overlay-dismiss")

            leftRegion
                .frame(width: panelWidth, height: size.height)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(alignment: .trailing) {
                    Color(uiColor: .separator)
                        .frame(width: 1)
                        .accessibilityHidden(true)
                }
                .offset(x: leading)
                .shadow(color: .black.opacity(0.14), radius: 16, x: 5, y: 0)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("landscape-left-page-overlay")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func portraitWorkspace(size: CGSize) -> some View {
        let topBarHeight: CGFloat = 54
        let contentHeight = max(0, size.height - topBarHeight)
        let focus = S1WorkspaceLayoutContract.normalizedFocus(
            selectedPrimaryFocus,
            hasReadableContent: model.hasReadableContent
        )
        let showingReader = focus == .reader
        let showingConversation = focus == .conversation
        let showingResults = focus == .results
        let showingNavigation = isPortraitNavigationPresented || selectedActivity != .conversation

        return ZStack(alignment: .topLeading) {
            Color(uiColor: .systemGroupedBackground)

            if model.hasReadableContent {
                VStack(spacing: 0) {
                    reader
                }
                .frame(width: size.width, height: contentHeight)
                .offset(y: topBarHeight)
                .opacity(showingReader ? 1 : 0)
                .allowsHitTesting(showingReader && !showingNavigation)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("portrait-reader-region")
                .accessibilityHidden(!showingReader || showingNavigation)
            }

            conversation
                .frame(width: size.width, height: contentHeight)
                .offset(y: topBarHeight)
                .opacity(showingConversation ? 1 : 0)
                .allowsHitTesting(showingConversation && !showingNavigation)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("portrait-conversation-region")
                .accessibilityHidden(!showingConversation || showingNavigation)

            artifacts
                .frame(width: size.width, height: contentHeight)
                .offset(y: topBarHeight)
                .opacity(showingResults ? 1 : 0)
                .allowsHitTesting(showingResults && !showingNavigation)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("portrait-results-region")
                .accessibilityHidden(!showingResults || showingNavigation)

            portraitTopBar
                .frame(width: size.width, height: topBarHeight)
                .allowsHitTesting(!showingNavigation)
                .accessibilityHidden(showingNavigation)

            if isPortraitNavigationPresented || selectedActivity != .conversation {
                portraitNavigationOverlay(size: size)
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace-portrait-single-focus")
    }
    private var portraitTopBar: some View {
        HStack(spacing: 10) {
            Button {
                isComposerFocused = false
                isPortraitNavigationPresented = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开导航")
            .accessibilityHint("从左侧打开对话历史、我的小说、AI 任务和设置")
            .accessibilityIdentifier("portrait-navigation-open")

            ForEach(
                S1WorkspaceLayoutContract.availableFocuses(hasReadableContent: model.hasReadableContent),
                id: \.self
            ) { focus in
                Button {
                    selectPortraitFocus(focus)
                } label: {
                    Text(primaryFocusTitle(focus))
                        .font(.subheadline.weight(isPortraitFocusSelected(focus) ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isPortraitFocusSelected(focus)
                                ? Color.accentColor.opacity(0.14)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("portrait-focus-\(focus.rawValue)")
                .accessibilityValue(isPortraitFocusSelected(focus) ? "当前页面" : "未选择")
            }
        }
        .padding(.horizontal, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("portrait-focus-bar")
    }

    private func portraitNavigationOverlay(size: CGSize) -> some View {
        let panelWidth = min(400, max(320, size.width * 0.88))

        return ZStack(alignment: .topLeading) {
            Button {
                dismissIndependentLeftSurface()
            } label: {
                Color.black.opacity(0.22)
                    .frame(width: size.width, height: size.height)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭导航")
            .accessibilityIdentifier("portrait-navigation-dismiss")

            VStack(spacing: 0) {
                HStack {
                    Text("导航")
                        .font(.headline)
                    Spacer()
                    Button {
                        dismissIndependentLeftSurface()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭导航")
                    .accessibilityIdentifier("portrait-navigation-close")
                }
                .padding(12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(S1ActivityBarContract.visibleItems, id: \.destination) { item in
                            Button {
                                selectActivityDestination(item.destination)
                            } label: {
                                Label(item.title, systemImage: systemImageName(for: item.iconRole))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedActivity == item.destination
                                            ? Color.accentColor.opacity(0.14)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 9)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("portrait-activity-\(item.destination.rawValue)")
                            .accessibilityValue(
                                selectedActivity == item.destination ? "当前页面" : "未选择"
                            )
                            .accessibilityHint(item.purpose)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }

                Divider()
                leftRegion
            }
            .frame(width: panelWidth, height: size.height)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(alignment: .trailing) {
                    Color(uiColor: .separator)
                        .frame(width: 1)
                        .accessibilityHidden(true)
                }
            .shadow(color: .black.opacity(0.18), radius: 18, x: 6, y: 0)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("portrait-left-page-overlay")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func dismissIndependentLeftSurface() {
        isPortraitNavigationPresented = false
        selectedActivity = .conversation
    }

    private func selectActivityDestination(_ destination: S1ActivityDestination) {
        if destination != .conversation {
            isComposerFocused = false
        }
        selectedActivity = destination
    }

    private func toggleResultsDrawer() {
        let willShowResults = !model.isArtifactDrawerPresented
        if willShowResults {
            isComposerFocused = false
        }
        selectedPrimaryFocus = willShowResults ? .results : .conversation
        model.isArtifactDrawerPresented = willShowResults
    }

    private func selectPortraitFocus(_ focus: S1WorkspacePrimaryFocus) {
        let normalized = S1WorkspaceLayoutContract.normalizedFocus(
            focus,
            hasReadableContent: model.hasReadableContent
        )
        if normalized != .conversation {
            isComposerFocused = false
        }
        selectedPrimaryFocus = normalized
        model.isArtifactDrawerPresented = normalized == .results
    }

    private func isPortraitFocusSelected(_ focus: S1WorkspacePrimaryFocus) -> Bool {
        S1WorkspaceLayoutContract.normalizedFocus(
            selectedPrimaryFocus,
            hasReadableContent: model.hasReadableContent
        ) == focus
    }
    private func primaryFocusTitle(_ focus: S1WorkspacePrimaryFocus) -> String {
        switch focus {
        case .reader:
            return "阅读"
        case .conversation:
            return "仓颉"
        case .results:
            return "这次结果"
        }
    }

    private var activityBar: some View {
        VStack(spacing: 8) {
            ForEach(S1ActivityBarContract.visibleItems, id: \.destination) { item in
                Button {
                    selectActivityDestination(item.destination)
                } label: {
                    Image(systemName: systemImageName(for: item.iconRole))
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedActivity == item.destination ? Color.accentColor : Color.secondary)
                .background(
                    selectedActivity == item.destination ? Color.accentColor.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .accessibilityIdentifier("activity-bar-\(item.destination.rawValue)")
                .accessibilityLabel(item.title)
                .accessibilityValue(selectedActivity == item.destination ? "当前页面" : "未选择")
                .accessibilityHint(item.purpose)
                .contextMenu {
                    Label(item.title, systemImage: systemImageName(for: item.iconRole))
                    Text(item.purpose)
                        .accessibilityIdentifier("activity-help-\(item.destination.rawValue)")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-bar")
    }

    @ViewBuilder
    private var leftRegion: some View {
        switch selectedActivity {
        case .conversation:
            conversationRail
        case .novels:
            NavigationStack {
                NovelProjectsPage(model: model) {
                    selectedActivity = .conversation
                }
            }
        case .tasks:
            S1TasksPage {
                selectedActivity = .conversation
            }
        case .settings:
            S1SettingsPage(showsConversationTimestamps: $showsConversationTimestamps) {
                selectedActivity = .conversation
            }
        }
    }

    private var conversationRail: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        model.startNewS1Conversation()
                    } label: {
                        Label("新建对话", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("new-conversation-button")

                    if model.conversations.isEmpty {
                        Text("还没有保存的对话")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("conversation-history-empty")
                    } else {
                        ForEach(Array(model.conversations.enumerated()), id: \.element.id) { index, conversation in
                            conversationHistoryRow(conversation, index: index)
                        }
                    }
                } header: {
                    Text("对话")
                        .accessibilityIdentifier("conversations-heading")
                }
            }
            .navigationTitle("对话")
        }
    }

    private func systemImageName(for role: S1ActivityIconRole) -> String {
        switch role {
        case .conversation:
            return "bubble.left.and.bubble.right"
        case .library:
            return "books.vertical"
        case .taskQueue:
            return "checklist"
        case .settings:
            return "gearshape"
        }
    }

    private func conversationHistoryRow(_ conversation: AgentConversation, index: Int) -> some View {
        let isSelected = model.selectedConversationID == conversation.id
        let updatedAt = conversation.updatedAt.formatted(date: .abbreviated, time: .shortened)

        return Button {
            model.selectS1Conversation(conversation.id)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .lineLimit(2)
                        .accessibilityIdentifier("conversation-title-\(index)")
                    if showsConversationTimestamps {
                        Text(updatedAt)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("conversation-time-\(index)")
                    }
                }
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("conversation-row-\(index)")
        .accessibilityLabel(
            showsConversationTimestamps
                ? "\(conversation.title)，更新时间 \(updatedAt)"
                : conversation.title
        )
        .accessibilityValue(isSelected ? "当前对话" : "未选择")
        .accessibilityHint("切换到这个对话")
    }

    private var reader: some View {
        ScrollView {
            if let readableContent = model.readableContent {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(readableContent.projectTitle)
                            .font(.title3.weight(.semibold))
                            .accessibilityIdentifier("reader-project-title")
                        Text(readableContent.chapterTitle)
                            .font(.title.bold())
                            .accessibilityIdentifier("reader-chapter-title")
                        Text(readableContent.statusDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("reader-status")
                    }

                    Divider()

                    Text(readableContent.body)
                        .font(.body)
                        .lineSpacing(8)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("reader-body")
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-region")
    }
    private var conversation: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("仓颉")
                        .font(.title2.bold())
                        .accessibilityIdentifier("agent-control-plane-title")
                    Text(model.businessStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("agent-business-status")
                    if let errorMessage = model.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("app-error-message")
                    }
                    if let notice = model.transientNotice {
                        Label(notice.message, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("transient-notice")
                    }
                }
                Spacer()
                Button {
                    toggleResultsDrawer()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .accessibilityLabel(
                    model.isArtifactDrawerPresented ? "收起这次结果" : "显示这次结果"
                )
                .accessibilityIdentifier("result-drawer-toggle")
            }
            .padding()
            Divider()
            if !model.isAgentExecutionAllowed {
                VStack(alignment: .leading, spacing: 6) {
                    Label("这个版本还没有完全启用", systemImage: "exclamationmark.shield.fill")
                        .font(.headline)
                    Text("为了保护你的小说，仓颉暂时不会执行会改动内容的操作。未发送的文字已经保留。")
                        .font(.footnote)
                    Text("请彻底关闭仓颉后重新打开。如果仍然看到这个提示，再重启 iPad 后重试。")
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .foregroundStyle(.red)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityIdentifier("build-activation-blocker")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if model.hasEarlierConversationMessages {
                        Label(
                            "已显示最近的对话，更早内容会在后续滚动加载。",
                            systemImage: "clock.arrow.circlepath"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("conversation-history-window-notice")
                    }
                    if shouldShowWelcomePage {
                        welcomePage
                    }
                    ForEach(Array(model.conversationMessages.enumerated()), id: \.offset) { index, message in
                        Text(message)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.background, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("conversation-message-\(index)")
                    }
                }
                .padding()
            }
            if let approval = pendingOpeningPlanApproval {
                pendingApprovalCard(approval)
            }
            if let chapter = pendingChapterReview {
                pendingChapterReviewCard(chapter)
            }
            if let chapter = pendingRewriteScopeApproval {
                pendingRewriteScopeCard(chapter)
            }
            HStack(alignment: .bottom) {
                ZStack(alignment: .topLeading) {
                    if model.draft.isEmpty {
                        Text("随便说点什么……")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("agent-composer-placeholder")
                    }
                    TextEditor(text: $model.draft)
                        .focused($isComposerFocused)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("agent-composer")
                        .disabled(!model.isComposerAvailable)
                        .accessibilityHidden(
                            selectedActivity != .conversation || isPortraitNavigationPresented
                        )
                }
                .frame(minHeight: 70, maxHeight: 130)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                Button {
                    model.sendS1PreviewMessage()
                    isComposerFocused = false
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }
                .disabled(
                    model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !model.isComposerAvailable
                )
                .accessibilityIdentifier("agent-send-button")
            }
            .padding()
        }
    }

    private var shouldShowWelcomePage: Bool {
        model.conversationMessages.isEmpty
            && !model.hasEarlierConversationMessages
            && model.projects.isEmpty
            && model.openingPlanApproval == nil
            && model.lastToolReceipt == nil
            && model.latestAgentRun == nil
            && model.chapter == nil
    }

    private var welcomePage: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.tint)

            Text("仓颉")
                .font(.title.bold())
                .accessibilityIdentifier("welcome-brand")

            Text("有什么想写成小说的念头吗？")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("welcome-question")

            Text(
                "你不用会写，也不用先想好主线、人物和世界。\n"
                    + "可以告诉我一句话、一幅画面、一种感觉，\n"
                    + "甚至只说你最近喜欢看什么。"
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("welcome-guidance")

            Text("剩下的，我来陪你想清楚。")
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("welcome-promise")

            HStack(spacing: 12) {
                Button("我有一个念头") {
                    focusComposer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.isComposerAvailable)
                .accessibilityIdentifier("welcome-idea-button")

                Button("我还没想法") {
                    focusComposer(prefill: "我还没想法")
                }
                .buttonStyle(.bordered)
                .disabled(!model.isComposerAvailable)
                .accessibilityIdentifier("welcome-no-idea-button")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome-page")
    }

    private func focusComposer(prefill: String? = nil) {
        if let prefill, model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.draft = prefill
        }
        isComposerFocused = true
    }

    private var pendingOpeningPlanApproval: ApprovalRequest? {
        guard let approval = model.openingPlanApproval, approval.status == .pending else {
            return nil
        }
        return approval
    }

    private func pendingApprovalCard(_ approval: ApprovalRequest) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                pendingApprovalSummary(approval)
                Spacer(minLength: 8)
                openingPlanReviewButton(approval)
            }

            VStack(alignment: .leading, spacing: 8) {
                pendingApprovalSummary(approval)
                openingPlanReviewButton(approval)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func pendingApprovalSummary(_ approval: ApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(S1OrdinarySurfaceContract.openingPlanHeading)
                .font(.headline)
                .accessibilityIdentifier("opening-plan-approval-card")
            Text(S1OrdinarySurfaceContract.openingPlanExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .accessibilityIdentifier("opening-plan-approval-card-status")
        }
    }

    private func openingPlanReviewButton(_ approval: ApprovalRequest) -> some View {
        Button("打开看看") {
            reviewedOpeningPlan = OpeningPlanApprovalReview(
                approval: approval,
                planBody: model.planBody
            )
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.isAgentWorking || !model.isAgentExecutionAllowed)
        .accessibilityIdentifier("opening-plan-review-button")
    }

    private var pendingChapterReview: ChapterRuntimeSnapshot? {
        guard let chapter = model.chapter,
              chapter.stage == .reviewingV1 || chapter.stage == .reviewingV2 else { return nil }
        return chapter
    }

    private var pendingRewriteScopeApproval: ChapterRuntimeSnapshot? {
        guard let chapter = model.chapter,
              chapter.stage == .awaitingRewriteConfirmation else { return nil }
        return chapter
    }

    private func openChapterReview(_ chapter: ChapterRuntimeSnapshot) {
        reviewedChapter = ChapterReviewReference(
            versionID: chapter.activeVersion.id,
            contentHash: chapter.activeVersion.contentHash
        )
    }

    private func pendingChapterReviewCard(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(S1OrdinarySurfaceContract.chapterHeading)
                        .font(.headline)
                        .accessibilityIdentifier("chapter-review-card")
                    Text(S1OrdinarySurfaceContract.chapterStageDescription(chapter.stage))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("chapter-review-card-status")
                    Text(
                        S1OrdinarySurfaceContract.protectedParagraphsDescription(
                            chapter.calibration.lockedParagraphIndexes
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("打开看看") { openChapterReview(chapter) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isAgentWorking)
                    .accessibilityIdentifier("chapter-review-button")
            }
            Text(chapter.activeVersion.body)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Button(S1OrdinarySurfaceContract.chapterApproveButton) {
                    model.acceptChapter(
                        versionID: chapter.activeVersion.id,
                        displayedContentHash: chapter.activeVersion.contentHash
                    )
                }
                .buttonStyle(.bordered)
                .disabled(model.isAgentWorking)
                .accessibilityIdentifier("chapter-card-accept-button")
                Button(S1OrdinarySurfaceContract.chapterRejectButton) { openChapterReview(chapter) }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(model.isAgentWorking)
                    .accessibilityIdentifier("chapter-card-reject-button")
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func pendingRewriteScopeCard(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(S1OrdinarySurfaceContract.rewriteHeading)
                .font(.headline)
                .accessibilityIdentifier("chapter-rewrite-scope-card")
            Text(S1OrdinarySurfaceContract.rewriteExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(chapter.calibration.rewriteScope ?? "还没有可确认的修改范围")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack {
                Button("打开看看") { openChapterReview(chapter) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("chapter-rewrite-review-button")
                if let scopeHash = chapter.calibration.rewriteScopeHash {
                    Button(S1OrdinarySurfaceContract.rewriteApproveButton) {
                        model.confirmChapterRewrite(
                            sourceVersionID: chapter.activeVersion.id,
                            displayedSourceHash: chapter.activeVersion.contentHash,
                            rewriteScopeHash: scopeHash
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isAgentWorking)
                    .accessibilityIdentifier("chapter-card-rewrite-confirm-button")
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var artifacts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("这次结果")
                    .font(.headline)
                    .accessibilityIdentifier("results-heading")
                Text("这里会放仓颉本次工作的可查看结果。当前还没有真正的模型结果；这个版本只验证界面、导航和本地保存。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("results-empty-state")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

}
