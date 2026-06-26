//
//  StorylinePanel.swift
//  Cangjie
//
//  故事线（主线/支线列表+进度+当前章节涉及的故事线），调 GovernanceStore。
//

import SwiftUI

struct StorylinePanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = GovernanceStore()

    // E-5：故事线 CRUD 状态
    @State private var showCreateSheet: Bool = false
    @State private var newStorylineName: String = ""
    @State private var newStorylineRole: String = "main"
    @State private var editingStorylineId: String?
    @State private var editingStorylineName: String = ""
    @State private var isProcessing: Bool = false

    private let apiClient = APIClient.shared

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                // E-5：添加故事线按钮
                HStack {
                    Text("故事线")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("添加", systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, Theme.Spacing.sm)

                if store.storylines.isEmpty {
                    Text("暂无故事线").font(Theme.captionFont()).foregroundColor(Theme.textTertiary).padding()
                } else {
                    ForEach(store.storylines) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Circle().fill(line.resolvedChapter != nil ? Theme.success : Theme.warning).frame(width: 6, height: 6)
                                Text(line.title).font(.system(size: 12, weight: .medium))
                                Spacer()
                                if let s = line.status { Text(s).font(.system(size: 9)).foregroundColor(Theme.textTertiary) }

                                // E-5：编辑按钮
                                Button {
                                    editingStorylineId = line.id
                                    editingStorylineName = line.title
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.info)
                                }
                                .buttonStyle(.plain)

                                // E-5：删除按钮
                                Button {
                                    Task { await deleteStoryline(id: line.id) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.error)
                                }
                                .buttonStyle(.plain)
                            }
                            HStack(spacing: 8) {
                                if let ch = line.introducedChapter { Text("第\(ch)章引入").font(.system(size: 9)).foregroundColor(Theme.textTertiary) }
                                if let rc = line.resolvedChapter { Text("→ 第\(rc)章闭合").font(.system(size: 9)).foregroundColor(Theme.success) }
                            }
                            if let tags = line.promiseTags, !tags.isEmpty {
                                Text(tags.map { "#\($0)" }.joined(separator: " ")).font(.system(size: 9)).foregroundColor(Theme.primary)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadState(novelId: novelId)
            }
        }
        // E-5：创建故事线弹窗
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                Form {
                    TextField("故事线名称", text: $newStorylineName)
                    Picker("类型", selection: $newStorylineRole) {
                        Text("主线").tag("main")
                        Text("支线").tag("sub")
                    }
                }
                .navigationTitle("新建故事线")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("创建") {
                            Task { await createStoryline() }
                        }
                        .disabled(newStorylineName.isEmpty || isProcessing)
                    }
                }
            }
        }
        // E-5：编辑故事线弹窗
        .sheet(isPresented: Binding(
            get: { editingStorylineId != nil },
            set: { if !$0 { editingStorylineId = nil } }
        )) {
            NavigationStack {
                Form {
                    TextField("故事线名称", text: $editingStorylineName)
                }
                .navigationTitle("编辑故事线")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { editingStorylineId = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            if let id = editingStorylineId {
                                Task { await updateStoryline(id: id) }
                            }
                        }
                        .disabled(editingStorylineName.isEmpty || isProcessing)
                    }
                }
            }
        }
    }

    // MARK: - E-5 故事线 CRUD

    /// 创建故事线 — workflow.ts createStoryline
    private func createStoryline() async {
        guard let novelId = appState.currentNovelId else { return }
        isProcessing = true
        do {
            let body = AnyCodable([
                "name": newStorylineName,
                "role": newStorylineRole
            ])
            let _: StorylineDTO = try await apiClient.request(
                APIEndpoint.Workflow.createStoryline(novelId: novelId),
                body: body
            )
            newStorylineName = ""
            showCreateSheet = false
            await store.loadState(novelId: novelId)
        } catch {
            Logger.data.error("创建故事线失败: \(error.localizedDescription)")
        }
        isProcessing = false
    }

    /// 更新故事线 — workflow.ts updateStoryline
    private func updateStoryline(id: String) async {
        guard let novelId = appState.currentNovelId else { return }
        isProcessing = true
        do {
            let body = AnyCodable([
                "name": editingStorylineName
            ])
            let _: StorylineDTO = try await apiClient.request(
                APIEndpoint.Workflow.updateStoryline(novelId: novelId, storylineId: id),
                body: body
            )
            editingStorylineId = nil
            await store.loadState(novelId: novelId)
        } catch {
            Logger.data.error("更新故事线失败: \(error.localizedDescription)")
        }
        isProcessing = false
    }

    /// 删除故事线 — workflow.ts deleteStoryline
    private func deleteStoryline(id: String) async {
        guard let novelId = appState.currentNovelId else { return }
        do {
            let _: AnyCodable = try await apiClient.request(
                APIEndpoint.Workflow.deleteStoryline(novelId: novelId, storylineId: id)
            )
            await store.loadState(novelId: novelId)
        } catch {
            Logger.data.error("删除故事线失败: \(error.localizedDescription)")
        }
    }
}
