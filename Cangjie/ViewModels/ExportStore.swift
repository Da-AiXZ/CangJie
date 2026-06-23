//
//  ExportStore.swift
//  Cangjie
//
//  导出 DOCX/EPUB/PDF/MD。
//

import SwiftUI
import Foundation

/// 导出 Store
@MainActor
final class ExportStore: ObservableObject {

    @Published var isExporting: Bool = false
    @Published var exportResult: ExportResult?
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 导出小说
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - format: 导出格式
    ///   - chapterStart: 起始章节号（可选，后端支持范围导出）
    ///   - chapterEnd: 结束章节号（可选，后端支持范围导出）
    /// - Returns: 导出结果
    @discardableResult
    func exportNovel(novelId: String, format: ExportFormat, chapterStart: Int? = nil, chapterEnd: Int? = nil) async -> ExportResult? {
        isExporting = true
        errorMessage = nil

        do {
            // 【修复】后端导出返回 StreamingResponse（二进制文件），非 JSON。
            // 修复前路径为 /novel/{id}（缺少 /export 前缀），导致 404。
            // 正确路径为 /export/novel/{id}?format=xxx
            var queryItems: [URLQueryItem] = [URLQueryItem(name: "format", value: format.rawValue)]
            if let start = chapterStart {
                queryItems.append(URLQueryItem(name: "chapter_start", value: String(start)))
            }
            if let end = chapterEnd {
                queryItems.append(URLQueryItem(name: "chapter_end", value: String(end)))
            }

            let data = try await apiClient.download(
                APIEndpoint.EndpointInfoWrapper(
                    path: "/novel/\(novelId)",
                    prefix: APIEndpoint.defaultPrefix + "/export",
                    method: .get,
                    queryItems: queryItems
                )
            )

            // 从 Content-Disposition 提取文件名
            let filename = "\(novelId).\(format.fileExtension)"
            let result = ExportResult(data: data, filename: filename, mimeType: format.mimeType, format: format)
            exportResult = result

            Logger.data.info("导出成功: \(filename), \(data.count) bytes")
            isExporting = false
            return result
        } catch {
            errorMessage = error.localizedDescription
            Logger.data.error("导出失败: \(error.localizedDescription)")
            isExporting = false
            return nil
        }
    }

    /// 导出章节
    /// - Parameters:
    ///   - chapterId: 章节 ID
    ///   - format: 导出格式
    ///   - novelId: 小说 ID（可选，与 chapterNumber 配合使用）
    ///   - chapterNumber: 章节编号（可选，与 novelId 配合使用）
    /// - Returns: 导出结果
    @discardableResult
    func exportChapter(chapterId: String, format: ExportFormat, novelId: String? = nil, chapterNumber: Int? = nil) async -> ExportResult? {
        isExporting = true
        errorMessage = nil

        do {
            // 【修复】修复前路径为 /chapter/{id}（缺少 /export 前缀），导致 404。
            // 正确路径为 /export/chapter/{id}?format=xxx
            var queryItems: [URLQueryItem] = [URLQueryItem(name: "format", value: format.rawValue)]
            if let nid = novelId {
                queryItems.append(URLQueryItem(name: "novel_id", value: nid))
            }
            if let cn = chapterNumber {
                queryItems.append(URLQueryItem(name: "chapter_number", value: String(cn)))
            }

            let data = try await apiClient.download(
                APIEndpoint.EndpointInfoWrapper(
                    path: "/chapter/\(chapterId)",
                    prefix: APIEndpoint.defaultPrefix + "/export",
                    method: .get,
                    queryItems: queryItems
                )
            )

            let filename = "chapter-\(chapterId).\(format.fileExtension)"
            let result = ExportResult(data: data, filename: filename, mimeType: format.mimeType, format: format)
            exportResult = result

            isExporting = false
            return result
        } catch {
            errorMessage = error.localizedDescription
            isExporting = false
            return nil
        }
    }

    /// 分享导出文件
    /// - Parameter result: 导出结果
    func shareFile(_ result: ExportResult) -> URL? {
        return result.fileURL
    }
}
