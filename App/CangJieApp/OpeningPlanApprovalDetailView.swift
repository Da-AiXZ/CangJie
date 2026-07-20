import CangJieCore
import SwiftUI

struct OpeningPlanApprovalDetailView: View {
    @ObservedObject var model: AppViewModel
    let approval: ApprovalRequest
    let planBody: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(S1OrdinarySurfaceContract.openingPlanHeading)
                            .font(.title2.bold())
                            .accessibilityIdentifier("opening-plan-approval-detail-heading")
                        Text(S1OrdinarySurfaceContract.openingPlanExplanation)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("开篇方案")
                            .font(.headline)
                        Text(planBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("opening-plan-approval-plan-body")
                    }

                    if let errorMessage = model.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("opening-plan-approval-error")
                    }

                    Button(S1OrdinarySurfaceContract.openingPlanApproveButton) {
                        let approved = model.approveOpeningPlan(
                            requestID: approval.id,
                            displayedBindingHash: approval.bindingHash
                        )
                        if Self.shouldDismiss(
                            approvalSucceeded: approved,
                            projectedApproval: model.openingPlanApproval,
                            reviewedApproval: approval
                        ) {
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isAgentWorking || !model.isAgentExecutionAllowed || approval.status != .pending)
                    .accessibilityIdentifier("opening-plan-approve-button")
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle(S1OrdinarySurfaceContract.openingPlanHeading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(S1OrdinarySurfaceContract.reviewLaterButton) { dismiss() }
                        .accessibilityIdentifier("opening-plan-review-close-button")
                }
            }
        }
    }

    static func shouldDismiss(
        approvalSucceeded: Bool,
        projectedApproval: ApprovalRequest?,
        reviewedApproval: ApprovalRequest
    ) -> Bool {
        approvalSucceeded
            && projectedApproval?.id == reviewedApproval.id
            && projectedApproval?.bindingHash == reviewedApproval.bindingHash
            && projectedApproval?.status == .approved
    }
}
