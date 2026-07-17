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

struct ContentView: View {
    @ObservedObject var model: AppViewModel
    @State private var reviewedOpeningPlan: OpeningPlanApprovalReview?
    @State private var reviewedChapter: ChapterReviewReference?
    @FocusState private var isComposerFocused: Bool

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

    private var leftRail: some View {
        NavigationStack {
            List {
                Section("Navigate") {
                    NavigationLink("Conversations", destination: Text("Conversation history"))
                    NavigationLink("Novel Projects", destination: projectPage)
                        .accessibilityIdentifier("novel-projects-link")
                    NavigationLink("Workbenches", destination: Text("Novel workbenches"))
                    NavigationLink("Research", destination: Text("Research center"))
                    NavigationLink {
                        DeviceDiagnosticsView(model: model)
                    } label: {
                        Text("Device Diagnostics")
                    }
                    .accessibilityIdentifier("device-diagnostics-link")
                }
                Section {
                    Button { model.isArtifactDrawerPresented.toggle() } label: {
                        Label(
                            model.isArtifactDrawerPresented ? "Hide artifacts" : "Show artifacts",
                            systemImage: "square.stack.3d.up"
                        )
                    }
                    .accessibilityIdentifier("artifact-drawer-list-toggle")
                }
                Section("Build") {
                    Text(model.buildIdentity.displayText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("build-identity")
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
                    Text(project.premise)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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
                    Text("Agent Control Plane")
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
                Button { model.isArtifactDrawerPresented.toggle() } label: {
                    Image(systemName: "sidebar.right")
                }
                .accessibilityLabel(
                    model.isArtifactDrawerPresented ? "Hide artifacts" : "Show artifacts"
                )
                .accessibilityIdentifier("artifact-drawer-toggle")
            }
            .padding()
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if model.conversationMessages.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "sparkles").font(.largeTitle)
                            Text("Start with an idea").font(.headline)
                            Text(
                                "Ask CangJie to create or develop a novel. "
                                    + "The Agent will operate the project tools for you."
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                    }
                    ForEach(Array(model.conversationMessages.enumerated()), id: \.offset) { _, message in
                        Text(message)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.background, in: RoundedRectangle(cornerRadius: 12))
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
                TextEditor(text: $model.draft)
                    .focused($isComposerFocused)
                    .accessibilityIdentifier("agent-composer")
                    .frame(minHeight: 70, maxHeight: 130)
                    .padding(6)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                Button {
                    model.sendAgentMessage()
                    isComposerFocused = false
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }
                .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("agent-send-button")
            }
            .padding()
        }
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
            Text("Opening plan approval")
                .font(.headline)
                .accessibilityIdentifier("opening-plan-approval-card")
            Text("Status: pending")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("opening-plan-approval-card-status")
            Text(
                "Revision \(approval.artifactRevision) | Cost "
                    + "\(approval.estimatedCostMinorUnits)/\(approval.budgetCeilingMinorUnits) | "
                    + "Hash \(approval.artifactHash.prefix(12))..."
            )
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .accessibilityIdentifier("opening-plan-approval-card-summary")
        }
    }

    private func openingPlanReviewButton(_ approval: ApprovalRequest) -> some View {
        Button("Review exact revision") {
            reviewedOpeningPlan = OpeningPlanApprovalReview(
                approval: approval,
                planBody: model.planBody
            )
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.isAgentWorking)
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
                    Text("Chapter 1 review")
                        .font(.headline)
                        .accessibilityIdentifier("chapter-review-card")
                    Text("Revision \(chapter.activeVersion.revision) | \(chapter.stage.rawValue)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("chapter-review-card-status")
                    Text("Hash \(chapter.activeVersion.contentHash.prefix(12))...")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("Locked paragraphs: \(chapter.calibration.lockedParagraphIndexes.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Review chapter") { openChapterReview(chapter) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isAgentWorking)
                    .accessibilityIdentifier("chapter-review-button")
            }
            Text(chapter.activeVersion.body)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Button("Accept and freeze") {
                    model.acceptChapter(
                        versionID: chapter.activeVersion.id,
                        displayedContentHash: chapter.activeVersion.contentHash
                    )
                }
                .buttonStyle(.bordered)
                .disabled(model.isAgentWorking)
                .accessibilityIdentifier("chapter-card-accept-button")
                Button("Reject and diagnose") { openChapterReview(chapter) }
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
            Text("Rewrite scope approval")
                .font(.headline)
                .accessibilityIdentifier("chapter-rewrite-scope-card")
            Text("Diagnosis complete. No rewrite runs until this exact scope is confirmed.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(chapter.calibration.rewriteScope ?? "Missing rewrite scope")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack {
                Button("Review exact scope") { openChapterReview(chapter) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("chapter-rewrite-review-button")
                if let scopeHash = chapter.calibration.rewriteScopeHash {
                    Button("Confirm rewrite scope") {
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
                Text("Conversation artifacts").font(.headline)
                Text("Projects: \(model.projects.count)")
                if let receipt = model.lastToolReceipt {
                    Text("Last tool: \(receipt.toolID)")
                        .font(.footnote)
                        .accessibilityIdentifier("last-tool-receipt")
                    Text("Outcome: \(receipt.outcome)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let approval = model.openingPlanApproval {
                    Divider()
                    Text("Bound opening-plan approval").font(.subheadline.bold())
                    Text("Status: \(approval.status.rawValue)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("opening-plan-history-status")
                    approvalBindingSummary(
                        approval,
                        accessibilityPrefix: "opening-plan-history"
                    )
                }
                if let chapter = model.chapter {
                    Divider()
                    chapterArtifactHistory(chapter)
                }
                Divider()
                Text("Tool receipts, exact bindings, chapter versions, and diffs remain reviewable here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func chapterArtifactHistory(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Chapter 1 history").font(.subheadline.bold())
                Spacer()
                Button("Open") { openChapterReview(chapter) }
                    .font(.caption)
                    .accessibilityIdentifier("chapter-history-open-button")
            }
            Text("Status: \(chapter.stage.rawValue)")
                .font(.caption.monospaced())
                .accessibilityIdentifier("chapter-history-status")
            Text("Active revision: \(chapter.activeVersion.revision)")
                .font(.caption.monospaced())
            Text("Active hash: \(chapter.activeVersion.contentHash.prefix(12))...")
                .font(.caption.monospaced())
            Text("Locked: \(chapter.calibration.lockedParagraphIndexes.map { String($0 + 1) }.joined(separator: ", ").isEmpty ? "none" : chapter.calibration.lockedParagraphIndexes.map { String($0 + 1) }.joined(separator: ", "))")
                .font(.caption.monospaced())
                .accessibilityIdentifier("chapter-history-locked")
            if let scopeHash = chapter.calibration.rewriteScopeHash {
                Text("Rewrite scope: \(scopeHash.prefix(12))...")
                    .font(.caption.monospaced())
                    .accessibilityIdentifier("chapter-history-rewrite-scope")
            }
            if let accepted = chapter.calibration.acceptedVersionID {
                Text("Frozen version: \(accepted.uuidString.prefix(12))...")
                    .font(.caption.monospaced())
                    .accessibilityIdentifier("chapter-history-frozen-version")
            }
            ForEach(chapter.versions) { version in
                VStack(alignment: .leading, spacing: 2) {
                    Text("V\(version.revision) | \(version.contentHash.prefix(12))...")
                        .font(.caption.bold().monospaced())
                    Text(version.diffSummary ?? "Base revision")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("chapter-history-version-\(version.revision)")
                }
                .padding(.vertical, 3)
            }
        }
        .textSelection(.enabled)
    }

    private func approvalBindingSummary(
        _ approval: ApprovalRequest,
        accessibilityPrefix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Request: \(approval.id.uuidString.prefix(12))...")
                .accessibilityIdentifier("\(accessibilityPrefix)-request-id")
            Text("Artifact revision: \(approval.artifactRevision)")
                .accessibilityIdentifier("\(accessibilityPrefix)-revision")
            Text("Artifact hash: \(approval.artifactHash.prefix(12))...")
                .accessibilityIdentifier("\(accessibilityPrefix)-artifact-hash")
            Text("Tool: \(approval.toolID) v\(approval.toolVersion)")
                .accessibilityIdentifier("\(accessibilityPrefix)-tool")
            Text(
                "Estimated cost / ceiling: \(approval.estimatedCostMinorUnits) / "
                    + "\(approval.budgetCeilingMinorUnits) minor units"
            )
            .accessibilityIdentifier("\(accessibilityPrefix)-budget")
            Text("Expires: \(approval.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                .accessibilityIdentifier("\(accessibilityPrefix)-expiration")
            Text("Expected diff: \(approval.expectedDiffHash.prefix(12))...")
                .accessibilityIdentifier("\(accessibilityPrefix)-expected-diff")
            Text("Binding: \(approval.bindingHash.prefix(12))...")
                .accessibilityIdentifier("\(accessibilityPrefix)-binding-hash")
        }
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
}
