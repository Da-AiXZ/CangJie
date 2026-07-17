import CangJieCore
import CryptoKit
import Foundation

enum ChapterVersionCreationStatus: String, Codable, Equatable {
    case calibrationReview
}

struct ChapterVersion: Identifiable, Equatable {
    let id: UUID
    let logicalID: UUID
    let conversationID: UUID
    let projectID: UUID
    let chapterNumber: Int
    let revision: Int
    let parentVersionID: UUID?
    let title: String
    let body: String
    let contentHash: String
    let creationStatus: ChapterVersionCreationStatus
    let evidenceReview: String
    let diffSummary: String?
    let createdAt: Date
}

struct ChapterDiagnosisEntry: Codable, Equatable {
    let versionID: UUID
    let versionHash: String
    let questionID: String
    let question: String
    let answer: String
    let createdAt: Date
}

struct ChapterRejectionEntry: Codable, Equatable {
    let versionID: UUID
    let versionHash: String
    let reason: String
    let createdAt: Date
}

struct ChapterCalibration: Codable, Equatable {
    let chapterLogicalID: UUID
    let conversationID: UUID
    let projectID: UUID
    let chapterNumber: Int
    let activeVersionID: UUID
    let stage: ChapterCalibrationStage
    let diagnosisEntries: [ChapterDiagnosisEntry]
    let diagnosisHash: String
    let rejectionHistory: [ChapterRejectionEntry]
    let lockedParagraphIndexes: [Int]
    let rewriteScope: String?
    let rewriteScopeHash: String?
    let acceptedVersionID: UUID?
    let updatedAt: Date
}

extension ChapterCalibration {
    func isAuditEquivalent(to other: ChapterCalibration) -> Bool {
        chapterLogicalID == other.chapterLogicalID
            && conversationID == other.conversationID
            && projectID == other.projectID
            && chapterNumber == other.chapterNumber
            && activeVersionID == other.activeVersionID
            && stage == other.stage
            && diagnosisEntries == other.diagnosisEntries
            && diagnosisHash == other.diagnosisHash
            && rejectionHistory == other.rejectionHistory
            && lockedParagraphIndexes == other.lockedParagraphIndexes
            && rewriteScope == other.rewriteScope
            && rewriteScopeHash == other.rewriteScopeHash
            && acceptedVersionID == other.acceptedVersionID
            && Self.auditTimestampsMatch(updatedAt, other.updatedAt)
    }

    private static func auditTimestampsMatch(_ lhs: Date, _ rhs: Date) -> Bool {
        let left = lhs.timeIntervalSinceReferenceDate
        let right = rhs.timeIntervalSinceReferenceDate
        return left == right || left.nextUp == right || left.nextDown == right
    }
}

struct ChapterToolResult: Equatable {
    let version: ChapterVersion
    let calibration: ChapterCalibration
    let receipt: ToolReceipt
    let isReplay: Bool
}


enum ChapterDiagnosisProtocol {
    static let orderedQuestionIDs = ["root-cause", "must-preserve", "chapter-end"]
    static let orderedQuestions = [
        "这一章最根本的不对味是什么？请指出最影响阅读体验的一处，而不是只说“不好看”。",
        "除了已经锁定的段落，还有哪些人物效果、信息或情绪必须保留？",
        "重写后，读者在章末必须产生什么具体情绪或下一步期待？"
    ]

    static func expectedQuestionID(answerCount: Int) -> String? {
        guard orderedQuestionIDs.indices.contains(answerCount) else { return nil }
        return orderedQuestionIDs[answerCount]
    }

    static func expectedQuestion(answerCount: Int) -> String? {
        guard orderedQuestions.indices.contains(answerCount) else { return nil }
        return orderedQuestions[answerCount]
    }
}

enum ChapterInputLimits {
    static let titleUTF8Bytes = 512
    static let bodyUTF8Bytes = 1_048_576
    static let evidenceUTF8Bytes = 131_072
    static let rejectionUTF8Bytes = 32_768
    static let questionUTF8Bytes = 16_384
    static let answerUTF8Bytes = 65_536
    static let rewriteScopeUTF8Bytes = 65_536
    static let questionIDUTF8Bytes = 128
    static let hashUTF8Bytes = 128
    static let idempotencyKeyUTF8Bytes = 512
    static let maximumParagraphs = 10_000
    static let maximumParagraphUTF8Bytes = 262_144
    static let maximumLockedParagraphIndexes = 2_000

    static func require(_ value: String, field: String, maximumUTF8Bytes: Int) throws {
        guard value.utf8.count < maximumUTF8Bytes else {
            throw AppDatabaseError.chapterInputLimitExceeded(field: field)
        }
    }

