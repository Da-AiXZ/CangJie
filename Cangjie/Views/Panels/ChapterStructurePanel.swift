//
//  ChapterStructurePanel.swift
//  Cangjie
//
//  章节结构（当前章节的节拍/场景/冲突结构展示），调 StructureStore。
//

import SwiftUI

struct ChapterStructurePanel: View {
    @EnvironmentObject var workbenchStore: WorkbenchStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let s = workbenchStore.structure {
                    structureRow("段落数", "\(s.paragraphCount)")
                    structureRow("场景数", "\(s.sceneCount)")
                    structureRow("对话比例", String(format: "%.0f%%", s.dialogueRatio * 100))
                    structureRow("节奏", s.pacing)
                    structureRow("字数", "\(workbenchStore.currentWordCount)")
                } else {
                    Text("选择章节后自动加载结构分析")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
    }

    private func structureRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
    }
}
