import Testing
@testable import CangJieCore

struct S1NovelProgressProjectionTests {
    @Test
    func savedIdeaWithoutAvailableChapterUsesHonestStartingCopy() {
        let facts = S1NovelProgressFacts(
            hasSavedStoryIdea: true,
            latestAvailableChapterNumber: nil,
            awaitingReviewChapterNumber: nil,
            editingChapterNumber: nil
        )

        #expect(S1NovelProgressProjection.description(for: facts) == "刚保存了故事念头，还没有开始正文")
    }

    @Test
    func missingFactsFailClosedWithoutInventingProgress() {
        let facts = S1NovelProgressFacts(
            hasSavedStoryIdea: false,
            latestAvailableChapterNumber: nil,
            awaitingReviewChapterNumber: nil,
            editingChapterNumber: nil
        )

        #expect(S1NovelProgressProjection.description(for: facts) == "这本书暂时没有正文")
    }

    @Test
    func latestAvailableChapterProducesWrittenThroughProgress() {
        let facts = S1NovelProgressFacts(
            hasSavedStoryIdea: true,
            latestAvailableChapterNumber: 12,
            awaitingReviewChapterNumber: nil,
            editingChapterNumber: nil
        )

        #expect(S1NovelProgressProjection.description(for: facts) == "已经写到第 12 章")
    }

    @Test
    func firstChapterWaitingForReviewUsesNaturalFirstChapterCopy() {
        let facts = S1NovelProgressFacts(
            hasSavedStoryIdea: true,
            latestAvailableChapterNumber: 1,
            awaitingReviewChapterNumber: 1,
            editingChapterNumber: nil
        )

        #expect(S1NovelProgressProjection.description(for: facts) == "第一章等你看看")
    }

    @Test
    func laterChapterWaitingForReviewUsesNumberedCopy() {
        let facts = S1NovelProgressFacts(
            hasSavedStoryIdea: true,
            latestAvailableChapterNumber: 8,
            awaitingReviewChapterNumber: 6,
            editingChapterNumber: nil
        )

        #expect(S1NovelProgressProjection.description(for: facts) == "第 6 章等你看看")
    }

    @Test
    func editingTakesPriorityOverWaitingAndGeneralWrittenProgress() {
        let facts = S1NovelProgressFacts(
            hasSavedStoryIdea: true,
            latestAvailableChapterNumber: 12,
            awaitingReviewChapterNumber: 7,
            editingChapterNumber: 3
        )

        #expect(S1NovelProgressProjection.description(for: facts) == "正在修改第 3 章")
    }

    @Test
    func waitingForReviewTakesPriorityOverGeneralWrittenProgress() {
        let facts = S1NovelProgressFacts(
            hasSavedStoryIdea: true,
            latestAvailableChapterNumber: 12,
            awaitingReviewChapterNumber: 7,
            editingChapterNumber: nil
        )

        #expect(S1NovelProgressProjection.description(for: facts) == "第 7 章等你看看")
    }

    @Test
    func invalidStatusChapterNumbersAreIgnoredInsteadOfInvented() {
        let facts = S1NovelProgressFacts(
            hasSavedStoryIdea: true,
            latestAvailableChapterNumber: 12,
            awaitingReviewChapterNumber: 13,
            editingChapterNumber: 0
        )

        #expect(S1NovelProgressProjection.description(for: facts) == "已经写到第 12 章")
    }

    @Test
    func invalidLatestChapterMakesDependentStatusesUntrusted() {
        let savedIdeaFacts = S1NovelProgressFacts(
            hasSavedStoryIdea: true,
            latestAvailableChapterNumber: -1,
            awaitingReviewChapterNumber: 1,
            editingChapterNumber: 1
        )
        let emptyFacts = S1NovelProgressFacts(
            hasSavedStoryIdea: false,
            latestAvailableChapterNumber: 0,
            awaitingReviewChapterNumber: 1,
            editingChapterNumber: 1
        )

        #expect(S1NovelProgressProjection.description(for: savedIdeaFacts) == "刚保存了故事念头，还没有开始正文")
        #expect(S1NovelProgressProjection.description(for: emptyFacts) == "这本书暂时没有正文")
    }

    @Test
    func everyProjectionAvoidsEngineeringVocabulary() {
        let factMatrix = [
            S1NovelProgressFacts(hasSavedStoryIdea: false, latestAvailableChapterNumber: nil, awaitingReviewChapterNumber: nil, editingChapterNumber: nil),
            S1NovelProgressFacts(hasSavedStoryIdea: true, latestAvailableChapterNumber: nil, awaitingReviewChapterNumber: nil, editingChapterNumber: nil),
            S1NovelProgressFacts(hasSavedStoryIdea: true, latestAvailableChapterNumber: 12, awaitingReviewChapterNumber: nil, editingChapterNumber: nil),
            S1NovelProgressFacts(hasSavedStoryIdea: true, latestAvailableChapterNumber: 12, awaitingReviewChapterNumber: 1, editingChapterNumber: nil),
            S1NovelProgressFacts(hasSavedStoryIdea: true, latestAvailableChapterNumber: 12, awaitingReviewChapterNumber: 1, editingChapterNumber: 3)
        ]
        let forbiddenTerms = ["stage", "hash", "revision", "receipt", "binding"]

        for facts in factMatrix {
            let description = S1NovelProgressProjection.description(for: facts)
            #expect(!description.isEmpty)
            for term in forbiddenTerms {
                #expect(!description.localizedCaseInsensitiveContains(term))
            }
        }
    }
}
