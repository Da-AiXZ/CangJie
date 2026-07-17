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
                        Text("Exact approval binding")
                            .font(.title2.bold())
                            .accessibilityIdentifier("opening-plan-approval-detail-heading")
                        Text(
                            "Approval authorizes only this immutable revision, tool policy, "
                                + "target versions, budget, expiration, and expected diff."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    bindingSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Opening plan")
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

                    Button("Approve exact revision") {
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
                    .disabled(model.isAgentWorking || approval.status != .pending)
                    .accessibilityIdentifier("opening-plan-approve-button")
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle("Review opening plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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

    private var bindingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Binding details")
                .font(.headline)
            approvalField(
                label: "Status",
                value: approval.status.rawValue,
                identifier: "opening-plan-approval-status"
            )
            approvalField(
                label: "Request",
                value: approval.id.uuidString,
                identifier: "opening-plan-approval-request-id"
            )
            approvalField(
                label: "Conversation",
                value: approval.conversationID.uuidString,
                identifier: "opening-plan-approval-conversation-id"
            )
            approvalField(
                label: "Project",
                value: approval.projectID.uuidString,
                identifier: "opening-plan-approval-project-id"
            )
            approvalField(
                label: "Artifact logical ID",
                value: approval.artifactLogicalID.uuidString,
                identifier: "opening-plan-approval-artifact-logical-id"
            )
            approvalField(
                label: "Artifact ID",
                value: approval.artifactID.uuidString,
                identifier: "opening-plan-approval-artifact-id"
            )
            approvalField(
                label: "Revision",
                value: String(approval.artifactRevision),
                identifier: "opening-plan-approval-revision"
            )
            approvalField(
                label: "Artifact hash",
                value: approval.artifactHash,
                identifier: "opening-plan-approval-artifact-hash"
            )
            approvalField(
                label: "Tool / version",
                value: "\(approval.toolID) / \(approval.toolVersion)",
                identifier: "opening-plan-approval-tool"
            )
            approvalField(
                label: "Parameters hash",
                value: approval.parametersHash,
                identifier: "opening-plan-approval-parameters-hash"
            )
            approvalField(
                label: "Target versions hash",
                value: approval.targetVersionsHash,
                identifier: "opening-plan-approval-targets-hash"
            )
            ForEach(Array(approval.targetVersions.enumerated()), id: \.offset) { index, target in
                approvalField(
                    label: "Target \(index + 1)",
                    value: "\(target.type) | \(target.id.uuidString) | version \(target.version)",
                    identifier: "opening-plan-approval-target-\(index)"
                )
            }
            approvalField(
                label: "Budget",
                value: "\(approval.estimatedCostMinorUnits) / "
                    + "\(approval.budgetCeilingMinorUnits) minor units",
                identifier: "opening-plan-approval-budget"
            )
            approvalField(
                label: "Expiration",
                value: approval.expiresAt.formatted(date: .abbreviated, time: .standard),
                identifier: "opening-plan-approval-expiration"
            )
            approvalField(
                label: "Expected diff",
                value: approval.expectedDiffHash,
                identifier: "opening-plan-approval-expected-diff"
            )
            approvalField(
                label: "Binding",
                value: approval.bindingHash,
                identifier: "opening-plan-approval-binding-hash"
            )
        }
    }

    private func approvalField(label: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityIdentifier(identifier)
        }
    }
}
