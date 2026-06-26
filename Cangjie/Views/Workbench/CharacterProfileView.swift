//
//  CharacterProfileView.swift
//  Cangjie
//
//  角色档案视图，接入记忆系统投影端点。
//  对齐原版 components/workbench/CharacterProfile.vue。
//
//  E-5-4：接入 APIEndpoint.Memory.getCharacterProjection + confirmAtom + rejectAtom。
//  展示 CharacterProjection 的 constitution/currentState、候选记忆（含确认/拒绝）、最近证据。
//

import SwiftUI

/// 角色档案视图
///
/// 对齐原版 CharacterProfile.vue：
/// - L540 getCharacterProjection(slug, selectedCharacterId) 加载角色投影
/// - L484 candidateMemories 来自 projection.candidate_memories
/// - L551-562 confirmMemory → memoryApi.confirm → reload
/// - L564-575 rejectMemory → memoryApi.reject → reload
/// - L488-494 memoryAtomText 从 payload 提取展示文本
struct CharacterProfileView: View {

    /// 小说 ID
    let novelId: String

    /// 选中的角色 ID（nil 表示未选中，显示空状态）
    let characterId: String?

    // MARK: - 状态

    @State private var projection: CharacterProjection? = nil
    @State private var loading: Bool = false
    @State private var calibratingId: String? = nil
    @State private var errorMessage: String = ""

    /// 子视图模式
    enum ProfileTab: String, CaseIterable {
        case overview = "投影概览"
        case candidates = "候选记忆"
        case evidence = "最近证据"
    }

    @State private var activeTab: ProfileTab = .overview

    private let apiClient = APIClient.shared

    // MARK: - 计算属性

    /// 候选记忆列表（对齐 L484）
    private var candidateMemories: [MemoryAtom] {
        projection?.candidateMemories ?? []
    }

    /// 最近证据列表
    private var recentEvidence: [MemoryAtom] {
        projection?.recentEvidence ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            if let cid = characterId, !cid.isEmpty {
                // 顶栏：角色名 + 刷新
                topBar

                Divider()

                // 子标签
                Picker("", selection: $activeTab) {
                    ForEach(ProfileTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // 内容
                if loading {
                    ProgressView("加载中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.error)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else if let proj = projection {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            switch activeTab {
                            case .overview:
                                overviewSection(proj)
                            case .candidates:
                                candidatesSection
                            case .evidence:
                                evidenceSection
                            }
                        }
                        .padding(12)
                    }
                } else {
                    Text("暂无角色投影数据")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // 空状态（对齐原版 cp-empty）
                VStack(spacing: 10) {
                    Image(systemName: "theatermasks")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.textTertiary)
                    Text("从左侧点选角色\n查看档案")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .onChange(of: characterId) { _ in
            activeTab = .overview
            Task { await loadProjection() }
        }
        .task {
            await loadProjection()
        }
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(projection?.name ?? "角色档案")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if let proj = projection, !proj.characterId.isEmpty {
                    Text(proj.characterId)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            Spacer()
            Button {
                Task { await loadProjection() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(loading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 投影概览（constitution + currentState）

    @ViewBuilder
    private func overviewSection(_ proj: CharacterProjection) -> some View {
        // 角色宪法
        projectionCard(title: "角色宪法", icon: "shield.lefthalf.filled") {
            anyCodableDisplay(proj.constitution)
        }

        // 当前状态
        projectionCard(title: "当前状态", icon: "heart.text.square") {
            anyCodableDisplay(proj.currentState)
        }

        // 知识边界
        projectionCard(title: "知识边界", icon: "brain") {
            anyCodableDisplay(proj.knowledgeBoundary)
        }

        // 声纹指纹
        projectionCard(title: "声纹指纹", icon: "waveform") {
            anyCodableDisplay(proj.voiceFingerprint)
        }

        // 上下文锁
        if proj.contextLocks.t0 != nil || proj.contextLocks.t1 != nil || proj.contextLocks.t2 != nil {
            projectionCard(title: "上下文锁", icon: "lock") {
                VStack(alignment: .leading, spacing: 4) {
                    if let t0 = proj.contextLocks.t0 {
                        lockRow(label: "T0", value: t0)
                    }
                    if let t1 = proj.contextLocks.t1 {
                        lockRow(label: "T1", value: t1)
                    }
                    if let t2 = proj.contextLocks.t2 {
                        lockRow(label: "T2", value: t2)
                    }
                }
            }
        }
    }

    // MARK: - 候选记忆（含确认/拒绝，对齐 L188-212 + L551-575）

    @ViewBuilder
    private var candidatesSection: some View {
        if candidateMemories.isEmpty {
            Text("暂无待校准记忆 · 章后抽取会在这里积累候选项")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            // 计数标签
            HStack {
                Text("候选记忆")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Text("\(candidateMemories.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.statusBypassed)
                    .cornerRadius(8)
                Spacer()
            }

            ForEach(candidateMemories) { atom in
                candidateRow(atom)
            }
        }
    }

    @ViewBuilder
    private func candidateRow(_ atom: MemoryAtom) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 元信息行
            HStack(spacing: 6) {
                Text(memoryTypeLabel(atom.memoryType))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.tertiaryBackground)
                    .cornerRadius(4)
                if let ch = atom.chapterNumber {
                    Text("第\(ch)章")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.info)
                }
                Spacer()
                Text("\(Int(atom.confidence * 100))%")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)
            }

            // 记忆文本（对齐 memoryAtomText L488-494）
            Text(memoryAtomText(atom))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // 操作按钮（对齐 L203-206 confirm/reject）
            HStack(spacing: 12) {
                Spacer()
                Button {
                    Task { await confirmMemory(atomId: atom.id) }
                } label: {
                    if calibratingId == atom.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("确认")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(calibratingId != nil)

                Button {
                    Task { await rejectMemory(atomId: atom.id) }
                } label: {
                    if calibratingId == atom.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("拒绝")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(calibratingId != nil)
            }
        }
        .padding(10)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 最近证据

    @ViewBuilder
    private var evidenceSection: some View {
        if recentEvidence.isEmpty {
            Text("暂无最近证据")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            HStack {
                Text("最近证据")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Text("\(recentEvidence.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.info)
                    .cornerRadius(8)
                Spacer()
            }

            ForEach(recentEvidence) { atom in
                evidenceRow(atom)
            }
        }
    }

    @ViewBuilder
    private func evidenceRow(_ atom: MemoryAtom) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(memoryTypeLabel(atom.memoryType))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.tertiaryBackground)
                    .cornerRadius(4)
                if let ch = atom.chapterNumber {
                    Text("第\(ch)章")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.info)
                }
                Spacer()
                // 状态标签
                Text(atom.status)
                    .font(.system(size: 9))
                    .foregroundColor(statusColor(atom.status))
            }

            Text(memoryAtomText(atom))
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Theme.secondaryBackground)
        .cornerRadius(6)
    }

    // MARK: - 通用视图组件

    /// 投影卡片容器
    @ViewBuilder
    private func projectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.tertiaryBackground)

            content()
                .padding(10)
        }
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// AnyCodable 动态结构展示（格式化 JSON）
    @ViewBuilder
    private func anyCodableDisplay(_ codable: AnyCodable) -> some View {
        let text = prettyJSON(codable)
        if text.isEmpty || text == "null" {
            Text("暂无数据")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        } else {
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 上下文锁行
    private func lockRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 24, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - 辅助方法

    /// 记忆原子文本提取（对齐 CharacterProfile.vue L488-494 memoryAtomText）
    private func memoryAtomText(_ atom: MemoryAtom) -> String {
        guard let dict = atom.payload.dictionaryValue else {
            return atom.textSpan.isEmpty ? "（空候选）" : atom.textSpan
        }
        let keys = [
            "summary", "mental_state", "impact_or_description", "impact",
            "description", "content", "source_event",
        ]
        for key in keys {
            guard let val = dict[key], !(val is NSNull) else { continue }
            if let str = val as? String, !str.isEmpty {
                return str
            }
            let str = AnyCodable(val).stringValue
            if !str.isEmpty && str != "null" {
                return str
            }
        }
        if !atom.textSpan.isEmpty {
            return atom.textSpan
        }
        return "（空候选）"
    }

    /// 记忆类型标签（简化映射）
    private func memoryTypeLabel(_ type: String) -> String {
        switch type.lowercased() {
        case "event": return "事件"
        case "emotion": return "情绪"
        case "relationship": return "关系"
        case "state": return "状态"
        case "wound": return "创伤"
        case "belief": return "信念"
        case "voice": return "声线"
        case "arc": return "弧线"
        default: return type
        }
    }

    /// 状态颜色
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "confirmed", "promoted": return Theme.success
        case "rejected": return Theme.error
        case "pending": return Theme.warning
        default: return Theme.textTertiary
        }
    }

