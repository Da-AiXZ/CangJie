//
//  ChapterGenerationTarget.swift
//  Cangjie
//
//  章节生成目标选择纯函数，对齐原版 workbench/chapterGenerationTarget.ts。
//

import Foundation

/// 章节生成目标（精简），对齐原版 ProseGenerationChapterTarget
struct ProseGenerationChapterTarget: Equatable {
    let id: Int
    let number: Int
    let title: String
}

/// 章节生成辅助类型（对齐 ChapterGenerationChapterLike）
struct ChapterGenerationChapterLike: Equatable {
    let id: Int
    let number: Int
    let title: String
    let wordCount: Int
    let content: String?

    init(id: Int, number: Int, title: String, wordCount: Int = 0, content: String? = nil) {
        self.id = id
        self.number = number
        self.title = title
        self.wordCount = wordCount
        self.content = content
    }

    /// 从 ChapterDTO 构造
    init(from dto: ChapterDTO) {
        self.id = dto.number
        self.number = dto.number
        self.title = dto.title
        self.wordCount = dto.wordCount
        self.content = dto.content
    }
}

/// 构造合成章节目标，对齐原版 buildSyntheticChapterTarget
/// - Parameter chapterNumber: 章节号
/// - Returns: 合成的章节目标（空标题）
func buildSyntheticChapterTarget(chapterNumber: Int) -> ProseGenerationChapterTarget {
    return ProseGenerationChapterTarget(id: chapterNumber, number: chapterNumber, title: "")
}

/// 获取下一个正文章节号，对齐原版 getNextProseChapterNumber
/// - Parameter chapters: 章节列表
/// - Returns: 最大章节号 + 1（至少为 1）
func getNextProseChapterNumber(_ chapters: [ChapterGenerationChapterLike]) -> Int {
    let maxChapterNumber = chapters.reduce(0) { max, chapter in
        Swift.max(max, chapter.number)
    }
    return Swift.max(1, maxChapterNumber + 1)
}

/// 选择下一章生成目标，对齐原版 selectNextChapterGenerationTarget
/// - Parameters:
///   - currentChapter: 当前章节
///   - chapters: 章节列表
///   - nextChapterNumber: 下一章号（默认自动计算）
/// - Returns: 下一章目标，或 nil（无当前章节时）
func selectNextChapterGenerationTarget(
    currentChapter: ChapterGenerationChapterLike?,
    chapters: [ChapterGenerationChapterLike],
    nextChapterNumber: Int? = nil
) -> ProseGenerationChapterTarget? {
    guard let current = currentChapter else { return nil }
    let nextNum = nextChapterNumber ?? getNextProseChapterNumber(chapters)

    // 查找当前章节之后第一个未写的章节
    let firstUnwrittenFutureChapter = chapters
        .filter { $0.number > current.number }
        .sorted { $0.number < $1.number }
        .first { $0.wordCount <= 0 }

    if let unwritten = firstUnwrittenFutureChapter {
        return ProseGenerationChapterTarget(id: unwritten.id, number: unwritten.number, title: unwritten.title)
    }

    // 没有未写的未来章节，构造合成目标
    return buildSyntheticChapterTarget(chapterNumber: Swift.max(current.number + 1, nextNum))
}

/// 判断是否有可编辑的章节内容，对齐原版 hasEditableChapterContent
/// - Parameters:
///   - editorContent: 编辑器内容
///   - chapterListContent: 章节列表中的内容
/// - Returns: 是否有非空内容
func hasEditableChapterContent(
    editorContent: String?,
    chapterListContent: String?
) -> Bool {
    let editor = (editorContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let list = (chapterListContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return !editor.isEmpty || !list.isEmpty
}

/// 选择正文主生成目标，对齐原版 selectProsePrimaryGenerationTarget
/// - Parameters:
///   - proseOnlyWorkbench: 是否仅正文工作台模式
///   - currentChapter: 当前章节
///   - chapters: 章节列表
///   - hasChapterContent: 当前章节是否有内容
///   - nextChapterNumber: 下一章号（可选）
/// - Returns: 生成目标
func selectProsePrimaryGenerationTarget(
    proseOnlyWorkbench: Bool,
    currentChapter: ChapterGenerationChapterLike?,
    chapters: [ChapterGenerationChapterLike],
    hasChapterContent: Bool,
    nextChapterNumber: Int? = nil
) -> ProseGenerationChapterTarget? {
    if !proseOnlyWorkbench {
        guard let current = currentChapter else { return nil }
        return ProseGenerationChapterTarget(id: current.id, number: current.number, title: current.title)
    }
    let nextNum = nextChapterNumber ?? getNextProseChapterNumber(chapters)
    guard let current = currentChapter else {
        return buildSyntheticChapterTarget(chapterNumber: nextNum)
    }
    if hasChapterContent {
        return selectNextChapterGenerationTarget(
            currentChapter: current,
            chapters: chapters,
            nextChapterNumber: nextNum
        )
    } else {
        return ProseGenerationChapterTarget(id: current.id, number: current.number, title: current.title)
    }
}

/// 获取正文主操作按钮标签，对齐原版 getProsePrimaryActionLabel
/// - Parameters:
///   - proseOnlyWorkbench: 是否仅正文工作台模式
///   - hasChapterContent: 当前章节是否有内容
/// - Returns: 按钮标签文本
func getProsePrimaryActionLabel(
    proseOnlyWorkbench: Bool,
    hasChapterContent: Bool
) -> String {
    if !proseOnlyWorkbench { return "⚡ 快速生成" }
    return hasChapterContent ? "生文（下一章）" : "生文"
}
