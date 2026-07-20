import Foundation

public enum S1DraftAutosaveContract {
    public struct Request: Equatable, Sendable {
        public let content: String
        public let selectedConversationID: UUID?
        public let generation: UInt64

        public init(
            content: String,
            selectedConversationID: UUID?,
            generation: UInt64
        ) {
            self.content = content
            self.selectedConversationID = selectedConversationID
            self.generation = generation
        }
    }

    public static func makeRequest(
        content: String,
        selectedConversationID: UUID?,
        after generation: UInt64
    ) -> Request {
        Request(
            content: content,
            selectedConversationID: selectedConversationID,
            generation: generation &+ 1
        )
    }

    public static func canPersist(
        _ request: Request,
        currentContent: String,
        currentSelectedConversationID: UUID?,
        currentGeneration: UInt64,
        lifecyclePermitsMutations: Bool,
        buildIsActive: Bool
    ) -> Bool {
        lifecyclePermitsMutations
            && buildIsActive
            && request.generation == currentGeneration
            && request.selectedConversationID == currentSelectedConversationID
            && request.content == currentContent
    }
}