    static func requireNonBlank(_ value: String, field: String, maximumUTF8Bytes: Int) throws {
        try require(value, field: field, maximumUTF8Bytes: maximumUTF8Bytes)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppDatabaseError.chapterInputLimitExceeded(field: field)
        }
    }

    static func requireCommonBinding(
        displayedHash: String,
        idempotencyKey: String
    ) throws {
        try requireNonBlank(displayedHash, field: "displayedHash", maximumUTF8Bytes: hashUTF8Bytes)
        try requireNonBlank(idempotencyKey, field: "idempotencyKey", maximumUTF8Bytes: idempotencyKeyUTF8Bytes)
    }

    static func requireBody(_ body: String) throws {
        try require(body, field: "body", maximumUTF8Bytes: bodyUTF8Bytes)
        let paragraphs = ChapterByteExactParagraphs.split(body)
        guard paragraphs.count <= maximumParagraphs else {
            throw AppDatabaseError.chapterInputLimitExceeded(field: "paragraphCount")
        }
        guard paragraphs.allSatisfy({ $0.count < maximumParagraphUTF8Bytes }) else {
            throw AppDatabaseError.chapterInputLimitExceeded(field: "paragraph")
        }
    }

    static func requireLockedIndexes(_ indexes: [Int]) throws {
        guard indexes.count <= maximumLockedParagraphIndexes else {
            throw AppDatabaseError.chapterInputLimitExceeded(field: "lockedParagraphIndexes")
        }
        guard indexes.allSatisfy({ $0 >= 0 && $0 < maximumParagraphs }) else {
            throw AppDatabaseError.chapterInputLimitExceeded(field: "lockedParagraphIndexes")
        }
    }
}

enum ChapterFingerprint {
    static func versionHash(
        id: UUID,
        logicalID: UUID,
        conversationID: UUID,
        projectID: UUID,
        chapterNumber: Int,
        revision: Int,
        parentVersionID: UUID?,
        title: String,
        body: String
    ) -> String {
        digest(fields: [
            "chapter-version-v1",
            id.uuidString,
            logicalID.uuidString,
            conversationID.uuidString,
            projectID.uuidString,
            String(chapterNumber),
            String(revision),
            parentVersionID?.uuidString ?? "",
            title,
            body
        ])
    }

    static func diagnosisHash(_ entries: [ChapterDiagnosisEntry]) -> String {
        let fields = entries.flatMap {
            [
                $0.versionID.uuidString,
                $0.versionHash,
                $0.questionID,
                $0.question,
                $0.answer,
                String($0.createdAt.timeIntervalSince1970.bitPattern)
            ]
        }
        return digest(fields: ["chapter-diagnosis-v1"] + fields)
    }

    static func rewriteScopeHash(_ scope: String) -> String {
        digest(fields: ["chapter-rewrite-scope-v1", scope])
    }

    static func calibrationSnapshotHash(_ json: Data) -> String {
        digest(fields: ["chapter-calibration-snapshot-v1", json.base64EncodedString()])
    }

    static func inputHash(toolID: String, fields: [String]) -> String {
        digest(fields: ["chapter-tool-input-v1", toolID] + fields)
    }

    static func lockedParagraphBinding(body: String, indexes: [Int]) throws -> String {
        let paragraphs = ChapterByteExactParagraphs.split(body)
        let canonical = Array(Set(indexes)).sorted()
        var fields = ["chapter-locked-paragraphs-v1"]
        for index in canonical {
            guard index >= 0, index < paragraphs.count else {
                throw AppDatabaseError.invalidChapterParagraphIndex(index)
            }
            fields.append(String(index))
            fields.append(paragraphs[index].base64EncodedString())
        }
        return digest(fields: fields)
    }

    private static func digest(fields: [String]) -> String {
        var data = Data()
        for field in fields {
            let bytes = Data(field.utf8)
            data.append(Data(String(bytes.count).utf8))
            data.append(0x3A)
            data.append(bytes)
            data.append(0x7C)
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum ChapterByteExactParagraphs {
    static func split(_ body: String) -> [Data] {
        ChapterContentIntegrity.protectedParagraphBytes(in: body).map { Data($0) }
    }

    static func validateLockedParagraphs(
        originalBody: String,
        revisedBody: String,
        indexes: [Int]
    ) throws {
        do {
            try ChapterContentIntegrity.validateLockedParagraphs(
                originalBody: originalBody,
                revisedBody: revisedBody,
                lockedParagraphIndexes: indexes
            )
        } catch let error as ChapterCalibrationError {
            switch error {
            case let .invalidLockedParagraphIndex(index):
                throw AppDatabaseError.invalidChapterParagraphIndex(index)
            case let .lockedContentChanged(index):
                throw AppDatabaseError.chapterLockedContentChanged(index: index)
            case .invalidTransition:
                throw AppDatabaseError.invalidChapterCalibration
            }
        }
    }
}
