import CangJieCore
import SwiftUI

struct ChapterReviewDetailView: View {
    @ObservedObject var model: AppViewModel
    let displayedVersionID: UUID
    let displayedContentHash: String

    @Environment(\.dismiss) private var dismiss
    @State private var rejectionReason = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let chapter = displayedChapter {
                        exactBinding(chapter)
                        chapterBody(chapter)
                        evidence(chapter.activeVersion)
                        if chapter.stage == .awaitingRewriteConfirmation {
                            rewriteScope(chapter)
                        }
                        versionHistory(chapter)
                        if chapter.stage == .reviewingV1 || chapter.stage == .reviewingV2 {
                            reviewActions(chapter)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.largeTitle)
                            Text("Revision changed").font(.headline)
                            Text("Close this review and open the latest Chapter 1 revision.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .accessibilityIdentifier("chapter-review-stale")
                    }
                }
                .padding()
            }
            .navigationTitle("Chapter 1 review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("chapter-review-detail")
    }

    private var displayedChapter: ChapterRuntimeSnapshot? {
        guard let chapter = model.chapter,
              chapter.activeVersion.id == displayedVersionID,
              chapter.activeVersion.contentHash == displayedContentHash else { return nil }
        return chapter
    }

    private func exactBinding(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(chapter.activeVersion.title)
                .font(.title2.bold())
                .accessibilityIdentifier("chapter-review-title")
            Text("Status: \(chapter.stage.rawValue)")
                .accessibilityIdentifier("chapter-review-status")
            Text("Revision: \(chapter.activeVersion.revision)")
                .accessibilityIdentifier("chapter-review-revision")
            Text("Version: \(chapter.activeVersion.id.uuidString)")
                .accessibilityIdentifier("chapter-review-version-id")
            Text("Content hash: \(chapter.activeVersion.contentHash)")
                .accessibilityIdentifier("chapter-review-content-hash")
            Text("Locked paragraphs: \(lockedDescription(chapter))")
                .accessibilityIdentifier("chapter-review-locked-summary")
        }
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }

    private func chapterBody(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exact chapter text")
                .font(.headline)
            ForEach(Array(model.chapterParagraphs.enumerated()), id: \.offset) { index, paragraph in
                let isLocked = chapter.calibration.lockedParagraphIndexes.contains(index)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Paragraph \(index + 1)")
                            .font(.caption.bold())
                        Spacer()
                        if chapter.stage == .reviewingV1 || chapter.stage == .reviewingV2 {
                            Button(isLocked ? "Unlock" : "Lock") {
                                model.setChapterParagraphLocked(
                                    index,
                                    locked: !isLocked,
                                    versionID: displayedVersionID,
                                    displayedContentHash: displayedContentHash
                                )
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isAgentWorking || !model.isAgentExecutionAllowed)
                            .accessibilityIdentifier("chapter-paragraph-lock-\(index)")
                        } else if isLocked {
                            Label("Locked", systemImage: "lock.fill")
                                .font(.caption)
                        }
                    }
                    Text(paragraph)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("chapter-paragraph-\(index)")
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func evidence(_ version: ChapterVersion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evidence review").font(.headline)
            Text(version.evidenceReview)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .accessibilityIdentifier("chapter-evidence-review")
        }
    }

    private func rewriteScope(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exact rewrite scope").font(.headline)
            Text(chapter.calibration.rewriteScope ?? "Missing scope")
                .textSelection(.enabled)
                .accessibilityIdentifier("chapter-rewrite-scope-body")
            Text("Scope hash: \(chapter.calibration.rewriteScopeHash ?? "missing")")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .accessibilityIdentifier("chapter-rewrite-scope-hash")
            if let scopeHash = chapter.calibration.rewriteScopeHash {
                Button("Confirm exact rewrite scope") {
                    if model.confirmChapterRewrite(
                        sourceVersionID: displayedVersionID,
                        displayedSourceHash: displayedContentHash,
                        rewriteScopeHash: scopeHash
                    ) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isAgentWorking || !model.isAgentExecutionAllowed)
                .accessibilityIdentifier("chapter-rewrite-confirm-button")
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func versionHistory(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Version history").font(.headline)
            ForEach(chapter.versions) { version in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Revision \(version.revision)").font(.subheadline.bold())
                    Text("ID: \(version.id.uuidString)")
                    Text("Hash: \(version.contentHash)")
                    Text(version.diffSummary ?? "Base revision; no parent diff")
                    if let parent = parentVersion(for: version, in: chapter) {
                        let diff = ChapterContentIntegrity.diff(
                            originalBody: parent.body,
                            revisedBody: version.body
                        )
                        Text("Changed paragraphs: \(indexList(diff.changedParagraphIndexes))")
                            .accessibilityIdentifier("chapter-history-diff-\(version.revision)")
                    }
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.vertical, 4)
            }
        }
        .accessibilityIdentifier("chapter-version-history")
    }

    private func reviewActions(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Decision").font(.headline)
            Button("Accept and freeze exact revision") {
                if model.acceptChapter(
                    versionID: displayedVersionID,
                    displayedContentHash: displayedContentHash
                ) {
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isAgentWorking || !model.isAgentExecutionAllowed)
            .accessibilityIdentifier("chapter-accept-freeze-button")

            if chapter.stage == .reviewingV1 {
                Text("Rejecting starts a governed three-question diagnosis. It does not reroll the chapter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $rejectionReason)
                    .frame(minHeight: 90)
                    .padding(6)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("chapter-rejection-reason")
                Button("Reject and diagnose") {
                    if model.rejectChapter(
                        reason: rejectionReason,
                        versionID: displayedVersionID,
                        displayedContentHash: displayedContentHash
                    ) {
                        dismiss()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isAgentWorking || !model.isAgentExecutionAllowed)
                .accessibilityIdentifier("chapter-reject-diagnose-button")
            } else {
                Text("Revision 2 is the final calibration candidate. Accept and freeze it, or close this review without changing the persisted chapter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("chapter-v2-final-guidance")
            }
        }
    }

    private func parentVersion(
        for version: ChapterVersion,
        in chapter: ChapterRuntimeSnapshot
    ) -> ChapterVersion? {
        guard let parentID = version.parentVersionID else { return nil }
        return chapter.versions.first { $0.id == parentID }
    }

    private func lockedDescription(_ chapter: ChapterRuntimeSnapshot) -> String {
        let indexes = chapter.calibration.lockedParagraphIndexes.map { String($0 + 1) }
        return indexes.isEmpty ? "none" : indexes.joined(separator: ", ")
    }

    private func indexList(_ indexes: [Int]) -> String {
        indexes.isEmpty ? "none" : indexes.map { String($0 + 1) }.joined(separator: ", ")
    }
}
