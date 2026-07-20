import CangJieCore
import Foundation
import GRDB

extension AppDatabase {
    func loadS1NovelProgressFacts() throws -> [UUID: S1NovelProgressFacts] {
        try queue.read { db in
            let projectRows = try Row.fetchAll(
                db,
                sql: "SELECT id, premise FROM novelProject"
            )
            let initial = Dictionary(
                uniqueKeysWithValues: projectRows.compactMap(Self.s1ProjectProgressEntry(from:))
            )

            let chapterRows = try Row.fetchAll(
                db,
                sql: """
                    SELECT
                        project.id AS shelfProjectID,
                        calibration.chapterLogicalID AS chapterLogicalID,
                        calibration.conversationID AS conversationID,
                        calibration.projectID AS calibrationProjectID,
                        calibration.chapterNumber AS chapterNumber,
                        calibration.activeVersionID AS activeVersionID,
                        calibration.stage AS stage,
                        calibration.diagnosisEntriesJSON AS diagnosisEntriesJSON,
                        calibration.diagnosisHash AS diagnosisHash,
                        calibration.rejectionHistoryJSON AS rejectionHistoryJSON,
                        calibration.lockedParagraphIndexesJSON AS lockedParagraphIndexesJSON,
                        calibration.rewriteScope AS rewriteScope,
                        calibration.rewriteScopeHash AS rewriteScopeHash,
                        calibration.acceptedVersionID AS acceptedVersionID,
                        version.id AS versionID,
                        version.logicalID AS versionLogicalID,
                        version.conversationID AS versionConversationID,
                        version.projectID AS versionProjectID,
                        version.chapterNumber AS versionChapterNumber,
                        version.revision AS revision,
                        version.parentVersionID AS parentVersionID,
                        version.title AS chapterTitle,
                        version.body AS body,
                        version.contentHash AS contentHash,
                        version.creationStatus AS creationStatus
                    FROM novelProject AS project
                    JOIN chapterCalibration AS calibration
                      ON calibration.projectID = project.id
                    JOIN chapterVersion AS version
                      ON version.id = calibration.activeVersionID
                    """
            )

            let accumulated = chapterRows.reduce(initial) { current, row in
                guard let chapter = Self.trustedS1ProgressChapter(from: row),
                      let existing = current[chapter.projectID] else {
                    return current
                }
                let updated = existing.including(chapter)
                return current.merging([chapter.projectID: updated]) { _, new in new }
            }

            return accumulated.mapValues(\.facts)
        }
    }

    private static func s1ProjectProgressEntry(
        from row: Row
    ) -> (UUID, S1NovelProgressAccumulator)? {
        let idText: String = row["id"]
        let premise: String = row["premise"]
        guard let projectID = UUID(uuidString: idText) else { return nil }
        return (
            projectID,
            S1NovelProgressAccumulator(
                hasSavedStoryIdea: !premise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                latestAvailableChapterNumber: nil,
                awaitingReviewChapterNumber: nil,
                editingChapterNumber: nil
            )
        )
    }

