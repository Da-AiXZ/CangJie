import Foundation

public enum ChapterCalibrationStage: String, Codable, Equatable, Sendable {
    case notStarted
    case reviewingV1
    case diagnosing
    case awaitingRewriteConfirmation
    case rewriting
    case reviewingV2
    case approvedFrozen
}

public enum ChapterCalibrationAction: String, Codable, Equatable, Sendable {
    case generateV1
    case reject
    case completeDiagnosis
    case confirmRewrite
    case presentV2
    case accept
}

public enum ChapterCalibrationError: Error, Equatable, Sendable {
    case invalidTransition(from: ChapterCalibrationStage, action: ChapterCalibrationAction)
    case invalidLockedParagraphIndex(Int)
    case lockedContentChanged(index: Int)
}

public struct ChapterCalibrationMachine: Equatable, Sendable {
    public let stage: ChapterCalibrationStage

    public init(stage: ChapterCalibrationStage) {
        self.stage = stage
    }

    public func applying(_ action: ChapterCalibrationAction) throws -> ChapterCalibrationMachine {
        let next: ChapterCalibrationStage
        switch (stage, action) {
        case (.notStarted, .generateV1):
            next = .reviewingV1
        case (.reviewingV1, .reject):
            next = .diagnosing
        case (.diagnosing, .completeDiagnosis):
            next = .awaitingRewriteConfirmation
        case (.awaitingRewriteConfirmation, .confirmRewrite):
            next = .rewriting
        case (.rewriting, .presentV2):
            next = .reviewingV2
        case (.reviewingV1, .accept), (.reviewingV2, .accept):
            next = .approvedFrozen
        default:
            throw ChapterCalibrationError.invalidTransition(from: stage, action: action)
        }
        return ChapterCalibrationMachine(stage: next)
    }
}

public struct ChapterParagraphDiff: Equatable, Sendable {
    public let changedParagraphIndexes: [Int]
    public let unchangedParagraphIndexes: [Int]

    public init(changedParagraphIndexes: [Int], unchangedParagraphIndexes: [Int]) {
        self.changedParagraphIndexes = changedParagraphIndexes
        self.unchangedParagraphIndexes = unchangedParagraphIndexes
    }
}

public enum ChapterContentIntegrity {
    private struct ParagraphSegment {
        let content: String
        let protectedBytes: [UInt8]
    }

    public static func paragraphs(in body: String) -> [String] {
        segments(in: body).map(\.content)
    }

    public static func protectedParagraphBytes(in body: String) -> [[UInt8]] {
        segments(in: body).map(\.protectedBytes)
    }

    private static func segments(in body: String) -> [ParagraphSegment] {
        let bytes = Array(body.utf8)
        guard !bytes.isEmpty else { return [] }

        var result: [ParagraphSegment] = []
        var paragraphStart = 0
        var cursor = 0

        while cursor < bytes.count {
            let firstBreakLength = lineBreakLength(in: bytes, at: cursor)
            guard firstBreakLength > 0 else {
                cursor += 1
                continue
            }

            var separatorEnd = cursor + firstBreakLength
            let secondBreakLength = lineBreakLength(in: bytes, at: separatorEnd)
            guard secondBreakLength > 0 else {
                cursor = separatorEnd
                continue
            }

            separatorEnd += secondBreakLength
            while true {
                let additionalBreakLength = lineBreakLength(in: bytes, at: separatorEnd)
                guard additionalBreakLength > 0 else { break }
                separatorEnd += additionalBreakLength
            }
            appendSegment(
                contentBytes: bytes[paragraphStart..<cursor],
                protectedBytes: bytes[paragraphStart..<separatorEnd],
                to: &result
            )
            paragraphStart = separatorEnd
            cursor = separatorEnd
        }

        appendSegment(
            contentBytes: bytes[paragraphStart..<bytes.count],
            protectedBytes: bytes[paragraphStart..<bytes.count],
            to: &result
        )
        return result
    }

