//
//  KnowledgePanelView.swift
//  Cangjie
//
//  工作台右栏知识库 Tab，显示三元组列表 + 搜索 + 编辑入口 + 实体状态查询。
//  对齐原版工作台右栏知识库面板（KnowledgePanel.vue）。
//
//  E-5-3：补充接入 APIEndpoint.Tools.getEntityState（对齐原版 narrativeStateApi.getState），
//  按实体 ID + 章节号查询叙事状态快照，与三元组是不同功能，互不替换。
//

import SwiftUI

/// 工作台知识库面板视图
struct KnowledgePanelView: View {
    let novelId: String

    /// 面板模式：三元组 / 实体状态
    enum PanelMode: String, CaseIterable {
        case triples = "三元组"
        case entityState = "实体状态"
    }

    // MARK: - 三元组状态

    @State private var triples: [KnowledgeTriple] = []
    @State private var searchText: String = ""
    @State private var loading: Bool = false
    @State private var showTriplesDrawer: Bool = false
    @State private var selectedEntityType: String? = nil

    // MARK: - 实体状态查询状态（E-5-3，对齐 KnowledgePanel.vue L572-603）

    @State private var entityStateId: String = ""
    @State private var entityStateChapter: Int = 1
    @State private var entityStateLoading: Bool = false
    /// EntityState 返回结构为 { entity_id: string, [key: string]: unknown }，
    /// 用 [String: AnyCodable] 解码动态字段。
    @State private var entityStateResult: [String: AnyCodable]? = nil
    @State private var entityStateError: String = ""

    // MARK: - 通用

    @State private var mode: PanelMode = .triples
    private let apiClient = APIClient.shared

    /// 筛选后的三元组
    private var filteredTriples: [KnowledgeTriple] {
        var result = triples
        if let type = selectedEntityType {
            result = result.filter { $0.entityType == type }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.subject.lowercased().contains(query) ||
                $0.object.lowercased().contains(query) ||
                $0.predicate.lowercased().contains(query)
            }
        }
        return result
    }

    /// 实体状态展示字段（排除 entity_id，其余按 key 排序）
    /// 对齐原版 entityStateDisplay computed（解构 entity_id 后展示 rest）。
    private var entityStateDisplayFields: [(key: String, value: String)] {
        guard let result = entityStateResult else { return [] }
        return result
            .filter { $0.key != "entity_id" }
            .sorted { $0.key < $1.key }
            .map { (key: $0.key, value: $0.value.stringValue) }
    }

    /// 实体 ID（从返回结果中提取）
    private var entityStateEntityId: String {
        entityStateResult?["entity_id"]?.stringValue ?? entityStateId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 模式切换
            Picker("", selection: $mode) {
                ForEach(PanelMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Divider()

            if mode == .triples {
                triplesContent
            } else {
                entityStateContent
            }
        }
        .background(Theme.background)
        .task {
            await loadTriples()
        }
        .sheet(isPresented: $showTriplesDrawer) {
            KnowledgeTriplesDrawer(
                novelId: novelId,
                triples: triples,
                focusEntityName: nil,
                defaultEntityType: nil
            )
        }
    }

    // MARK: - 三元组内容

    private var triplesContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Label("知识三元组", systemImage: "network")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.primary)
                Spacer()
                Button {
                    showTriplesDrawer = true
                } label: {
                    Label("编辑", systemImage: "square.and.pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // 搜索框
            HStack {
                TextField("搜索三元组…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                // 实体类型筛选
                Picker("", selection: $selectedEntityType) {
                    Text("全部").tag(String?.none)
                    Text("角色").tag(String?.some("character"))
                    Text("地点").tag(String?.some("location"))
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 80)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // 三元组列表
            if loading {
                ProgressView("加载中…")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if filteredTriples.isEmpty {
                Text("暂无三元组数据")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredTriples) { triple in
                            tripleRow(triple)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    // MARK: - 实体状态内容（E-5-3，对齐 KnowledgePanel.vue L327-377）

    private var entityStateContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack {
                Label("实体状态快照", systemImage: "eye")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // 说明
            Text("输入实体 ID 和章节号，查询该实体在指定章节时的叙事状态（通过回放该章之前所有事件计算得出）。")
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            // 查询表单
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("实体 ID")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                        TextField("如：char-001 或角色名", text: $entityStateId)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("章节")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                        Stepper(value: $entityStateChapter, in: 1...9999) {
                            Text("第 \(entityStateChapter) 章")
                                .font(.system(size: 12))
                        }
                    }
                }

                Button {
                    Task { await fetchEntityState() }
                } label: {
                    HStack {
                        if entityStateLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("查询")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(entityStateLoading || entityStateId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // 结果区域
            if entityStateLoading {
                ProgressView("查询中…")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let _ = entityStateResult {
                entityStateResultView
            } else if !entityStateError.isEmpty {
                Text(entityStateError)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                Text("输入实体 ID 后点击查询")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }

    /// 实体状态结果展示（对齐原版 entity_id tag + key-value grid）
    @ViewBuilder
    private var entityStateResultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // entity_id 标签 + 章节标注
                HStack(spacing: 6) {
                    Text(entityStateEntityId)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.info)
                        .cornerRadius(10)
                    Text("第 \(entityStateChapter) 章时的状态")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.bottom, 4)

                // key-value 网格（对齐原版 entity-state-grid）
                if entityStateDisplayFields.isEmpty {
                    Text("无额外状态字段")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entityStateDisplayFields.enumerated()), id: \.offset) { _, field in
                            HStack(alignment: .top, spacing: 8) {
                                Text(field.key)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Theme.textTertiary)
                                    .frame(width: 90, alignment: .leading)
                                Text(field.value)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 8)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(6)
                }
            }
            .padding(12)
        }
    }

    // MARK: - 三元组行

    @ViewBuilder
    private func tripleRow(_ triple: KnowledgeTriple) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(triple.subject)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text(triple.predicate)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(3)
                Text(triple.object)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                if let type = triple.entityType {
                    Text(type == "character" ? "角色" : "地点")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            if let note = triple.note, !note.isEmpty, note != "null" {
                Text(note)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(Theme.secondaryBackground)
        .cornerRadius(6)
    }

    // MARK: - 数据加载

    /// 加载三元组（Knowledge.get）
    private func loadTriples() async {
        loading = true
        do {
            let response: StoryKnowledge = try await apiClient.request(
                APIEndpoint.Knowledge.get(novelId: novelId)
            )
            triples = response.facts
        } catch {
            triples = []
        }
        loading = false
    }

    /// 查询实体状态（Tools.getEntityState，对齐 narrativeStateApi.getState）
    /// 对齐 KnowledgePanel.vue L585-603。
    private func fetchEntityState() async {
        let trimmedId = entityStateId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            entityStateError = "请输入实体 ID"
            return
        }
        entityStateLoading = true
        entityStateResult = nil
        entityStateError = ""
        do {
            let result: [String: AnyCodable] = try await apiClient.request(
                APIEndpoint.Tools.getEntityState(
                    novelId: novelId,
                    entityId: trimmedId,
                    chapter: entityStateChapter
                )
            )
            entityStateResult = result
        } catch let error as APIError {
            // 对齐原版：404 → 未找到实体，其他 → 查询失败
            switch error {
            case .notFound:
                entityStateError = "未找到实体「\(trimmedId)」"
            default:
                entityStateError = "查询失败，请确认实体 ID 是否正确"
            }
        } catch {
            entityStateError = "查询失败，请确认实体 ID 是否正确"
        }
        entityStateLoading = false
    }
}
