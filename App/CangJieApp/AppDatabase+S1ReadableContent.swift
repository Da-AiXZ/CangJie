import CangJieCore
import Foundation
import GRDB

extension AppDatabase {
    func restoreS1ReadableContent(
        selectedConversationID: UUID?
    ) throws -> S1ReadableContentProjection? {
        guard let selectedConversationID else { return nil }

        return try queue.read { db in
            guard let sessionRow = try Row.fetchOne(
                db,
                sql: "SELECT focusedProjectID FROM agentSession WHERE conversationID = ?",
                arguments: [selectedConversationID.uuidString]
            ) else {
                return nil
            }

            let focusedProjectText: String? = sessionRow["focusedProjectID"]
            guard let focusedProjectText,
                  let focusedProjectID = UUID(uuidString: focusedProjectText) else {
                return nil
            }

            guard let row = try Row.fetchOne(
                db,
                sql: Self.s1ReadableContentSelect + """
                    WHERE calibration.conversationID = ?
                      AND calibration.projectID = ?
                    ORDER BY calibration.chapterNumber DESC, calibration.updatedAt DESC
                    LIMIT 1
                    """,
                arguments: [selectedConversationID.uuidString, focusedProjectID.uuidString]
            ) else {
                return nil
            }

            return Self.s1ReadableProjection(
                from: row,
                selectedConversationID: selectedConversationID,
                focusedProjectID: focusedProjectID
            )
        }
    }

    func loadS1ReadableContent(
        projectID: UUID
    ) throws -> S1ReadableContentProjection? {
        try queue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: Self.s1ReadableContentSelect + """
                    WHERE calibration.projectID = ?
                    ORDER BY calibration.chapterNumber DESC, calibration.updatedAt DESC
                    """,
                arguments: [projectID.uuidString]
            )

            for row in rows {
                let conversationText: String = row["conversationID"]
                guard let conversationID = UUID(uuidString: conversationText) else {
                    continue
                }
                if let projection = Self.s1ReadableProjection(
                    from: row,
                    selectedConversationID: conversationID,
                    focusedProjectID: projectID
                ) {
                    return projection
                }
            }
            return nil
        }
    }

    private static let s1ReadableContentSelect = """
        SELECT
            calibration.chapterLogicalID AS chapterLogicalID,
            calibration.conversationID AS conversationID,
            calibration.projectID AS projectID,
            calibration.chapterNumber AS chapterNumber,
            calibration.activeVersionID AS activeVersionID,
            calibration.acceptedVersionID AS acceptedVersionID,
            calibration.stage AS stage,
            project.title AS projectTitle,
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
        FROM chapterCalibration AS calibration
        JOIN chapterVersion AS version
          ON version.id = calibration.activeVersionID
        JOIN novelProject AS project
          ON project.id = calibration.projectID
        """

    private static func s1ReadableProjection(
        from row: Row,
        selectedConversationID: UUID,
        focusedProjectID: UUID
    ) -> S1ReadableContentProjection? {
        let conversationText: String = row["conversationID"]
        let projectText: String = row["projectID"]
        let chapterLogicalText: String = row["chapterLogicalID"]
        let activeVersionText: String = row["activeVersionID"]
        let acceptedVersionText: String? = row["acceptedVersionID"]
        let versionText: String = row["versionID"]
        let versionLogicalText: String = row["versionLogicalID"]
        let versionConversationText: String = row["versionConversationID"]
        let versionProjectText: String = row["versionProjectID"]
        let stageText: String = row["stage"]
        let creationStatusText: String = row["creationStatus"]

        guard let conversationID = UUID(uuidString: conversationText),
              let projectID = UUID(uuidString: projectText),
              let chapterLogicalID = UUID(uuidString: chapterLogicalText),
              let activeVersionID = UUID(uuidString: activeVersionText),
              let versionID = UUID(uuidString: versionText),
              let versionLogicalID = UUID(uuidString: versionLogicalText),
              let versionConversationID = UUID(uuidString: versionConversationText),
              let versionProjectID = UUID(uuidString: versionProjectText),
              let stage = ChapterCalibrationStage(rawValue: stageText),
              let creationStatus = ChapterVersionCreationStatus(rawValue: creationStatusText) else {
            return nil
        }

        let chapterNumber: Int = row["chapterNumber"]
        let versionChapterNumber: Int = row["versionChapterNumber"]
        let revision: Int = row["revision"]
        let parentVersionText: String? = row["parentVersionID"]
        let parentVersionID = parentVersionText.flatMap(UUID.init(uuidString:))
        let acceptedVersionID = acceptedVersionText.flatMap(UUID.init(uuidString:))
        let projectTitle: String = row["projectTitle"]
        let chapterTitle: String = row["chapterTitle"]
        let body: String = row["body"]
        let storedContentHash: String = row["contentHash"]

        guard projectID == focusedProjectID,
              revision > 0,
              versionID == activeVersionID,
              versionLogicalID == chapterLogicalID,
              versionConversationID == conversationID,
              versionProjectID == projectID,
              versionChapterNumber == chapterNumber else {
            return nil
        }

        if acceptedVersionText != nil, acceptedVersionID == nil {
            return nil
        }
        switch stage {
        case .approvedFrozen:
            guard acceptedVersionID == activeVersionID else { return nil }
        default:
            guard acceptedVersionID == nil else { return nil }
        }

        let calculatedContentHash = ChapterFingerprint.versionHash(
            id: versionID,
            logicalID: versionLogicalID,
            conversationID: versionConversationID,
            projectID: versionProjectID,
            chapterNumber: versionChapterNumber,
            revision: revision,
            parentVersionID: parentVersionID,
            title: chapterTitle,
            body: body
        )

        return S1ReadableContentProjection.select(
            selectedConversationID: selectedConversationID,
            focusedProjectID: focusedProjectID,
            candidate: S1ReadableContentCandidate(
                conversationID: conversationID,
                projectID: projectID,
                chapterLogicalID: chapterLogicalID,
                activeVersionID: activeVersionID,
                versionID: versionID,
                projectTitle: projectTitle,
                chapterNumber: chapterNumber,
                chapterTitle: chapterTitle,
                body: body,
                storedContentHash: storedContentHash,
                calculatedContentHash: calculatedContentHash,
                stage: stage,
                isCommitted: creationStatus == .calibrationReview
            )
        )
    }
}
