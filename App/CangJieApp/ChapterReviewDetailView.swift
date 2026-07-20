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
                        reviewSummary(chapter)
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
                            Text("正文已经更新")
                                .font(.headline)
                            Text("请先关闭这个页面，再打开最新的第一章。旧页面不会覆盖新内容。")
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
            .navigationTitle(S1OrdinarySurfaceContract.chapterHeading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(S1OrdinarySurfaceContract.reviewLaterButton) { dismiss() }
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

    private func reviewSummary(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(chapter.activeVersion.title)
                .font(.title2.bold())
                .accessibilityIdentifier("chapter-review-title")
            Text(S1OrdinarySurfaceContract.chapterStageDescription(chapter.stage))
                .font(.subheadline.weight(.medium))
                .accessibilityIdentifier("chapter-review-status")
            Text(S1OrdinarySurfaceContract.chapterExplanation)
            Text(
                S1OrdinarySurfaceContract.protectedParagraphsDescription(
                    chapter.calibration.lockedParagraphIndexes
                )
            )
            .accessibilityIdentifier("chapter-review-locked-summary")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func chapterBody(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("第一章正文")
                .font(.headline)
            ForEach(Array(model.chapterParagraphs.enumerated()), id: \.offset) { index, paragraph in
                let isLocked = chapter.calibration.lockedParagraphIndexes.contains(index)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("第 \(index + 1) 段")
                            .font(.caption.bold())
                        Spacer()
                        if chapter.stage == .reviewingV1 || chapter.stage == .reviewingV2 {
                            Button(isLocked ? "取消保留" : "这段保留不动") {
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
                            Label("已保留不动", systemImage: "lock.fill")
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
            Text("仓颉的检查结果")
                .font(.headline)
            Text(version.evidenceReview)
                .font(.footnote)
                .textSelection(.enabled)
                .accessibilityIdentifier("chapter-evidence-review")
        }
    }

    private func rewriteScope(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(S1OrdinarySurfaceContract.rewriteHeading)
                .font(.headline)
            Text(S1OrdinarySurfaceContract.rewriteExplanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(chapter.calibration.rewriteScope ?? "还没有可确认的修改范围")
                .textSelection(.enabled)
                .accessibilityIdentifier("chapter-rewrite-scope-body")
            if let scopeHash = chapter.calibration.rewriteScopeHash {
                Button(S1OrdinarySurfaceContract.rewriteApproveButton) {
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
            Text("以前的版本")
                .font(.headline)
            ForEach(Array(chapter.versions.enumerated()), id: \.element.id) { index, version in
                VStack(alignment: .leading, spacing: 4) {
                    Text("第 \(index + 1) 版")
                        .font(.subheadline.bold())
                    if let parent = parentVersion(for: version, in: chapter) {
                        let diff = ChapterContentIntegrity.diff(
                            originalBody: parent.body,
                            revisedBody: version.body
                        )
                        Text(
                            S1OrdinarySurfaceContract.changedParagraphsDescription(
                                diff.changedParagraphIndexes
                            )
                        )
                        .accessibilityIdentifier("chapter-history-diff-\(version.revision)")
                    } else {
                        Text("这是最初保存的版本")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            }
        }
        .accessibilityIdentifier("chapter-version-history")
    }

    private func reviewActions(_ chapter: ChapterRuntimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("你想怎么继续")
                .font(.headline)
            Button(S1OrdinarySurfaceContract.chapterApproveButton) {
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
                Text("如果不对，只要说最明显的感觉。仓颉会先理解问题，不会直接随机重写。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $rejectionReason)
                    .frame(minHeight: 90)
                    .padding(6)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("chapter-rejection-reason")
                Button(S1OrdinarySurfaceContract.chapterRejectButton) {
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
                .disabled(
                    rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || model.isAgentWorking
                        || !model.isAgentExecutionAllowed
                )
                .accessibilityIdentifier("chapter-reject-diagnose-button")
            } else {
                Text("这是根据你的意见改好的版本。你可以确认继续，也可以先关闭页面，正文不会因此被覆盖。")
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
}
