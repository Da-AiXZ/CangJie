//
//  MonitorStore.swift
//  Cangjie
//
//  监控 Store：张力曲线/文风漂移/伏笔统计 + 质量护栏检查/快照。
//  对齐原版 engineCore.ts:133-147（guardrailApi）+ chapter.ts:159-167（getGuardrailSnapshot）。
//  机制4：每个方法标注原版文件+行号。
//

import SwiftUI
import Foundation

/// 监控 Store — 张力曲线/文风漂移/伏笔统计 + 质量护栏
@MainActor
final class MonitorStore: ObservableObject {

    // MARK: - 监控数据状态

    @Published var tensionCurve: TensionCurveResponse?
    @Published var voiceDrifts: [VoiceDrift] = []
    @Published var foreshadowStats: ForeshadowStats?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - 质量护栏状态（engineCore.ts:133-147）

    /// 最近一次护栏检查结果 — QualityGuardrailPanel.vue:180
    @Published var guardrailReport: GuardrailCheckResponse?

    /// 是否正在执行护栏检查 — QualityGuardrailPanel.vue:178
    @Published var isCheckingGuardrail: Bool = false

    /// 检查模式（advise/enforce） — QualityGuardrailPanel.vue:179
    @Published var guardrailMode: String = "advise"

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 监控数据加载

    /// 加载全部监控数据
    /// - Parameter novelId: 小说 ID
    func loadAll(novelId: String) async {
        isLoading = true
        self.errorMessage = nil

        async let tension: TensionCurveResponse? = try? apiClient.request(
            APIEndpoint.Monitor.tensionCurve(novelId: novelId)
        )
        async let drifts: [VoiceDrift]? = try? apiClient.request(
            APIEndpoint.Monitor.voiceDrift(novelId: novelId)
        )
        async let foreshadow: ForeshadowStats? = try? apiClient.request(
            APIEndpoint.Monitor.foreshadowStats(novelId: novelId)
        )

        self.tensionCurve = await tension
        self.voiceDrifts = await drifts ?? []
        self.foreshadowStats = await foreshadow

        isLoading = false
    }

