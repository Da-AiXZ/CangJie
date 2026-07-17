import CangJieCore
import Foundation
import GRDB

extension AppDatabase {
    private static let chapterToolVersion = "1"

    func executeChapterGenerateTool(
        conversationID: UUID,
        projectID: UUID,
        chapterNumber: Int,
        title: String,
        body: String,
        evidenceReview: String,
        openingPlanArtifactID: UUID,
        openingPlanHash: String,
        idempotencyKey: String,
        originRunID: UUID? = nil,
        now: Date = Date()
    ) throws -> ChapterToolResult {
        try ChapterInputLimits.require(title, field: "title", maximumUTF8Bytes: ChapterInputLimits.titleUTF8Bytes)
        try ChapterInputLimits.requireBody(body)
        try ChapterInputLimits.require(evidenceReview, field: "evidenceReview", maximumUTF8Bytes: ChapterInputLimits.evidenceUTF8Bytes)
        try ChapterInputLimits.requireNonBlank(openingPlanHash, field: "openingPlanHash", maximumUTF8Bytes: ChapterInputLimits.hashUTF8Bytes)
        try ChapterInputLimits.requireNonBlank(idempotencyKey, field: "idempotencyKey", maximumUTF8Bytes: ChapterInputLimits.idempotencyKeyUTF8Bytes)
        let toolID = "chapter.generate"
        let inputSummary = "chapter:\(chapterNumber):generate"
        let inputHash = ChapterFingerprint.inputHash(toolID: toolID, fields: [
            conversationID.uuidString, projectID.uuidString, String(chapterNumber),
            title, body, evidenceReview, openingPlanArtifactID.uuidString, openingPlanHash
        ])
        return try queue.write { db in
            if let replay = try Self.replayChapterTool(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, in: db
            ) { return replay }

            guard chapterNumber > 0, !title.isEmpty, !body.isEmpty else {
                throw AppDatabaseError.invalidChapterVersion
            }
            try Self.requireChapterScope(conversationID: conversationID, projectID: projectID, in: db)
            try Self.requireApprovedOpeningPlan(
                conversationID: conversationID, projectID: projectID,
                artifactID: openingPlanArtifactID, artifactHash: openingPlanHash, in: db
            )
            guard try Self.calibration(
                conversationID: conversationID, projectID: projectID,
                chapterNumber: chapterNumber, in: db
            ) == nil else {
                throw AppDatabaseError.chapterOperationNotAllowed
            }

            let versionID = UUID()
            let version = ChapterVersion(
                id: versionID, logicalID: versionID,
                conversationID: conversationID, projectID: projectID,
                chapterNumber: chapterNumber, revision: 1, parentVersionID: nil,
                title: title, body: body,
                contentHash: ChapterFingerprint.versionHash(
                    id: versionID, logicalID: versionID,
                    conversationID: conversationID, projectID: projectID,
                    chapterNumber: chapterNumber, revision: 1, parentVersionID: nil,
                    title: title, body: body
                ),
                creationStatus: .calibrationReview,
                evidenceReview: evidenceReview, diffSummary: nil, createdAt: now
            )
            let emptyDiagnosis: [ChapterDiagnosisEntry] = []
            let calibration = ChapterCalibration(
                chapterLogicalID: version.logicalID,
                conversationID: conversationID, projectID: projectID,
                chapterNumber: chapterNumber, activeVersionID: version.id,
                stage: try ChapterCalibrationMachine(stage: .notStarted).applying(.generateV1).stage,
                diagnosisEntries: emptyDiagnosis,
                diagnosisHash: ChapterFingerprint.diagnosisHash(emptyDiagnosis),
                rejectionHistory: [], lockedParagraphIndexes: [],
                rewriteScope: nil, rewriteScopeHash: nil,
                acceptedVersionID: nil, updatedAt: now
            )
            try Self.insertChapterVersion(version, in: db)
            try Self.insertChapterCalibration(calibration, in: db)
            let receipt = Self.makeChapterReceipt(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, outputVersionID: version.id, now: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            try Self.insertChapterToolResultSnapshot(receipt: receipt, version: version, calibration: calibration, in: db)
            return ChapterToolResult(
                version: version, calibration: calibration,
                receipt: receipt, isReplay: false
            )
        }
    }

    func executeChapterLockParagraphSetTool(
        conversationID: UUID,
        projectID: UUID,
        versionID: UUID,
        displayedContentHash: String,
        lockedParagraphIndexes: [Int],
        idempotencyKey: String,
        originRunID: UUID? = nil,
        now: Date = Date()
    ) throws -> ChapterToolResult {
        try ChapterInputLimits.requireCommonBinding(displayedHash: displayedContentHash, idempotencyKey: idempotencyKey)
        try ChapterInputLimits.requireLockedIndexes(lockedParagraphIndexes)
        let canonicalIndexes = Array(Set(lockedParagraphIndexes)).sorted()
        let toolID = "chapter.lockParagraph.set"
        let inputSummary = "chapter:\(versionID.uuidString):lockParagraph"
        let inputHash = ChapterFingerprint.inputHash(toolID: toolID, fields: [
            conversationID.uuidString, projectID.uuidString, versionID.uuidString,
            displayedContentHash, canonicalIndexes.map(String.init).joined(separator: ",")
        ])
        return try queue.write { db in
            if let replay = try Self.replayChapterTool(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, in: db
            ) { return replay }

            let (version, calibration) = try Self.requireActiveChapterBinding(
                conversationID: conversationID, projectID: projectID,
                versionID: versionID, displayedContentHash: displayedContentHash, in: db
            )
            guard calibration.stage == .reviewingV1 || calibration.stage == .reviewingV2 else {
                throw AppDatabaseError.chapterOperationNotAllowed
            }
            _ = try ChapterFingerprint.lockedParagraphBinding(
                body: version.body, indexes: canonicalIndexes
            )
            let updated = Self.copyCalibration(
                calibration, lockedParagraphIndexes: canonicalIndexes, updatedAt: now
            )
            let receipt = Self.makeChapterReceipt(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, outputVersionID: version.id, now: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            try Self.insertChapterToolResultSnapshot(receipt: receipt, version: version, calibration: updated, in: db)
            try Self.updateChapterCalibration(updated, in: db)
            return ChapterToolResult(
                version: version, calibration: updated,
                receipt: receipt, isReplay: false
            )
        }
    }
    func executeChapterRejectTool(
        conversationID: UUID,
        projectID: UUID,
        versionID: UUID,
        displayedContentHash: String,
        reason: String,
        idempotencyKey: String,
        originRunID: UUID? = nil,
        now: Date = Date()
    ) throws -> ChapterToolResult {
        try ChapterInputLimits.requireCommonBinding(displayedHash: displayedContentHash, idempotencyKey: idempotencyKey)
        try ChapterInputLimits.require(reason, field: "rejection", maximumUTF8Bytes: ChapterInputLimits.rejectionUTF8Bytes)
        let toolID = "chapter.reject"
        let inputSummary = "chapter:\(versionID.uuidString):reject"
        let inputHash = ChapterFingerprint.inputHash(toolID: toolID, fields: [
            conversationID.uuidString, projectID.uuidString, versionID.uuidString,
            displayedContentHash, reason
        ])
        return try queue.write { db in
            if let replay = try Self.replayChapterTool(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, in: db
            ) { return replay }
            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AppDatabaseError.invalidChapterDiagnosis
            }
            let (version, calibration) = try Self.requireActiveChapterBinding(
                conversationID: conversationID, projectID: projectID,
                versionID: versionID, displayedContentHash: displayedContentHash, in: db
            )
            let nextStage = try ChapterCalibrationMachine(stage: calibration.stage)
                .applying(.reject).stage
            let rejection = ChapterRejectionEntry(
                versionID: version.id, versionHash: version.contentHash,
                reason: reason, createdAt: now
            )
            let updated = Self.copyCalibration(
                calibration,
                stage: nextStage,
                rejectionHistory: calibration.rejectionHistory + [rejection],
                rewriteScope: .some(nil),
                rewriteScopeHash: .some(nil),
                acceptedVersionID: .some(nil),
                updatedAt: now
            )
            try Self.updateChapterCalibration(updated, in: db)
            let receipt = Self.makeChapterReceipt(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, outputVersionID: version.id, now: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            try Self.insertChapterToolResultSnapshot(receipt: receipt, version: version, calibration: updated, in: db)
            return ChapterToolResult(
                version: version, calibration: updated,
                receipt: receipt, isReplay: false
            )
        }
    }

    func executeChapterDiagnosisAnswerTool(
        conversationID: UUID,
        projectID: UUID,
        versionID: UUID,
        displayedContentHash: String,
        questionID: String,
        question: String,
        answer: String,
        rewriteScope: String?,
        idempotencyKey: String,
        originRunID: UUID? = nil,
        now: Date = Date()
    ) throws -> ChapterToolResult {
        try ChapterInputLimits.requireCommonBinding(displayedHash: displayedContentHash, idempotencyKey: idempotencyKey)
        try ChapterInputLimits.require(questionID, field: "questionID", maximumUTF8Bytes: ChapterInputLimits.questionIDUTF8Bytes)
        try ChapterInputLimits.require(question, field: "question", maximumUTF8Bytes: ChapterInputLimits.questionUTF8Bytes)
        try ChapterInputLimits.require(answer, field: "answer", maximumUTF8Bytes: ChapterInputLimits.answerUTF8Bytes)
        if let rewriteScope {
            try ChapterInputLimits.require(rewriteScope, field: "rewriteScope", maximumUTF8Bytes: ChapterInputLimits.rewriteScopeUTF8Bytes)
        }
        let toolID = "chapter.diagnosis.answer"
        let inputSummary = "chapter:\(versionID.uuidString):diagnosis:\(questionID)"
        let inputHash = ChapterFingerprint.inputHash(toolID: toolID, fields: [
            conversationID.uuidString, projectID.uuidString, versionID.uuidString,
            displayedContentHash, questionID, question, answer, rewriteScope ?? ""
        ])
        return try queue.write { db in
            if let replay = try Self.replayChapterTool(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, in: db
            ) { return replay }
            guard !questionID.isEmpty,
                  !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AppDatabaseError.invalidChapterDiagnosis
            }
            let (version, calibration) = try Self.requireActiveChapterBinding(
                conversationID: conversationID, projectID: projectID,
                versionID: versionID, displayedContentHash: displayedContentHash, in: db
            )
            let currentEntries = calibration.diagnosisEntries.filter {
                $0.versionID == version.id && $0.versionHash == version.contentHash
            }
            guard calibration.stage == .diagnosing,
                  currentEntries.count < ChapterDiagnosisProtocol.orderedQuestionIDs.count,
                  let expectedQuestionID = ChapterDiagnosisProtocol.expectedQuestionID(answerCount: currentEntries.count),
                  let expectedQuestion = ChapterDiagnosisProtocol.expectedQuestion(answerCount: currentEntries.count),
                  questionID == expectedQuestionID,
                  question == expectedQuestion,
                  !currentEntries.contains(where: { $0.questionID == questionID }) else {
                throw AppDatabaseError.invalidChapterDiagnosis
            }
            let isFinalQuestion = currentEntries.count == ChapterDiagnosisProtocol.orderedQuestionIDs.count - 1
            if isFinalQuestion {
                guard let rewriteScope,
                      !rewriteScope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AppDatabaseError.invalidRewriteScope
                }
            } else if rewriteScope != nil {
                throw AppDatabaseError.invalidRewriteScope
            }
            let entry = ChapterDiagnosisEntry(
                versionID: version.id, versionHash: version.contentHash,
                questionID: questionID, question: question,
                answer: answer, createdAt: now
            )
            let entries = calibration.diagnosisEntries + [entry]
            let finalScope = isFinalQuestion ? rewriteScope : nil
            let finalScopeHash = finalScope.map(ChapterFingerprint.rewriteScopeHash)
            let nextStage = isFinalQuestion
                ? try ChapterCalibrationMachine(stage: calibration.stage).applying(.completeDiagnosis).stage
                : calibration.stage
            let updated = Self.copyCalibration(
                calibration,
                stage: nextStage,
                diagnosisEntries: entries,
                diagnosisHash: ChapterFingerprint.diagnosisHash(entries),
                rewriteScope: .some(finalScope),
                rewriteScopeHash: .some(finalScopeHash),
                updatedAt: now
            )
            try Self.updateChapterCalibration(updated, in: db)
            let receipt = Self.makeChapterReceipt(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, outputVersionID: version.id, now: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            try Self.insertChapterToolResultSnapshot(receipt: receipt, version: version, calibration: updated, in: db)
            return ChapterToolResult(
                version: version, calibration: updated,
                receipt: receipt, isReplay: false
            )
        }
    }
    func executeChapterRewriteTool(
        conversationID: UUID,
        projectID: UUID,
        sourceVersionID: UUID,
        displayedSourceHash: String,
        diagnosisHash: String,
        rewriteScopeHash: String,
        displayedLockedParagraphIndexes: [Int],
        title: String,
        body: String,
        evidenceReview: String,
        idempotencyKey: String,
        originRunID: UUID? = nil,
        now: Date = Date()
    ) throws -> ChapterToolResult {
        try ChapterInputLimits.requireCommonBinding(displayedHash: displayedSourceHash, idempotencyKey: idempotencyKey)
        try ChapterInputLimits.require(diagnosisHash, field: "diagnosisHash", maximumUTF8Bytes: ChapterInputLimits.hashUTF8Bytes)
        try ChapterInputLimits.require(rewriteScopeHash, field: "rewriteScopeHash", maximumUTF8Bytes: ChapterInputLimits.hashUTF8Bytes)
        try ChapterInputLimits.requireLockedIndexes(displayedLockedParagraphIndexes)
        try ChapterInputLimits.require(title, field: "title", maximumUTF8Bytes: ChapterInputLimits.titleUTF8Bytes)
        try ChapterInputLimits.requireBody(body)
        try ChapterInputLimits.require(evidenceReview, field: "evidenceReview", maximumUTF8Bytes: ChapterInputLimits.evidenceUTF8Bytes)
        let canonicalIndexes = Array(Set(displayedLockedParagraphIndexes)).sorted()
        let toolID = "chapter.rewrite"
        let inputSummary = "chapter:\(sourceVersionID.uuidString):rewrite"
        let inputHash = ChapterFingerprint.inputHash(toolID: toolID, fields: [
            conversationID.uuidString, projectID.uuidString, sourceVersionID.uuidString,
            displayedSourceHash, diagnosisHash, rewriteScopeHash,
            canonicalIndexes.map(String.init).joined(separator: ","),
            title, body, evidenceReview
        ])
        return try queue.write { db in
            if let replay = try Self.replayChapterTool(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, in: db
            ) { return replay }
            guard !title.isEmpty, !body.isEmpty else {
                throw AppDatabaseError.invalidChapterVersion
            }
            let (source, calibration) = try Self.requireActiveChapterBinding(
                conversationID: conversationID, projectID: projectID,
                versionID: sourceVersionID, displayedContentHash: displayedSourceHash,
                in: db
            )
            let activeDiagnosis = calibration.diagnosisEntries.filter {
                $0.versionID == source.id && $0.versionHash == source.contentHash
            }
            guard calibration.stage == .awaitingRewriteConfirmation,
                  calibration.diagnosisHash == diagnosisHash,
                  calibration.rewriteScopeHash == rewriteScopeHash,
                  calibration.lockedParagraphIndexes == canonicalIndexes,
                  activeDiagnosis.map(\.questionID) == ChapterDiagnosisProtocol.orderedQuestionIDs,
                  activeDiagnosis.map(\.question) == ChapterDiagnosisProtocol.orderedQuestions else {
                throw AppDatabaseError.chapterBindingMismatch
            }
            try ChapterByteExactParagraphs.validateLockedParagraphs(
                originalBody: source.body,
                revisedBody: body,
                indexes: canonicalIndexes
            )
            let rewriting = try ChapterCalibrationMachine(stage: calibration.stage)
                .applying(.confirmRewrite)
            let reviewing = try rewriting.applying(.presentV2)
            let lineage = try Self.validatedLineage(logicalID: source.logicalID, in: db)
            guard lineage.last?.id == source.id else {
                throw AppDatabaseError.chapterBindingMismatch
            }
            let revision = source.revision + 1
            let versionID = UUID()
            let version = ChapterVersion(
                id: versionID,
                logicalID: source.logicalID,
                conversationID: conversationID,
                projectID: projectID,
                chapterNumber: source.chapterNumber,
                revision: revision,
                parentVersionID: source.id,
                title: title,
                body: body,
                contentHash: ChapterFingerprint.versionHash(
                    id: versionID,
                    logicalID: source.logicalID,
                    conversationID: conversationID,
                    projectID: projectID,
                    chapterNumber: source.chapterNumber,
                    revision: revision,
                    parentVersionID: source.id,
                    title: title,
                    body: body
                ),
                creationStatus: .calibrationReview,
                evidenceReview: evidenceReview,
                diffSummary: Self.chapterDiffSummary(
                    originalBody: source.body, revisedBody: body
                ),
                createdAt: now
            )
            let updated = Self.copyCalibration(
                calibration,
                activeVersionID: version.id,
                stage: reviewing.stage,
                acceptedVersionID: .some(nil),
                updatedAt: now
            )
            try Self.insertChapterVersion(version, in: db)
            try Self.updateChapterCalibration(updated, in: db)
            let receipt = Self.makeChapterReceipt(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, outputVersionID: version.id, now: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            try Self.insertChapterToolResultSnapshot(receipt: receipt, version: version, calibration: updated, in: db)
            return ChapterToolResult(
                version: version, calibration: updated,
                receipt: receipt, isReplay: false
            )
        }
    }

    func executeChapterAcceptTool(
        conversationID: UUID,
        projectID: UUID,
        versionID: UUID,
        displayedContentHash: String,
        idempotencyKey: String,
        originRunID: UUID? = nil,
        now: Date = Date()
    ) throws -> ChapterToolResult {
        try ChapterInputLimits.requireCommonBinding(displayedHash: displayedContentHash, idempotencyKey: idempotencyKey)
        let toolID = "chapter.accept"
        let inputSummary = "chapter:\(versionID.uuidString):accept"
        let inputHash = ChapterFingerprint.inputHash(toolID: toolID, fields: [
            conversationID.uuidString, projectID.uuidString,
            versionID.uuidString, displayedContentHash
        ])
        return try queue.write { db in
            if let replay = try Self.replayChapterTool(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, in: db
            ) { return replay }
            let (version, calibration) = try Self.requireActiveChapterBinding(
                conversationID: conversationID, projectID: projectID,
                versionID: versionID, displayedContentHash: displayedContentHash, in: db
            )
            let nextStage = try ChapterCalibrationMachine(stage: calibration.stage)
                .applying(.accept).stage
            let updated = Self.copyCalibration(
                calibration,
                stage: nextStage,
                acceptedVersionID: .some(version.id),
                updatedAt: now
            )
            let receipt = Self.makeChapterReceipt(
                toolID: toolID, inputSummary: inputSummary, inputHash: inputHash,
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, originRunID: originRunID, outputVersionID: version.id, now: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            try Self.insertChapterToolResultSnapshot(receipt: receipt, version: version, calibration: updated, in: db)
            try Self.updateChapterCalibration(updated, in: db)
            return ChapterToolResult(
                version: version, calibration: updated,
                receipt: receipt, isReplay: false
            )
        }
    }

    func chapterVersion(
        id: UUID,
        conversationID: UUID,
        projectID: UUID
    ) throws -> ChapterVersion? {
        try queue.read { db in
            try Self.version(
                id: id,
                conversationID: conversationID,
                projectID: projectID,
                logicalID: nil,
                in: db
            )
        }
    }

    func listChapterVersions(
        chapterLogicalID: UUID,
        conversationID: UUID,
        projectID: UUID
    ) throws -> [ChapterVersion] {
        try queue.read { db in
            let versions = try Self.validatedLineage(logicalID: chapterLogicalID, in: db)
            guard versions.allSatisfy({
                $0.conversationID == conversationID && $0.projectID == projectID
            }) else {
                return []
            }
            return versions
        }
    }

    func latestChapterToolReceipt(
        conversationID: UUID,
        projectID: UUID,
        chapterLogicalID: UUID
    ) throws -> ToolReceipt? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT receipt.* FROM toolReceipt AS receipt
                JOIN chapterToolResultSnapshot AS snapshot ON snapshot.receiptID = receipt.id
                WHERE receipt.conversationID = ?
                  AND receipt.projectID = ?
                  AND snapshot.chapterLogicalID = ?
                  AND receipt.toolID LIKE 'chapter.%'
                ORDER BY receipt.createdAt DESC, receipt.rowid DESC
                LIMIT 1
                """,
                arguments: [conversationID.uuidString, projectID.uuidString, chapterLogicalID.uuidString]
            ) else { return nil }
            return Self.decodeToolReceipt(row)
        }
    }

    func validatedChapterToolResult(
        receiptID: UUID,
        conversationID: UUID,
        projectID: UUID,
        chapterLogicalID: UUID
    ) throws -> ChapterToolResult {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM toolReceipt WHERE id = ? AND conversationID = ? AND projectID = ? LIMIT 1",
                arguments: [receiptID.uuidString, conversationID.uuidString, projectID.uuidString]
            ), let receipt = Self.decodeToolReceipt(row) else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            return try Self.validatedChapterToolResult(
                receipt: receipt,
                chapterLogicalID: chapterLogicalID,
                in: db
            )
        }
    }

    func validatedAgentChapterToolResult(
        originRunID: UUID,
        conversationID: UUID
    ) throws -> ChapterToolResult? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT receipt.*, snapshot.chapterLogicalID AS boundChapterLogicalID
                FROM toolReceipt AS receipt
                JOIN chapterToolResultSnapshot AS snapshot ON snapshot.receiptID = receipt.id
                WHERE receipt.originRunID = ?
                  AND receipt.conversationID = ?
                  AND receipt.toolID LIKE 'chapter.%'
                ORDER BY receipt.createdAt DESC, receipt.rowid DESC
                LIMIT 1
                """,
                arguments: [originRunID.uuidString, conversationID.uuidString]
            ), let receipt = Self.decodeToolReceipt(row),
               let logicalID = UUID(uuidString: row["boundChapterLogicalID"]) else { return nil }
            return try Self.validatedChapterToolResult(
                receipt: receipt,
                chapterLogicalID: logicalID,
                in: db
            )
        }
    }