    /// AnyCodable 格式化为可读 JSON
    private func prettyJSON(_ codable: AnyCodable) -> String {
        if let data = try? JSONSerialization.data(
            withJSONObject: codable.value,
            options: [.prettyPrinted, .fragmentsAllowed]
        ),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return codable.stringValue
    }

    // MARK: - 数据加载

    /// 加载角色投影（对齐 CharacterProfile.vue L525-549 loadCharacterData）
    private func loadProjection() async {
        guard let cid = characterId, !cid.isEmpty else {
            projection = nil
            errorMessage = ""
            return
        }
        loading = true
        errorMessage = ""
        do {
            projection = try await apiClient.request(
                APIEndpoint.Memory.getCharacterProjection(
                    novelId: novelId,
                    characterId: cid
                )
            )
        } catch {
            projection = nil
            if let apiError = error as? APIError {
                errorMessage = apiError.errorDescription ?? "加载角色投影失败"
            } else {
                errorMessage = "加载角色投影失败"
            }
        }
        loading = false
    }

    /// 确认候选记忆（对齐 CharacterProfile.vue L551-562 confirmMemory）
    private func confirmMemory(atomId: String) async {
        calibratingId = atomId
        do {
            try await apiClient.send(
                APIEndpoint.Memory.confirmAtom(novelId: novelId, atomId: atomId)
            )
            await loadProjection()
        } catch {
            errorMessage = "确认失败"
        }
        calibratingId = nil
    }

    /// 拒绝候选记忆（对齐 CharacterProfile.vue L564-575 rejectMemory）
    private func rejectMemory(atomId: String) async {
        calibratingId = atomId
        do {
            try await apiClient.send(
                APIEndpoint.Memory.rejectAtom(novelId: novelId, atomId: atomId)
            )
            await loadProjection()
        } catch {
            errorMessage = "拒绝失败"
        }
        calibratingId = nil
    }
}
