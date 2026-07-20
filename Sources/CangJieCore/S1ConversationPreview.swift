import Foundation

public enum S1ConversationPreviewError: Error, Equatable, Sendable {
    case emptyInput
    case inputTooLarge
    case unsafeDirectionalControl
}

public enum S1ConversationSpeaker: Sendable {
    case user
    case assistant
    case system
}

public struct S1ConversationPreviewTurn: Equatable, Sendable {
    public let userText: String
    public let systemReceipt: String
}

public enum S1ConversationPreview {
    public static let maximumInputUTF8Bytes = 32_768
    public static let maximumDraftUTF8Bytes = 65_536
    public static let maximumHistoryTitleCharacters = 32
    public static let systemReceipt =
        "界面预览版：这句话已保存。当前只验证界面和导航，真正的模型对话从 S2 接入。"

    public static func displayText(speaker: S1ConversationSpeaker, content: String) -> String {
        let prefix: String
        switch speaker {
        case .user:
            prefix = "你："
        case .assistant:
            prefix = "仓颉："
        case .system:
            prefix = ""
        }

        var rendered = prefix
        for character in content {
            rendered.append(character)
            if character.unicodeScalars.allSatisfy(CharacterSet.newlines.contains) {
                rendered.append("  ")
            }
        }
        return rendered
    }

    public static func makeTurn(from rawInput: String) throws -> S1ConversationPreviewTurn {
        let userText = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else {
            throw S1ConversationPreviewError.emptyInput
        }
        guard userText.utf8.count <= maximumInputUTF8Bytes else {
            throw S1ConversationPreviewError.inputTooLarge
        }
        guard !containsUnsafeDirectionalControl(userText) else {
            throw S1ConversationPreviewError.unsafeDirectionalControl
        }
        return S1ConversationPreviewTurn(
            userText: userText,
            systemReceipt: systemReceipt
        )
    }

    public static func makeHistoryTitle(fromValidatedUserText userText: String) -> String {
        let singleLineText = userText
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        let safeTitle = removingLeadingRoleLabels(from: singleLineText)
        guard !safeTitle.isEmpty else {
            return "新对话"
        }
        guard safeTitle.count > maximumHistoryTitleCharacters else {
            return safeTitle
        }

        return String(safeTitle.prefix(maximumHistoryTitleCharacters - 1)) + "…"
    }

    private static let disallowedHistoryRoleLabels: Set<String> = [
        "agent",
        "assistant",
        "developer",
        "model",
        "system",
        "tool",
        "user",
        "仓颉",
        "助手",
        "开发者",
        "模型",
        "系统",
        "工具",
        "用户"
    ]

    private static func removingLeadingRoleLabels(from text: String) -> String {
        var candidate = text

        while let colonIndex = candidate.firstIndex(where: { $0 == ":" || $0 == "：" }) {
            let possibleRole = candidate[..<colonIndex]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            guard disallowedHistoryRoleLabels.contains(possibleRole) else {
                break
            }

            candidate = candidate[candidate.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespaces)
        }

        return candidate
    }

    private static func containsUnsafeDirectionalControl(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x061C, 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x2069:
                return true
            default:
                return false
            }
        }
    }
}
