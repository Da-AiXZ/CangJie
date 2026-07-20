import Foundation
import Testing
@testable import CangJieCore

struct S1DraftAutosaveContractTests {
    @Test
    func newerGenerationSupersedesEarlierDraftContent() {
        let conversationID = UUID()
        let first = S1DraftAutosaveContract.makeRequest(
            content: "a",
            selectedConversationID: conversationID,
            after: 0
        )
        let latest = S1DraftAutosaveContract.makeRequest(
            content: "abc",
            selectedConversationID: conversationID,
            after: first.generation
        )

        #expect(!S1DraftAutosaveContract.canPersist(
            first,
            currentContent: latest.content,
            currentSelectedConversationID: conversationID,
            currentGeneration: latest.generation,
            lifecyclePermitsMutations: true,
            buildIsActive: true
        ))
        #expect(S1DraftAutosaveContract.canPersist(
            latest,
            currentContent: latest.content,
            currentSelectedConversationID: conversationID,
            currentGeneration: latest.generation,
            lifecyclePermitsMutations: true,
            buildIsActive: true
        ))
    }

    @Test
    func conversationScopeChangeInvalidatesDelayedRequest() {
        let firstConversationID = UUID()
        let secondConversationID = UUID()
        let request = S1DraftAutosaveContract.makeRequest(
            content: "first conversation draft",
            selectedConversationID: firstConversationID,
            after: 41
        )

        #expect(!S1DraftAutosaveContract.canPersist(
            request,
            currentContent: request.content,
            currentSelectedConversationID: secondConversationID,
            currentGeneration: request.generation,
            lifecyclePermitsMutations: true,
            buildIsActive: true
        ))
        #expect(!S1DraftAutosaveContract.canPersist(
            request,
            currentContent: request.content,
            currentSelectedConversationID: nil,
            currentGeneration: request.generation,
            lifecyclePermitsMutations: true,
            buildIsActive: true
        ))
    }

    @Test
    func workspaceReplacementInvalidatesSameScopeRequest() {
        let conversationID = UUID()
        let request = S1DraftAutosaveContract.makeRequest(
            content: "stale draft",
            selectedConversationID: conversationID,
            after: 9
        )

        #expect(!S1DraftAutosaveContract.canPersist(
            request,
            currentContent: "restored draft",
            currentSelectedConversationID: conversationID,
            currentGeneration: request.generation,
            lifecyclePermitsMutations: true,
            buildIsActive: true
        ))
    }

    @Test
    func lifecycleAndBuildGatesAreBothRequiredAtCommitTime() {
        let request = S1DraftAutosaveContract.makeRequest(
            content: "latest draft",
            selectedConversationID: nil,
            after: 7
        )

        #expect(!S1DraftAutosaveContract.canPersist(
            request,
            currentContent: request.content,
            currentSelectedConversationID: nil,
            currentGeneration: request.generation,
            lifecyclePermitsMutations: false,
            buildIsActive: true
        ))
        #expect(!S1DraftAutosaveContract.canPersist(
            request,
            currentContent: request.content,
            currentSelectedConversationID: nil,
            currentGeneration: request.generation,
            lifecyclePermitsMutations: true,
            buildIsActive: false
        ))
    }

    @Test
    func generationAdvancesAcrossUnsignedOverflowWithoutReusingCurrentGeneration() {
        let request = S1DraftAutosaveContract.makeRequest(
            content: "overflow safe",
            selectedConversationID: nil,
            after: UInt64.max
        )

        #expect(request.generation == 0)
        #expect(request.generation != UInt64.max)
    }
}