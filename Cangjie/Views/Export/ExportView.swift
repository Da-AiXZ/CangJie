//
//  ExportView.swift
//  Cangjie
//
//  导出页：格式选择（DOCX/EPUB/PDF/MD）+ 章节范围 + 导出选项 + ShareLink 分享。
//  调 ExportStore.export()。对齐 Vue3 导出组件选项。
//

import SwiftUI

struct ExportView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = ExportStore()

    @State private var selectedFormat: ExportFormat = .epub
    @State private var includeMetadata = true
    @State private var includeCover = true
    @State private var includeTOC = true
    @State private var exportAllChapters = true
    @State private var chapterStart: Double = 1
    @State private var chapterEnd: Double = 100

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // 格式选择
                formatSection

                // 范围选择
                rangeSection

                // 选项
                optionsSection

                // 导出按钮
                exportButton

                // 导出结果
                if let result = store.exportResult {
                    resultSection(result)
                }

                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.error)
                        .font(.system(size: 12))
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("导出")
    }

    // MARK: - 格式选择

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("导出格式").font(Theme.headlineFont())

            HStack(spacing: Theme.Spacing.md) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    formatButton(format)
                }
            }
        }
        .cardStyle()
    }

    private func formatButton(_ format: ExportFormat) -> some View {
        Button { selectedFormat = format } label: {
            VStack(spacing: 6) {
                Image(systemName: formatIcon(format))
                    .font(.system(size: 24))
                    .foregroundColor(selectedFormat == format ? Theme.primary : Theme.textSecondary)
                Text(format.displayName)
                    .font(.system(size: 13, weight: selectedFormat == format ? .semibold : .regular))
                Text(format.fileExtension)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(selectedFormat == format ? Theme.primary.opacity(0.1) : Theme.tertiaryBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(selectedFormat == format ? Theme.primary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 范围选择

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("章节范围").font(Theme.headlineFont())

            Toggle("导出全部章节", isOn: $exportAllChapters)

            if !exportAllChapters {
                VStack(spacing: 8) {
                    Text("第 \(Int(chapterStart)) ~ \(Int(chapterEnd)) 章")
                        .font(.system(size: 12, design: .monospaced))
                    HStack {
                        Text("起").font(.caption)
                        Slider(value: $chapterStart, in: 1...200, step: 1) { editing in
                            if !editing, chapterStart > chapterEnd { chapterEnd = chapterStart }
                        }
                    }
                    HStack {
                        Text("止").font(.caption)
                        Slider(value: $chapterEnd, in: 1...200, step: 1) { editing in
                            if !editing, chapterEnd < chapterStart { chapterStart = chapterEnd }
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 选项

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("导出选项").font(Theme.headlineFont())

            Toggle("包含元数据（作者/简介/标签）", isOn: $includeMetadata)
            Toggle("包含封面（如有）", isOn: $includeCover)
            Toggle("包含目录", isOn: $includeTOC)
        }
        .cardStyle()
    }

    // MARK: - 导出按钮

    private var exportButton: some View {
        Button {
            Task { await performExport() }
        } label: {
            if store.isExporting {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("导出中…").padding(.leading, 8)
                }
                .frame(maxWidth: .infinity)
            } else {
                Label("开始导出", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(store.isExporting)
    }

    // MARK: - 结果

    private func resultSection(_ result: ExportResult) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Label("导出成功", systemImage: "checkmark.circle.fill")
                .foregroundColor(Theme.success)

            HStack(spacing: Theme.Spacing.md) {
                VStack(spacing: 2) {
                    Text(formatFileSize(result.data.count)).font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("大小").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                }
                VStack(spacing: 2) {
                    Text(result.format.displayName).font(.system(size: 14, weight: .bold))
                    Text("格式").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                }
                VStack(spacing: 2) {
                    Text(result.filename).font(.system(size: 10, design: .monospaced)).lineLimit(1)
                    Text("文件名").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                }
            }

            // ShareLink（iOS 16+）
            if let url = result.fileURL {
                ShareLink(item: url) {
                    Label("分享文件", systemImage: "square.and.arrow.up.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .cardStyle()
    }

    // MARK: - 操作

    private func performExport() async {
        guard let novelId = appState.currentNovelId else { return }
        await store.exportNovel(novelId: novelId, format: selectedFormat)
    }

    // MARK: - 辅助

    private func formatIcon(_ format: ExportFormat) -> String {
        switch format {
        case .epub: return "book.fill"
        case .pdf: return "doc.richtext.fill"
        case .docx: return "doc.text.fill"
        case .markdown: return "text.alignleft"
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes >= 1_048_576 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        if bytes >= 1024 { return "\(bytes / 1024) KB" }
        return "\(bytes) B"
    }
}
