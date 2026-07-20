public struct S1NovelProgressFacts: Equatable, Sendable {
    public let hasSavedStoryIdea: Bool
    public let latestAvailableChapterNumber: Int?
    public let awaitingReviewChapterNumber: Int?
    public let editingChapterNumber: Int?

    public init(
        hasSavedStoryIdea: Bool,
        latestAvailableChapterNumber: Int?,
        awaitingReviewChapterNumber: Int?,
        editingChapterNumber: Int?
    ) {
        self.hasSavedStoryIdea = hasSavedStoryIdea
        self.latestAvailableChapterNumber = latestAvailableChapterNumber
        self.awaitingReviewChapterNumber = awaitingReviewChapterNumber
        self.editingChapterNumber = editingChapterNumber
    }
}

public enum S1NovelProgressProjection {
    public static func description(for facts: S1NovelProgressFacts) -> String {
        guard let latestChapterNumber = positive(facts.latestAvailableChapterNumber) else {
            return facts.hasSavedStoryIdea
                ? "刚保存了故事念头，还没有开始正文"
                : "这本书暂时没有正文"
        }

        if let editingChapterNumber = trustedStatusChapter(
            facts.editingChapterNumber,
            latestChapterNumber: latestChapterNumber
        ) {
            return "正在修改第 \(editingChapterNumber) 章"
        }

        if let awaitingReviewChapterNumber = trustedStatusChapter(
            facts.awaitingReviewChapterNumber,
            latestChapterNumber: latestChapterNumber
        ) {
            return awaitingReviewChapterNumber == 1
                ? "第一章等你看看"
                : "第 \(awaitingReviewChapterNumber) 章等你看看"
        }

        return "已经写到第 \(latestChapterNumber) 章"
    }

    private static func positive(_ chapterNumber: Int?) -> Int? {
        guard let chapterNumber, chapterNumber > 0 else {
            return nil
        }
        return chapterNumber
    }

    private static func trustedStatusChapter(
        _ chapterNumber: Int?,
        latestChapterNumber: Int
    ) -> Int? {
        guard let chapterNumber = positive(chapterNumber),
              chapterNumber <= latestChapterNumber else {
            return nil
        }
        return chapterNumber
    }
}
