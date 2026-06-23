//
//  ExportModels.swift
//  Cangjie
//
//  导出模型，对应后端 interfaces/api/v1/core/export.py 的导出端点。
//  后端返回 StreamingResponse（二进制文件），非 JSON。
//

import Foundation

// MARK: - 导出格式

/// 导出格式枚举
enum ExportFormat: String, Codable, CaseIterable {
    case epub
    case pdf
    case docx
    case markdown

    /// 文件扩展名
    var fileExtension: String {
        switch self {
        case .epub: return "epub"
        case .pdf: return "pdf"
        case .docx: return "docx"
        case .markdown: return "md"
        }
    }

    /// MIME 类型
    var mimeType: String {
        switch self {
        case .epub: return "application/epub+zip"
        case .pdf: return "application/pdf"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .markdown: return "text/markdown"
        }
    }

    /// 中文显示名
    var displayName: String {
        switch self {
        case .epub: return "EPUB"
        case .pdf: return "PDF"
        case .docx: return "DOCX"
        case .markdown: return "Markdown"
        }
    }
}

// MARK: - 导出结果

/// 导出结果（包含文件数据和元信息）
struct ExportResult: Equatable {
    /// 文件数据
    let data: Data
    /// 文件名
    let filename: String
    /// MIME 类型
    let mimeType: String
    /// 导出格式
    let format: ExportFormat

    /// 构建 URL 用于分享/保存
    var fileURL: URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            Logger.general.error("导出文件写入失败: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - 导出请求

/// 导出小说请求参数
struct ExportNovelRequest {
    let novelId: String
    let format: ExportFormat
}

/// 导出章节请求参数
struct ExportChapterRequest {
    let chapterId: String
    let format: ExportFormat
    let novelId: String?
    let chapterNumber: Int?
}
