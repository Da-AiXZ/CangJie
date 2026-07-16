import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            leftRail
                .frame(width: 250)
            Divider()
            conversation
                .frame(maxWidth: .infinity)
            if model.isArtifactDrawerPresented {
                Divider()
                artifacts
                    .frame(width: 320)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var leftRail: some View {
        NavigationStack {
            List {
                Section("Navigate") {
                    NavigationLink("Conversations", destination: Text("Conversation history"))
                    NavigationLink("Novel Projects", destination: projectPage)
                        .accessibilityIdentifier("novel-projects-link")
                    NavigationLink("Workbenches", destination: Text("Novel workbenches"))
                    NavigationLink("Research", destination: Text("Research center"))
                }
                Section {
                    Button { model.isArtifactDrawerPresented.toggle() } label: {
                        Label(model.isArtifactDrawerPresented ? "Hide artifacts" : "Show artifacts", systemImage: "square.stack.3d.up")
                    }
                }
            }
            .navigationTitle("CangJie")
        }
    }

    private var projectPage: some View {
        List {
            ForEach(model.projects) { project in
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title).font(.headline)
                    Text(project.premise).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                .padding(.vertical, 4)
            }
            Button { model.reloadProjects() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("projects-refresh-button")

            if let notice = model.transientNotice, notice.kind == .projectRefresh {
                Label(notice.message, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("project-refresh-feedback")
            }
        }
        .navigationTitle("Novel Projects")
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Agent Control Plane").font(.title2.bold())
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
                Button { model.isArtifactDrawerPresented.toggle() } label: { Image(systemName: "sidebar.right") }
            }
            .padding()
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if model.conversationMessages.isEmpty {
                        VStack(spacing: 10) { Image(systemName: "sparkles").font(.largeTitle); Text("Start with an idea").font(.headline); Text("Ask CangJie to create or develop a novel. The Agent will operate the project tools for you.").font(.footnote).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 80)
                    }
                    ForEach(Array(model.conversationMessages.enumerated()), id: \.offset) { _, message in
                        Text(message).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                }.padding()
            }
            if let approval = model.openingPlanApproval {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Opening plan approval").font(.headline)
                            Text("Status: \(approval.status.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("opening-plan-approval-status")
                        }
                        Spacer()
                        if approval.status == .pending {
                            Button("Approve exact revision") {
                                model.approveOpeningPlan(
                                    requestID: approval.id,
                                    displayedBindingHash: approval.bindingHash
                                )
                            }
                                .buttonStyle(.borderedProminent)
                                .disabled(model.isAgentWorking)
                                .accessibilityIdentifier("opening-plan-approve-button")
                        }
                    }
                    approvalBindingSummary(approval)
                    Text(model.planBody).font(.footnote).lineLimit(6)
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .accessibilityIdentifier("opening-plan-approval-card")
            }
            HStack(alignment: .bottom) {
                TextEditor(text: $model.draft)
                    .accessibilityIdentifier("agent-composer")
                    .frame(minHeight: 70, maxHeight: 130).padding(6).background(.background, in: RoundedRectangle(cornerRadius: 12))
                Button { model.sendAgentMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }
                .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("agent-send-button")
            }.padding()
        }
    }

    private var artifacts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation artifacts").font(.headline)
            Text("Projects: \(model.projects.count)")
            if let receipt = model.lastToolReceipt {
                Text("Last tool: \(receipt.toolID)").font(.footnote)
                Text("Outcome: \(receipt.outcome)").font(.footnote).foregroundStyle(.secondary)
            }
            if let approval = model.openingPlanApproval {
                Divider()
                Text("Bound opening-plan approval").font(.subheadline.bold())
                approvalBindingSummary(approval)
            }
            Divider()
            Text("Tool receipts, plans, diffs, approvals, and chapter versions will appear here.").font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }.padding()
    }
    private func approvalBindingSummary(_ approval: ApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Request: \(approval.id.uuidString.prefix(12))...")
                .accessibilityIdentifier("opening-plan-approval-request-id")
            Text("Artifact revision: \(approval.artifactRevision)")
                .accessibilityIdentifier("opening-plan-approval-revision")
            Text("Artifact hash: \(approval.artifactHash.prefix(12))...")
                .accessibilityIdentifier("opening-plan-approval-artifact-hash")
            Text("Tool: \(approval.toolID) v\(approval.toolVersion)")
                .accessibilityIdentifier("opening-plan-approval-tool")
            Text("Estimated cost / ceiling: \(approval.estimatedCostMinorUnits) / \(approval.budgetCeilingMinorUnits) minor units")
                .accessibilityIdentifier("opening-plan-approval-budget")
            Text("Expires: \(approval.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                .accessibilityIdentifier("opening-plan-approval-expiration")
            Text("Expected diff: \(approval.expectedDiffHash.prefix(12))...")
                .accessibilityIdentifier("opening-plan-approval-expected-diff")
            Text("Binding: \(approval.bindingHash.prefix(12))...")
                .accessibilityIdentifier("opening-plan-approval-binding-hash")
        }
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }

}