    private static func lineBreakLength(in bytes: [UInt8], at index: Int) -> Int {
        guard index < bytes.count else { return 0 }
        if bytes[index] == 0x0A { return 1 }
        if bytes[index] == 0x0D {
            return index + 1 < bytes.count && bytes[index + 1] == 0x0A ? 2 : 1
        }
        return 0
    }

    private static func appendSegment(
        contentBytes: ArraySlice<UInt8>,
        protectedBytes: ArraySlice<UInt8>,
        to result: inout [ParagraphSegment]
    ) {
        guard !contentBytes.isEmpty else { return }
        result.append(
            ParagraphSegment(
                content: String(decoding: contentBytes, as: UTF8.self),
                protectedBytes: Array(protectedBytes)
            )
        )
    }

    public static func rewritingParagraphs(
        in body: String,
        transform: (_ index: Int, _ paragraph: String) -> String
    ) -> String {
        let bytes = Array(body.utf8)
        guard !bytes.isEmpty else { return body }

        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var paragraphStart = 0
        var cursor = 0
        var paragraphIndex = 0

        while cursor < bytes.count {
            let firstBreakLength = lineBreakLength(in: bytes, at: cursor)
            guard firstBreakLength > 0 else {
                cursor += 1
                continue
            }

            var separatorEnd = cursor + firstBreakLength
            let secondBreakLength = lineBreakLength(in: bytes, at: separatorEnd)
            guard secondBreakLength > 0 else {
                cursor = separatorEnd
                continue
            }

            separatorEnd += secondBreakLength
            while true {
                let additionalBreakLength = lineBreakLength(in: bytes, at: separatorEnd)
                guard additionalBreakLength > 0 else { break }
                separatorEnd += additionalBreakLength
            }

            let contentBytes = bytes[paragraphStart..<cursor]
            if contentBytes.isEmpty {
                output.append(contentsOf: bytes[paragraphStart..<separatorEnd])
            } else {
                let paragraph = String(decoding: contentBytes, as: UTF8.self)
                output.append(contentsOf: transform(paragraphIndex, paragraph).utf8)
                output.append(contentsOf: bytes[cursor..<separatorEnd])
                paragraphIndex += 1
            }
            paragraphStart = separatorEnd
            cursor = separatorEnd
        }

        let trailingBytes = bytes[paragraphStart..<bytes.count]
        if !trailingBytes.isEmpty {
            let paragraph = String(decoding: trailingBytes, as: UTF8.self)
            output.append(contentsOf: transform(paragraphIndex, paragraph).utf8)
        }
        return String(decoding: output, as: UTF8.self)
    }

    public static func validateLockedParagraphs(
        originalBody: String,
        revisedBody: String,
        lockedParagraphIndexes: [Int]
    ) throws {
        let original = segments(in: originalBody)
        let revised = segments(in: revisedBody)
        for index in Array(Set(lockedParagraphIndexes)).sorted() {
            guard index >= 0, index < original.count, index < revised.count else {
                throw ChapterCalibrationError.invalidLockedParagraphIndex(index)
            }
            guard original[index].protectedBytes == revised[index].protectedBytes else {
                throw ChapterCalibrationError.lockedContentChanged(index: index)
            }
        }
    }

    public static func diff(originalBody: String, revisedBody: String) -> ChapterParagraphDiff {
        let original = segments(in: originalBody)
        let revised = segments(in: revisedBody)
        let count = max(original.count, revised.count)
        var changed: [Int] = []
        var unchanged: [Int] = []
        for index in 0..<count {
            if index < original.count,
               index < revised.count,
               original[index].content == revised[index].content {
                unchanged.append(index)
            } else {
                changed.append(index)
            }
        }
        return ChapterParagraphDiff(
            changedParagraphIndexes: changed,
            unchangedParagraphIndexes: unchanged
        )
    }
}