    func latestValidatedAgentChapterToolResult(
        conversationID: UUID,
        projectID: UUID,
        chapterLogicalID: UUID
    ) throws -> ChapterToolResult? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT receipt.* FROM toolReceipt AS receipt
                JOIN chapterToolResultSnapshot AS snapshot ON snapshot.receiptID = receipt.id
                WHERE receipt.conversationID = ?
                  AND receipt.projectID = ?
                  AND snapshot.chapterLogicalID = ?
                  AND receipt.toolID LIKE 'chapter.%'
                  AND receipt.originRunID IS NOT NULL
                ORDER BY receipt.createdAt DESC, receipt.rowid DESC
                LIMIT 1
                """,
                arguments: [conversationID.uuidString, projectID.uuidString, chapterLogicalID.uuidString]
            ), let receipt = Self.decodeToolReceipt(row) else { return nil }
            return try Self.validatedChapterToolResult(
                receipt: receipt,
                chapterLogicalID: chapterLogicalID,
                in: db
            )
        }
    }

    func chapterCalibration(
        conversationID: UUID,
        projectID: UUID,
        chapterNumber: Int
    ) throws -> ChapterCalibration? {
        try queue.read { db in
            try Self.calibration(
                conversationID: conversationID,
                projectID: projectID,
                chapterNumber: chapterNumber,
                in: db
            )
        }
    }

    func countChapterVersions(projectID: UUID, chapterNumber: Int) throws -> Int {
        try queue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM chapterVersion WHERE projectID = ? AND chapterNumber = ?",
                arguments: [projectID.uuidString, chapterNumber]
            ) ?? 0
        }
    }
    private static func validatedChapterToolResult(
        receipt: ToolReceipt,
        chapterLogicalID: UUID,
        in db: Database
    ) throws -> ChapterToolResult {
        guard receipt.toolID.hasPrefix("chapter."),
              receipt.toolVersion == chapterToolVersion,
              receipt.outcome == "completed",
              let conversationID = receipt.conversationID,
              let projectID = receipt.projectID,
              let inputHash = receipt.inputHash,
              let idempotencyKey = receipt.idempotencyKey,
              !idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let replay = try replayChapterTool(
                toolID: receipt.toolID,
                inputSummary: receipt.inputSummary,
                inputHash: inputHash,
                conversationID: conversationID,
                projectID: projectID,
                idempotencyKey: idempotencyKey,
                originRunID: receipt.originRunID,
                in: db
              ),
              replay.receipt.id == receipt.id,
              replay.version.logicalID == chapterLogicalID,
              replay.calibration.chapterLogicalID == chapterLogicalID,
              receipt.inputSummary == expectedChapterInputSummary(for: replay) else {
            throw AppDatabaseError.invalidToolReceiptReference
        }
        return replay
    }

    private static func expectedChapterInputSummary(for result: ChapterToolResult) -> String? {
        switch result.receipt.toolID {
        case "chapter.generate":
            return "chapter:\(result.version.chapterNumber):generate"
        case "chapter.lockParagraph.set":
            return "chapter:\(result.version.id.uuidString):lockParagraph"
        case "chapter.reject":
            return "chapter:\(result.version.id.uuidString):reject"
        case "chapter.diagnosis.answer":
            guard let questionID = result.calibration.diagnosisEntries.last?.questionID else { return nil }
            return "chapter:\(result.version.id.uuidString):diagnosis:\(questionID)"
        case "chapter.rewrite":
            guard let parentVersionID = result.version.parentVersionID else { return nil }
            return "chapter:\(parentVersionID.uuidString):rewrite"
        case "chapter.accept":
            return "chapter:\(result.version.id.uuidString):accept"
        default:
            return nil
        }
    }

    private static func replayChapterTool(
        toolID: String,
        inputSummary: String,
        inputHash: String,
        conversationID: UUID,
        projectID: UUID,
        idempotencyKey: String,
        originRunID: UUID?,
        in db: Database
    ) throws -> ChapterToolResult? {
        guard let receiptRow = try Row.fetchOne(
            db,
            sql: "SELECT * FROM toolReceipt WHERE idempotencyKey = ? AND conversationID = ? AND projectID = ? LIMIT 1",
            arguments: [idempotencyKey, conversationID.uuidString, projectID.uuidString]
        ), let receipt = decodeToolReceipt(receiptRow) else {
            if try receipt(idempotencyKey: idempotencyKey, in: db) != nil {
                throw AppDatabaseError.idempotencyConflict
            }
            return nil
        }
        guard receipt.toolID == toolID,
              receipt.toolVersion == chapterToolVersion,
              receipt.inputSummary == inputSummary,
              receipt.inputHash == inputHash,
              receipt.outcome == "completed",
              receipt.conversationID == conversationID,
              receipt.projectID == projectID,
              receipt.originRunID == originRunID,
              let outputReference = receipt.outputReference,
              let versionID = UUID(uuidString: outputReference),
              let snapshot = try Row.fetchOne(
                db,
                sql: "SELECT * FROM chapterToolResultSnapshot WHERE receiptID = ? LIMIT 1",
                arguments: [receipt.id.uuidString]
              ) else {
            throw AppDatabaseError.idempotencyConflict
        }
        let snapshotToolID: String = snapshot["toolID"]
        let snapshotInputHash: String = snapshot["inputHash"]
        let snapshotConversationID: String = snapshot["conversationID"]
        let snapshotProjectID: String = snapshot["projectID"]
        let snapshotLogicalID: String = snapshot["chapterLogicalID"]
        let snapshotVersionID: String = snapshot["versionID"]
        let calibrationJSON: String = snapshot["calibrationJSON"]
        let calibrationHash: String = snapshot["calibrationHash"]
        guard snapshotToolID == toolID,
              snapshotInputHash == inputHash,
              snapshotConversationID == conversationID.uuidString,
              snapshotProjectID == projectID.uuidString,
              snapshotVersionID == versionID.uuidString,
              ChapterFingerprint.calibrationSnapshotHash(Data(calibrationJSON.utf8)) == calibrationHash,
              let logicalID = UUID(uuidString: snapshotLogicalID),
              let version = try version(
                id: versionID,
                conversationID: conversationID,
                projectID: projectID,
                logicalID: logicalID,
                in: db
              ) else {
            throw AppDatabaseError.idempotencyConflict
        }
        let calibration: ChapterCalibration = try decodeJSON(calibrationJSON)
        guard calibration.chapterLogicalID == logicalID,
              calibration.conversationID == conversationID,
              calibration.projectID == projectID,
              calibration.chapterNumber == version.chapterNumber,
              calibration.activeVersionID == version.id,
              calibration.diagnosisHash == ChapterFingerprint.diagnosisHash(calibration.diagnosisEntries),
              calibration.lockedParagraphIndexes == Array(Set(calibration.lockedParagraphIndexes)).sorted(),
              (calibration.rewriteScope == nil) == (calibration.rewriteScopeHash == nil),
              calibration.rewriteScope.map(ChapterFingerprint.rewriteScopeHash) == calibration.rewriteScopeHash else {
            throw AppDatabaseError.idempotencyConflict
        }
        if calibration.stage == .approvedFrozen {
            guard calibration.acceptedVersionID == calibration.activeVersionID else {
                throw AppDatabaseError.idempotencyConflict
            }
        } else if calibration.acceptedVersionID != nil {
            throw AppDatabaseError.idempotencyConflict
        }
        return ChapterToolResult(
            version: version, calibration: calibration,
            receipt: receipt, isReplay: true
        )
    }

    private static func requireChapterScope(
        conversationID: UUID,
        projectID: UUID,
        in db: Database
    ) throws {
        let conversationExists = try Bool.fetchOne(
            db,
            sql: "SELECT EXISTS(SELECT 1 FROM agentConversation WHERE id = ?)",
            arguments: [conversationID.uuidString]
        ) ?? false
        let projectExists = try Bool.fetchOne(
            db,
            sql: "SELECT EXISTS(SELECT 1 FROM novelProject WHERE id = ?)",
            arguments: [projectID.uuidString]
        ) ?? false
        guard conversationExists, projectExists else {
            throw AppDatabaseError.chapterBindingMismatch
        }
    }

    private static func requireApprovedOpeningPlan(
        conversationID: UUID,
        projectID: UUID,
        artifactID: UUID,
        artifactHash: String,
        in db: Database
    ) throws {
        _ = try requireExactApprovedOpeningPlan(
            conversationID: conversationID,
            projectID: projectID,
            artifactID: artifactID,
            artifactHash: artifactHash,
            in: db
        )
    }

    private static func requireActiveChapterBinding(
        conversationID: UUID,
        projectID: UUID,
        versionID: UUID,
        displayedContentHash: String,
        in db: Database
    ) throws -> (ChapterVersion, ChapterCalibration) {
        guard let version = try version(
                id: versionID,
                conversationID: conversationID,
                projectID: projectID,
                logicalID: nil,
                in: db
              ),
              version.contentHash == displayedContentHash,
              let calibration = try calibration(logicalID: version.logicalID, in: db),
              calibration.conversationID == conversationID,
              calibration.projectID == projectID,
              calibration.chapterNumber == version.chapterNumber,
              calibration.activeVersionID == version.id else {
            throw AppDatabaseError.chapterBindingMismatch
        }
        return (version, calibration)
    }

    private static func version(id: UUID, in db: Database) throws -> ChapterVersion? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM chapterVersion WHERE id = ?",
            arguments: [id.uuidString]
        ) else { return nil }
        return try decodeChapterVersion(row)
    }

    private static func version(
        id: UUID,
        conversationID: UUID,
        projectID: UUID,
        logicalID: UUID?,
        in db: Database
    ) throws -> ChapterVersion? {
        let row: Row?
        if let logicalID {
            row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM chapterVersion WHERE id = ? AND conversationID = ? AND projectID = ? AND logicalID = ?",
                arguments: [id.uuidString, conversationID.uuidString, projectID.uuidString, logicalID.uuidString]
            )
        } else {
            row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM chapterVersion WHERE id = ? AND conversationID = ? AND projectID = ?",
                arguments: [id.uuidString, conversationID.uuidString, projectID.uuidString]
            )
        }
        guard let row else { return nil }
        return try decodeChapterVersion(row)
    }

    private static func validatedLineage(
        logicalID: UUID,
        in db: Database
    ) throws -> [ChapterVersion] {
        let versions = try Row.fetchAll(
            db,
            sql: "SELECT * FROM chapterVersion WHERE logicalID = ? ORDER BY revision ASC",
            arguments: [logicalID.uuidString]
        ).map(decodeChapterVersion)
        guard !versions.isEmpty else { return [] }
        for (index, version) in versions.enumerated() {
            let expectedRevision = index + 1
            guard version.logicalID == logicalID,
                  version.revision == expectedRevision else {
                throw AppDatabaseError.invalidChapterVersion
            }
            if index == 0 {
                guard version.id == logicalID, version.parentVersionID == nil else {
                    throw AppDatabaseError.invalidChapterVersion
                }
            } else {
                let parent = versions[index - 1]
                guard version.parentVersionID == parent.id,
                      version.conversationID == parent.conversationID,
                      version.projectID == parent.projectID,
                      version.chapterNumber == parent.chapterNumber else {
                    throw AppDatabaseError.invalidChapterVersion
                }
            }
        }
        return versions
    }

    private static func calibration(
        conversationID: UUID,
        projectID: UUID,
        chapterNumber: Int,
        in db: Database
    ) throws -> ChapterCalibration? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM chapterCalibration WHERE conversationID = ? AND projectID = ? AND chapterNumber = ?",
            arguments: [conversationID.uuidString, projectID.uuidString, chapterNumber]
        ) else { return nil }
        let value = try decodeChapterCalibration(row)
        try validateCalibrationRelations(value, in: db)
        return value
    }

    private static func calibration(
        logicalID: UUID,
        in db: Database
    ) throws -> ChapterCalibration? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM chapterCalibration WHERE chapterLogicalID = ?",
            arguments: [logicalID.uuidString]
        ) else { return nil }
        let value = try decodeChapterCalibration(row)
        try validateCalibrationRelations(value, in: db)
        return value
    }

    private static func validateCalibrationRelations(
        _ calibration: ChapterCalibration,
        in db: Database
    ) throws {
        let lineage = try validatedLineage(logicalID: calibration.chapterLogicalID, in: db)
        guard let active = lineage.last,
              active.id == calibration.activeVersionID,
              active.conversationID == calibration.conversationID,
              active.projectID == calibration.projectID,
              active.chapterNumber == calibration.chapterNumber,
              calibration.lockedParagraphIndexes.allSatisfy({
                $0 >= 0 && $0 < ChapterByteExactParagraphs.split(active.body).count
              }),
              calibration.diagnosisEntries.allSatisfy({ entry in
                lineage.contains(where: {
                    $0.id == entry.versionID && $0.contentHash == entry.versionHash
                })
              }),
              calibration.rejectionHistory.allSatisfy({ entry in
                lineage.contains(where: {
                    $0.id == entry.versionID && $0.contentHash == entry.versionHash
                })
              }) else {
            throw AppDatabaseError.invalidChapterCalibration
        }
        if calibration.stage == .approvedFrozen {
            guard calibration.acceptedVersionID == active.id else {
                throw AppDatabaseError.invalidChapterCalibration
            }
        } else if calibration.acceptedVersionID != nil {
            throw AppDatabaseError.invalidChapterCalibration
        }
    }

    private static func insertChapterVersion(
        _ version: ChapterVersion,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO chapterVersion (
                id, logicalID, conversationID, projectID, chapterNumber, revision,
                parentVersionID, title, body, contentHash, creationStatus,
                evidenceReview, diffSummary, createdAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                version.id.uuidString,
                version.logicalID.uuidString,
                version.conversationID.uuidString,
                version.projectID.uuidString,
                version.chapterNumber,
                version.revision,
                version.parentVersionID?.uuidString,
                version.title,
                version.body,
                version.contentHash,
                version.creationStatus.rawValue,
                version.evidenceReview,
                version.diffSummary,
                version.createdAt.timeIntervalSince1970
            ]
        )
    }

    private static func insertChapterCalibration(
        _ calibration: ChapterCalibration,
        in db: Database
    ) throws {
        let diagnosisJSON = try encodeJSON(calibration.diagnosisEntries)
        let rejectionJSON = try encodeJSON(calibration.rejectionHistory)
        let lockedJSON = try encodeJSON(calibration.lockedParagraphIndexes)
        try db.execute(
            sql: """
            INSERT INTO chapterCalibration (
                chapterLogicalID, conversationID, projectID, chapterNumber, activeVersionID,
                stage, diagnosisEntriesJSON, diagnosisHash, rejectionHistoryJSON,
                lockedParagraphIndexesJSON, rewriteScope, rewriteScopeHash,
                acceptedVersionID, updatedAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                calibration.chapterLogicalID.uuidString,
                calibration.conversationID.uuidString,
                calibration.projectID.uuidString,
                calibration.chapterNumber,
                calibration.activeVersionID.uuidString,
                calibration.stage.rawValue,
                diagnosisJSON,
                calibration.diagnosisHash,
                rejectionJSON,
                lockedJSON,
                calibration.rewriteScope,
                calibration.rewriteScopeHash,
                calibration.acceptedVersionID?.uuidString,
                calibration.updatedAt.timeIntervalSince1970
            ]
        )
    }

    private static func updateChapterCalibration(
        _ calibration: ChapterCalibration,
        in db: Database
    ) throws {
        let diagnosisJSON = try encodeJSON(calibration.diagnosisEntries)
        let rejectionJSON = try encodeJSON(calibration.rejectionHistory)
        let lockedJSON = try encodeJSON(calibration.lockedParagraphIndexes)
        try db.execute(
            sql: """
            UPDATE chapterCalibration SET
                activeVersionID = ?, stage = ?, diagnosisEntriesJSON = ?, diagnosisHash = ?,
                rejectionHistoryJSON = ?, lockedParagraphIndexesJSON = ?, rewriteScope = ?,
                rewriteScopeHash = ?, acceptedVersionID = ?, updatedAt = ?
            WHERE chapterLogicalID = ? AND conversationID = ? AND projectID = ? AND chapterNumber = ?
            """,
            arguments: [
                calibration.activeVersionID.uuidString,
                calibration.stage.rawValue,
                diagnosisJSON,
                calibration.diagnosisHash,
                rejectionJSON,
                lockedJSON,
                calibration.rewriteScope,
                calibration.rewriteScopeHash,
                calibration.acceptedVersionID?.uuidString,
                calibration.updatedAt.timeIntervalSince1970,
                calibration.chapterLogicalID.uuidString,
                calibration.conversationID.uuidString,
                calibration.projectID.uuidString,
                calibration.chapterNumber
            ]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.invalidChapterCalibration
        }
    }

    private static func decodeChapterVersion(_ row: Row) throws -> ChapterVersion {
        let idText: String = row["id"]
        let logicalText: String = row["logicalID"]
        let conversationText: String = row["conversationID"]
        let projectText: String = row["projectID"]
        let creationStatusText: String = row["creationStatus"]
        guard let id = UUID(uuidString: idText),
              let logicalID = UUID(uuidString: logicalText),
              let conversationID = UUID(uuidString: conversationText),
              let projectID = UUID(uuidString: projectText),
              let creationStatus = ChapterVersionCreationStatus(rawValue: creationStatusText) else {
            throw AppDatabaseError.invalidChapterVersion
        }
        let parentText: String? = row["parentVersionID"]
        let version = ChapterVersion(
            id: id,
            logicalID: logicalID,
            conversationID: conversationID,
            projectID: projectID,
            chapterNumber: row["chapterNumber"],
            revision: row["revision"],
            parentVersionID: parentText.flatMap(UUID.init(uuidString:)),
            title: row["title"],
            body: row["body"],
            contentHash: row["contentHash"],
            creationStatus: creationStatus,
            evidenceReview: row["evidenceReview"],
            diffSummary: row["diffSummary"],
            createdAt: Date(timeIntervalSince1970: row["createdAt"])
        )
        let expectedHash = ChapterFingerprint.versionHash(
            id: version.id,
            logicalID: version.logicalID,
            conversationID: version.conversationID,
            projectID: version.projectID,
            chapterNumber: version.chapterNumber,
            revision: version.revision,
            parentVersionID: version.parentVersionID,
            title: version.title,
            body: version.body
        )
        guard version.chapterNumber > 0,
              version.revision > 0,
              version.contentHash == expectedHash else {
            throw AppDatabaseError.invalidChapterVersion
        }
        return version
    }
    private static func decodeChapterCalibration(_ row: Row) throws -> ChapterCalibration {
        let logicalText: String = row["chapterLogicalID"]
        let conversationText: String = row["conversationID"]
        let projectText: String = row["projectID"]
        let activeVersionText: String = row["activeVersionID"]
        let stageText: String = row["stage"]
        guard let logicalID = UUID(uuidString: logicalText),
              let conversationID = UUID(uuidString: conversationText),
              let projectID = UUID(uuidString: projectText),
              let activeVersionID = UUID(uuidString: activeVersionText),
              let stage = ChapterCalibrationStage(rawValue: stageText) else {
            throw AppDatabaseError.invalidChapterCalibration
        }
        let diagnosisJSON: String = row["diagnosisEntriesJSON"]
        let rejectionJSON: String = row["rejectionHistoryJSON"]
        let lockedJSON: String = row["lockedParagraphIndexesJSON"]
        let diagnosisEntries: [ChapterDiagnosisEntry] = try decodeJSON(diagnosisJSON)
        let rejectionHistory: [ChapterRejectionEntry] = try decodeJSON(rejectionJSON)
        let lockedParagraphIndexes: [Int] = try decodeJSON(lockedJSON)
        let acceptedText: String? = row["acceptedVersionID"]
        let rewriteScope: String? = row["rewriteScope"]
        let rewriteScopeHash: String? = row["rewriteScopeHash"]
        let diagnosisHash: String = row["diagnosisHash"]
        let calibration = ChapterCalibration(
            chapterLogicalID: logicalID,
            conversationID: conversationID,
            projectID: projectID,
            chapterNumber: row["chapterNumber"],
            activeVersionID: activeVersionID,
            stage: stage,
            diagnosisEntries: diagnosisEntries,
            diagnosisHash: diagnosisHash,
            rejectionHistory: rejectionHistory,
            lockedParagraphIndexes: lockedParagraphIndexes,
            rewriteScope: rewriteScope,
            rewriteScopeHash: rewriteScopeHash,
            acceptedVersionID: acceptedText.flatMap(UUID.init(uuidString:)),
            updatedAt: Date(timeIntervalSince1970: row["updatedAt"])
        )
        guard calibration.chapterNumber > 0,
              calibration.lockedParagraphIndexes == Array(Set(calibration.lockedParagraphIndexes)).sorted(),
              calibration.diagnosisHash == ChapterFingerprint.diagnosisHash(calibration.diagnosisEntries),
              (calibration.rewriteScope == nil) == (calibration.rewriteScopeHash == nil),
              calibration.rewriteScope.map(ChapterFingerprint.rewriteScopeHash) == calibration.rewriteScopeHash,
              (calibration.stage == .approvedFrozen) == (calibration.acceptedVersionID != nil) else {
            throw AppDatabaseError.invalidChapterCalibration
        }
        return calibration
    }

    private static func copyCalibration(
        _ calibration: ChapterCalibration,
        activeVersionID: UUID? = nil,
        stage: ChapterCalibrationStage? = nil,
        diagnosisEntries: [ChapterDiagnosisEntry]? = nil,
        diagnosisHash: String? = nil,
        rejectionHistory: [ChapterRejectionEntry]? = nil,
        lockedParagraphIndexes: [Int]? = nil,
        rewriteScope: String?? = nil,
        rewriteScopeHash: String?? = nil,
        acceptedVersionID: UUID?? = nil,
        updatedAt: Date
    ) -> ChapterCalibration {
        ChapterCalibration(
            chapterLogicalID: calibration.chapterLogicalID,
            conversationID: calibration.conversationID,
            projectID: calibration.projectID,
            chapterNumber: calibration.chapterNumber,
            activeVersionID: activeVersionID ?? calibration.activeVersionID,
            stage: stage ?? calibration.stage,
            diagnosisEntries: diagnosisEntries ?? calibration.diagnosisEntries,
            diagnosisHash: diagnosisHash ?? calibration.diagnosisHash,
            rejectionHistory: rejectionHistory ?? calibration.rejectionHistory,
            lockedParagraphIndexes: lockedParagraphIndexes ?? calibration.lockedParagraphIndexes,
            rewriteScope: rewriteScope ?? calibration.rewriteScope,
            rewriteScopeHash: rewriteScopeHash ?? calibration.rewriteScopeHash,
            acceptedVersionID: acceptedVersionID ?? calibration.acceptedVersionID,
            updatedAt: updatedAt
        )
    }

    private static func insertChapterToolResultSnapshot(
        receipt: ToolReceipt,
        version: ChapterVersion,
        calibration: ChapterCalibration,
        in db: Database
    ) throws {
        guard receipt.outputReference == version.id.uuidString,
              receipt.conversationID == version.conversationID,
              receipt.projectID == version.projectID,
              calibration.chapterLogicalID == version.logicalID,
              calibration.conversationID == version.conversationID,
              calibration.projectID == version.projectID,
              calibration.chapterNumber == version.chapterNumber,
              calibration.activeVersionID == version.id,
              let inputHash = receipt.inputHash else {
            throw AppDatabaseError.invalidToolReceiptReference
        }
        let calibrationJSON = try encodeJSON(calibration)
        try db.execute(
            sql: """
            INSERT INTO chapterToolResultSnapshot (
                receiptID, toolID, inputHash, conversationID, projectID,
                chapterLogicalID, chapterNumber, versionID,
                calibrationJSON, calibrationHash, createdAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                receipt.id.uuidString,
                receipt.toolID,
                inputHash,
                version.conversationID.uuidString,
                version.projectID.uuidString,
                version.logicalID.uuidString,
                version.chapterNumber,
                version.id.uuidString,
                calibrationJSON,
                ChapterFingerprint.calibrationSnapshotHash(Data(calibrationJSON.utf8)),
                receipt.createdAt.timeIntervalSince1970
            ]
        )
    }

    private static func makeChapterReceipt(
        toolID: String,
        inputSummary: String,
        inputHash: String,
        conversationID: UUID,
        projectID: UUID,
        idempotencyKey: String,
        originRunID: UUID?,
        outputVersionID: UUID,
        now: Date
    ) -> ToolReceipt {
        ToolReceipt(
            id: UUID(),
            toolID: toolID,
            toolVersion: chapterToolVersion,
            inputSummary: inputSummary,
            inputHash: inputHash,
            outcome: "completed",
            conversationID: conversationID,
            projectID: projectID,
            originRunID: originRunID,
            idempotencyKey: idempotencyKey,
            outputReference: outputVersionID.uuidString,
            createdAt: now
        )
    }

    private static func encodeJSON<Value: Encodable>(_ value: Value) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AppDatabaseError.invalidChapterCalibration
        }
        return json
    }

    private static func decodeJSON<Value: Decodable>(_ json: String) throws -> Value {
        guard let data = json.data(using: .utf8) else {
            throw AppDatabaseError.invalidChapterCalibration
        }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw AppDatabaseError.invalidChapterCalibration
        }
    }

    private static func chapterDiffSummary(
        originalBody: String,
        revisedBody: String
    ) -> String {
        let original = ChapterByteExactParagraphs.split(originalBody)
        let revised = ChapterByteExactParagraphs.split(revisedBody)
        let count = max(original.count, revised.count)
        let changed = (0..<count).filter { index in
            guard index < original.count, index < revised.count else { return true }
            return original[index] != revised[index]
        }
        return "changedParagraphIndexes=" + changed.map(String.init).joined(separator: ",")
    }
}