    /// 仅加载张力曲线
    func loadTensionCurve(novelId: String) async {
        do {
            tensionCurve = try await apiClient.request(
                APIEndpoint.Monitor.tensionCurve(novelId: novelId)
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// 仅加载文风漂移
    func loadVoiceDrift(novelId: String) async {
        do {
            voiceDrifts = try await apiClient.request(
                APIEndpoint.Monitor.voiceDrift(novelId: novelId)
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// 仅加载伏笔统计
    func loadForeshadowStats(novelId: String) async {
        do {
            foreshadowStats = try await apiClient.request(
                APIEndpoint.Monitor.foreshadowStats(novelId: novelId)
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - 质量护栏（engineCore.ts:133-147）

    /// 执行质量护栏检查 — engineCore.ts:133-139 guardrailApi.check()
    /// POST /novels/{novelId}/guardrail/check
    ///
    /// 对齐原版 QualityGuardrailPanel.vue:200-225 runCheck()
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - text: 章节正文文本
    ///   - chapterNumber: 章节编号（用于 chapter_goal）
    ///   - chapterTitle: 章节标题（用于 chapter_goal）
    ///   - characterNames: 角色名称列表（可选）
    func loadGuardrailCheck(
        novelId: String,
        text: String,
        chapterNumber: Int,
        chapterTitle: String,
        characterNames: [String] = []
    ) async {
        // 原版 QualityGuardrailPanel.vue:207-208：空文本不检查
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.errorMessage = "该章节暂无正文内容"
            return
        }

        isCheckingGuardrail = true
        self.errorMessage = nil

        // 构造请求体 — engineCore.ts:100-107 GuardrailCheckRequest
        // 对齐 QualityGuardrailPanel.vue:212-219
        let request = GuardrailCheckRequest(
            text: text,
            characterNames: characterNames,
            chapterGoal: "第\(chapterNumber)章: \(chapterTitle)",
            era: "ancient",              // 疑问1决策：硬编码 'ancient'
            sceneType: "auto",           // 疑问2决策：硬编码 'auto'
            mode: guardrailMode           // advise 或 enforce
        )

        do {
            let response: GuardrailCheckResponse = try await apiClient.request(
                APIEndpoint.Checkpoints.guardrailCheck(novelId: novelId),
                body: request
            )
            self.guardrailReport = response
        } catch {
            self.errorMessage = "质量检查失败: \(error.localizedDescription)"
        }

        isCheckingGuardrail = false
    }

    /// 加载护栏自动快照 — chapter.ts:159-167 getGuardrailSnapshot()
    /// GET /novels/{novelId}/chapters/{chapterNumber}/guardrail-snapshot
    ///
    /// 对齐原版 QualityGuardrailPanel.vue:227-238 hydrateFromSnapshot()
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节编号
    func loadGuardrailSnapshot(novelId: String, chapterNumber: Int) async {
        // 原版：尚无快照时服务端返回 JSON null（HTTP 200），lastReport 置 null
        do {
            let response: GuardrailCheckResponse? = try await apiClient.request(
                APIEndpoint.Chapters.guardrailSnapshot(novelId: novelId, chapterNumber: chapterNumber)
            )
            self.guardrailReport = response
        } catch {
            // 原版 catch 中 lastReport = null
            self.guardrailReport = nil
        }
    }

    // MARK: - 便捷属性

    /// 张力点列表
    var tensionPoints: [TensionPoint] {
        return tensionCurve?.points ?? []
    }

    /// 张力统计
    var tensionStats: TensionCurveStats? {
        return tensionCurve?.stats
    }

    /// 护栏总分百分比（0-100） — QualityGuardrailPanel.vue:54,58
    var guardrailOverallScorePercent: Int {
        return Int((guardrailReport?.overallScore ?? 0) * 100)
    }

    /// 护栏是否通过 — QualityGuardrailPanel.vue:10
    var guardrailPassed: Bool {
        return guardrailReport?.passed ?? false
    }

    /// 护栏维度列表 — QualityGuardrailPanel.vue:69
    var guardrailDimensions: [GuardrailDimensionScore] {
        return guardrailReport?.dimensions ?? []
    }

    /// 护栏违规列表 — QualityGuardrailPanel.vue:90,96
    var guardrailViolations: [GuardrailViolationDTO] {
        return guardrailReport?.violations ?? []
    }
}

// MARK: - 护栏辅助函数（chapterWriting.ts:71-157）

/// 护栏维度中文标签 — chapterWriting.ts:80-87 GUARDRAIL_DIMENSION_LABELS
func guardrailDimensionLabel(_ key: String) -> String {
    let labels: [String: String] = [
        "language_style": "语言风格",
        "character_consistency": "角色一致性",
        "plot_density": "情节密度",
        "naming": "命名",
        "viewpoint": "视角",
        "rhythm": "节奏",
    ]
    return labels[key] ?? key
}

/// 护栏分数着色 — chapterWriting.ts:139-143 getGuardrailScoreColor
func guardrailScoreColor(_ score: Double) -> Color {
    if score >= 0.75 { return .green }
    if score >= 0.5 { return .orange }
    return .red
}

/// 护栏严重程度标签 — chapterWriting.ts:71-78,150-153 getGuardrailSeverityLabel
func guardrailSeverityLabel(_ severity: String) -> String {
    let key = severity.lowercased()
    switch key {
    case "critical", "error": return "严重"
    case "important", "warning": return "重要"
    case "minor", "info": return "轻微"
    default: return severity.isEmpty ? "—" : severity
    }
}

/// 护栏严重程度着色 — chapterWriting.ts:71-78,145-148 getGuardrailSeverityTagType
func guardrailSeverityColor(_ severity: String) -> Color {
    let key = severity.lowercased()
    switch key {
    case "critical", "error": return .red
    case "important", "warning": return .orange
    case "minor", "info": return .blue
    default: return .gray
    }
}
