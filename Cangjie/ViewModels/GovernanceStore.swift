//
//  GovernanceStore.swift
//  Cangjie
//
//  叙事治理：契约/故事线/债务/报告/预算。
//

import SwiftUI
import Foundation

/// 叙事治理 Store
@MainActor
final class GovernanceStore: ObservableObject {

    @Published var state: GovernanceState?
    @Published var budgetPreview: GovernanceBudgetPreview?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载治理状态
    /// - Parameter novelId: 小说 ID
    func loadState(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.Governance.state(novelId: novelId)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                state = try? CangjieDecoder.shared.decode(GovernanceState.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 更新治理契约
    func updateContract(novelId: String, payload: GovernanceContractPayload) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.Governance.contract(novelId: novelId),
                body: payload
            )
            // 重新加载状态
            await loadState(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 合并故事线
    func mergeStorylines(novelId: String, payload: MergeStorylinesPayload) async {
        do {
            let _: AnyCodable = try await apiClient.request(
                APIEndpoint.Governance.mergeStorylines(novelId: novelId),
                body: payload
            )
            await loadState(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 预算预览
    func previewBudget(novelId: String, chapterNumber: Int?) async {
        let payload = BudgetPreviewPayload(chapterNumber: chapterNumber)

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.Governance.chapterBudgetPreview(novelId: novelId),
                body: payload
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                budgetPreview = try? CangjieDecoder.shared.decode(GovernanceBudgetPreview.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 审阅动作
    func reviewAction(novelId: String, reportId: String, action: String, patch: [String: AnyCodable]? = nil) async {
        let payload = ReviewActionPayload(reportId: reportId, action: action, patch: patch)

        do {
            let _: AnyCodable = try await apiClient.request(
                APIEndpoint.Governance.reviewAction(novelId: novelId),
                body: payload
            )
            await loadState(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 便捷属性

    var contract: GovernanceContract? { state?.contract }
    var storylines: [Storyline] { state?.storylines ?? [] }
    var debts: [DebtRecord] { state?.debts ?? [] }
    var reports: [GovernanceReport] { state?.reports ?? [] }
}