    private static func trustedS1ProgressChapter(from row: Row) -> S1TrustedProgressChapter? {
        let shelfProjectText: String = row["shelfProjectID"]
        let logicalText: String = row["chapterLogicalID"]
        let conversationText: String = row["conversationID"]
        let calibrationProjectText: String = row["calibrationProjectID"]
        let activeVersionText: String = row["activeVersionID"]
        let versionText: String = row["versionID"]
        let versionLogicalText: String = row["versionLogicalID"]
        let versionConversationText: String = row["versionConversationID"]
        let versionProjectText: String = row["versionProjectID"]
        let stageText: String = row["stage"]
        let creationStatusText: String = row["creationStatus"]

        guard let shelfProjectID = UUID(uuidString: shelfProjectText),
              let logicalID = UUID(uuidString: logicalText),
              let conversationID = UUID(uuidString: conversationText),
              let calibrationProjectID = UUID(uuidString: calibrationProjectText),
              let activeVersionID = UUID(uuidString: activeVersionText),
              let versionID = UUID(uuidString: versionText),
              let versionLogicalID = UUID(uuidString: versionLogicalText),
              let versionConversationID = UUID(uuidString: versionConversationText),
              let versionProjectID = UUID(uuidString: versionProjectText),
              let stage = ChapterCalibrationStage(rawValue: stageText),
              stage != .notStarted,
              let creationStatus = ChapterVersionCreationStatus(rawValue: creationStatusText),
              creationStatus == .calibrationReview else {
            return nil
        }

        let chapterNumber: Int = row["chapterNumber"]
        let versionChapterNumber: Int = row["versionChapterNumber"]
        let revision: Int = row["revision"]
        let title: String = row["chapterTitle"]
        let body: String = row["body"]
        let storedContentHash: String = row["contentHash"]

        guard chapterNumber > 0,
              versionChapterNumber == chapterNumber,
              revision > 0,
              shelfProjectID == calibrationProjectID,
              versionProjectID == calibrationProjectID,
              versionConversationID == conversationID,
              versionLogicalID == logicalID,
              activeVersionID == versionID,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !storedContentHash.isEmpty else {
            return nil
        }

        let parentText: String? = row["parentVersionID"]
        let acceptedText: String? = row["acceptedVersionID"]
        guard let parentVersionID = validOptionalUUID(parentText),
              let acceptedVersionID = validOptionalUUID(acceptedText) else {
            return nil
        }

        let calculatedContentHash = ChapterFingerprint.versionHash(
            id: versionID,
            logicalID: versionLogicalID,
            conversationID: versionConversationID,
            projectID: versionProjectID,
            chapterNumber: versionChapterNumber,
            revision: revision,
            parentVersionID: parentVersionID,
            title: title,
            body: body
        )
        guard storedContentHash == calculatedContentHash else { return nil }

        let diagnosisJSON: String = row["diagnosisEntriesJSON"]
        let diagnosisHash: String = row["diagnosisHash"]
        let rejectionJSON: String = row["rejectionHistoryJSON"]
        let lockedJSON: String = row["lockedParagraphIndexesJSON"]
        guard let diagnosisEntries = decodeJSON([ChapterDiagnosisEntry].self, from: diagnosisJSON),
              diagnosisHash == ChapterFingerprint.diagnosisHash(diagnosisEntries),
              decodeJSON([ChapterRejectionEntry].self, from: rejectionJSON) != nil,
              let lockedIndexes = decodeJSON([Int].self, from: lockedJSON),
              lockedIndexes == Array(Set(lockedIndexes)).sorted(),
              lockedIndexes.allSatisfy({
                  $0 >= 0 && $0 < ChapterByteExactParagraphs.split(body).count
              }) else {
            return nil
        }

        let rewriteScope: String? = row["rewriteScope"]
        let rewriteScopeHash: String? = row["rewriteScopeHash"]
        guard (rewriteScope == nil) == (rewriteScopeHash == nil),
              rewriteScope.map(ChapterFingerprint.rewriteScopeHash) == rewriteScopeHash,
              acceptedVersionIsValid(
                  stage: stage,
                  acceptedVersionID: acceptedVersionID,
                  activeVersionID: activeVersionID
              ) else {
            return nil
        }

        return S1TrustedProgressChapter(
            projectID: shelfProjectID,
            chapterNumber: chapterNumber,
            stage: stage
        )
    }

    private static func validOptionalUUID(_ text: String?) -> UUID?? {
        guard let text else { return .some(nil) }
        guard let value = UUID(uuidString: text) else { return nil }
        return .some(value)
    }

    private static func decodeJSON<Value: Decodable>(
        _ type: Value.Type,
        from text: String
    ) -> Value? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func acceptedVersionIsValid(
        stage: ChapterCalibrationStage,
        acceptedVersionID: UUID?,
        activeVersionID: UUID
    ) -> Bool {
        if stage == .approvedFrozen {
            return acceptedVersionID == activeVersionID
        }
        return acceptedVersionID == nil
    }
}

private struct S1TrustedProgressChapter {
    let projectID: UUID
    let chapterNumber: Int
    let stage: ChapterCalibrationStage
}

private struct S1NovelProgressAccumulator {
    let hasSavedStoryIdea: Bool
    let latestAvailableChapterNumber: Int?
    let awaitingReviewChapterNumber: Int?
    let editingChapterNumber: Int?

    var facts: S1NovelProgressFacts {
        S1NovelProgressFacts(
            hasSavedStoryIdea: hasSavedStoryIdea,
            latestAvailableChapterNumber: latestAvailableChapterNumber,
            awaitingReviewChapterNumber: awaitingReviewChapterNumber,
            editingChapterNumber: editingChapterNumber
        )
    }

    func including(_ chapter: S1TrustedProgressChapter) -> S1NovelProgressAccumulator {
        S1NovelProgressAccumulator(
            hasSavedStoryIdea: hasSavedStoryIdea,
            latestAvailableChapterNumber: maximum(
                latestAvailableChapterNumber,
                chapter.chapterNumber
            ),
            awaitingReviewChapterNumber: chapter.stage == .reviewingV1 || chapter.stage == .reviewingV2
                ? maximum(awaitingReviewChapterNumber, chapter.chapterNumber)
                : awaitingReviewChapterNumber,
            editingChapterNumber: Self.isEditing(chapter.stage)
                ? maximum(editingChapterNumber, chapter.chapterNumber)
                : editingChapterNumber
        )
    }

    private func maximum(_ current: Int?, _ candidate: Int) -> Int {
        max(current ?? candidate, candidate)
    }

    private static func isEditing(_ stage: ChapterCalibrationStage) -> Bool {
        switch stage {
        case .diagnosing, .awaitingRewriteConfirmation, .rewriting:
            return true
        case .notStarted, .reviewingV1, .reviewingV2, .approvedFrozen:
            return false
        }
    }
}
