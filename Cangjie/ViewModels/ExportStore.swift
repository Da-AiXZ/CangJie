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
    /// - Returns: 导出结果
    @discardableResult
    func exportNovel(novelId: String, format: ExportFormat) async -> ExportResult? {
        isExporting = true
        errorMessage = nil

        do {
            // 后端导出返回 StreamingResponse（二进制文件），非 JSON
            // 需要构建带 format 查询参数的 URL
            guard let baseUrl = APIEndpoint.Export.novel(novelId: novelId).url() else {
                errorMessage = "无效的 URL"
                isExporting = false
                return nil
            }

            var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "format", value: format.rawValue)]

            guard let url = components?.url else {
                errorMessage = "URL 构建失败"
                isExporting = false
                return nil
            }

            // 使用 download 下载二进制数据
            let data = try await apiClient.download(
                APIEndpoint.EndpointInfoWrapper(
                    path: "/novel/\(novelId)",
                    prefix: APIEndpoint.defaultPrefix,
                    method: .get,
                    queryItems: [URLQueryItem(name: "format", value: format.rawValue)]
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
    /// - Returns: 导出结果
    @discardableResult
    func exportChapter(chapterId: String, format: ExportFormat) async -> ExportResult? {
        isExporting = true
        errorMessage = nil

        do {
            let data = try await apiClient.download(
                APIEndpoint.EndpointInfoWrapper(
                    path: "/chapter/\(chapterId)",
                    prefix: APIEndpoint.defaultPrefix,
                    method: .get,
                    queryItems: [URLQueryItem(name: "format", value: format.rawValue)]
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
