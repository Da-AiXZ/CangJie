//
//  AntiAIStore.swift
//  Cangjie
//
//  Anti-AI 防御系统 Store，对齐原版 AntiAIDashboard.vue:389-552。
//  管理：扫描结果 + 系统统计 + 规则列表 + 白名单场景。
//

import SwiftUI
import Foundation

/// Anti-AI Store — AntiAIDashboard.vue:389-552
@MainActor
final class AntiAIStore: ObservableObject {

    // MARK: - 状态

    /// 扫描结果 — AntiAIDashboard.vue:410
    @Published var scanResult: AntiAIScanResult?
    @Published var isScanning: Bool = false

    /// 系统统计 — AntiAIDashboard.vue:411
    @Published var stats: AntiAIStats?

    /// 规则列表 — AntiAIDashboard.vue:415
    @Published var rules: [AntiAIRuleInfo] = []
    @Published var rulesLoading: Bool = false

    /// 白名单场景 — AntiAIDashboard.vue:419
    @Published var allowlistScenes: [AllowlistScene] = []
    @Published var allowlistLoading: Bool = false

    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 扫描 — AntiAIDashboard.vue:492-502 handleScan

    /// 扫描文本 AI 味 — POST /anti-ai/scan
    /// - Parameter content: 要扫描的文本
    /// - Parameter chapterId: 可选章节 ID
    func scan(content: String, chapterId: String? = nil) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isScanning = true
        errorMessage = nil
        let request = AntiAIScanRequest(content: content, chapterId: chapterId)
        do {
            scanResult = try await apiClient.request(APIEndpoint.AntiAI.scan, body: request)
        } catch {
            errorMessage = error.localizedDescription
        }
        isScanning = false
    }

    // MARK: - 系统统计 — AntiAIDashboard.vue:517-523 loadStats

    /// 加载系统统计 — GET /anti-ai/stats
    func loadStats() async {
        do {
            stats = try await apiClient.request(APIEndpoint.AntiAI.stats)
        } catch {
            // 静默失败
        }
    }

    // MARK: - 规则 — AntiAIDashboard.vue:525-534 loadRules

    /// 加载正向行为映射规则 — GET /anti-ai/rules
    func loadRules() async {
        rulesLoading = true
        do {
            rules = try await apiClient.request(APIEndpoint.AntiAI.rules)
        } catch {
            // 静默失败
        }
        rulesLoading = false
    }

    // MARK: - 白名单 — AntiAIDashboard.vue:536-545 loadAllowlist

    /// 加载白名单场景 — GET /anti-ai/allowlist/scenes
    func loadAllowlist() async {
        allowlistLoading = true
        do {
            allowlistScenes = try await apiClient.request(APIEndpoint.AntiAI.allowlistScenes)
        } catch {
            // 静默失败
        }
        allowlistLoading = false
    }

    // MARK: - 生命周期 — AntiAIDashboard.vue:547-551 onMounted

    /// 加载全部数据（3路并行）— AntiAIDashboard.vue:547-551
    func loadAll() async {
        async let s: Void = loadStats()
        async let r: Void = loadRules()
        async let a: Void = loadAllowlist()
        _ = await (s, r, a)
    }
}
