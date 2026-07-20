import Foundation

public enum S1WorkspaceLayoutMode: String, CaseIterable, Hashable, Sendable {
    case landscapeColumns
    case portraitSingleFocus
}

public enum S1WorkspacePrimaryFocus: String, CaseIterable, Hashable, Sendable {
    case reader
    case conversation
    case results
}

public struct S1WorkspaceLayoutProjection: Equatable, Hashable, Sendable {
    public let showsPersistentActivityBar: Bool
    public let showsPersistentConversationRail: Bool
    public let usesSinglePrimaryFocus: Bool
    public let opensIndependentPagesAsOverlay: Bool

    public init(
        showsPersistentActivityBar: Bool,
        showsPersistentConversationRail: Bool,
        usesSinglePrimaryFocus: Bool,
        opensIndependentPagesAsOverlay: Bool
    ) {
        self.showsPersistentActivityBar = showsPersistentActivityBar
        self.showsPersistentConversationRail = showsPersistentConversationRail
        self.usesSinglePrimaryFocus = usesSinglePrimaryFocus
        self.opensIndependentPagesAsOverlay = opensIndependentPagesAsOverlay
    }
}

public struct S1ReadableWorkspaceWidthProjection: Equatable, Hashable, Sendable {
    public let readerWidth: Double
    public let companionWidth: Double

    public init(readerWidth: Double, companionWidth: Double) {
        self.readerWidth = readerWidth
        self.companionWidth = companionWidth
    }
}

public enum S1WorkspaceLayoutContract {
    public static let minimumColumnWidth = 1024.0

    public static func mode(width: Double, height: Double) -> S1WorkspaceLayoutMode {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return .portraitSingleFocus
        }

        return width >= height && width >= minimumColumnWidth
            ? .landscapeColumns
            : .portraitSingleFocus
    }

    public static func readableWorkspaceWidths(
        availableWidth: Double,
        dividerWidth: Double
    ) -> S1ReadableWorkspaceWidthProjection? {
        guard availableWidth.isFinite,
              dividerWidth.isFinite,
              availableWidth > 0,
              dividerWidth > 0,
              availableWidth > dividerWidth else {
            return nil
        }

        let contentWidth = availableWidth - dividerWidth
        let companionWidth = contentWidth * 0.34
        let readerWidth = contentWidth - companionWidth
        guard readerWidth.isFinite,
              companionWidth.isFinite,
              readerWidth > 0,
              companionWidth > 0 else {
            return nil
        }

        return S1ReadableWorkspaceWidthProjection(
            readerWidth: readerWidth,
            companionWidth: companionWidth
        )
    }

    public static func projection(for mode: S1WorkspaceLayoutMode) -> S1WorkspaceLayoutProjection {
        switch mode {
        case .landscapeColumns:
            return S1WorkspaceLayoutProjection(
                showsPersistentActivityBar: true,
                showsPersistentConversationRail: true,
                usesSinglePrimaryFocus: false,
                opensIndependentPagesAsOverlay: true
            )
        case .portraitSingleFocus:
            return S1WorkspaceLayoutProjection(
                showsPersistentActivityBar: false,
                showsPersistentConversationRail: false,
                usesSinglePrimaryFocus: true,
                opensIndependentPagesAsOverlay: true
            )
        }
    }

    public static func availableFocuses(hasReadableContent: Bool) -> [S1WorkspacePrimaryFocus] {
        hasReadableContent
            ? [.reader, .conversation, .results]
            : [.conversation, .results]
    }

    public static func normalizedFocus(
        _ focus: S1WorkspacePrimaryFocus,
        hasReadableContent: Bool
    ) -> S1WorkspacePrimaryFocus {
        availableFocuses(hasReadableContent: hasReadableContent).contains(focus)
            ? focus
            : .conversation
    }
}
