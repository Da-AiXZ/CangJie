import CangJieCore
import Foundation

enum StreamingHTTPError: LocalizedError {
    case invalidURL
    case insecureURL
    case invalidAuthority
    case invalidResponse
    case invalidContentType
    case httpStatus(Int)
    case consumerTooSlow
    case outputLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL 无效（NET-URL）"
        case .insecureURL:
            return "M0 仅允许 HTTPS（NET-HTTPS）"
        case .invalidAuthority:
            return "URL 主机无效或包含用户凭证（NET-HOST）"
        case .invalidResponse:
            return "服务器响应无效（NET-RESPONSE）"
        case .invalidContentType:
            return "服务器未返回 text/event-stream（NET-CONTENT-TYPE）"
        case .httpStatus(let code):
            return "HTTP 请求失败：\(code)（NET-HTTP）"
        case .consumerTooSlow:
            return "流式数据过快，已安全停止（NET-BACKPRESSURE）"
        case .outputLimitExceeded:
            return "流式输出超过 M0 安全上限（NET-LIMIT）"
        }
    }
}

private final class RejectingRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

struct StreamingHTTPClient {
    private let maximumEvents = 10_000

    func stream(urlText: String) -> AsyncThrowingStream<ServerSentEvent, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingOldest(128)) { continuation in
            let task = Task {
                let delegate = RejectingRedirectDelegate()
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 60
                configuration.timeoutIntervalForResource = 300
                configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                let session = URLSession(
                    configuration: configuration,
                    delegate: delegate,
                    delegateQueue: nil
                )
                defer { session.invalidateAndCancel() }

                do {
                    let url = try validatedURL(urlText)
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw StreamingHTTPError.invalidResponse
                    }
                    guard http.statusCode == 200 else {
                        throw StreamingHTTPError.httpStatus(http.statusCode)
                    }
                    guard SSEContentType.isEventStream(
                        http.value(forHTTPHeaderField: "Content-Type")
                    ) else {
                        throw StreamingHTTPError.invalidContentType
                    }

                    var parser = SSEByteParser()
                    var eventCount = 0
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        if let event = try parser.consume(byte: byte) {
                            eventCount += 1
                            guard eventCount <= maximumEvents else {
                                throw StreamingHTTPError.outputLimitExceeded
                            }
                            switch continuation.yield(event) {
                            case .enqueued:
                                break
                            case .dropped:
                                throw StreamingHTTPError.consumerTooSlow
                            case .terminated:
                                return
                            @unknown default:
                                throw StreamingHTTPError.consumerTooSlow
                            }
                        }
                    }
                    try Task.checkCancellation()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func validatedURL(_ text: String) throws -> URL {
        guard let components = URLComponents(string: text), let url = components.url else {
            throw StreamingHTTPError.invalidURL
        }
        guard components.scheme?.lowercased() == "https" else {
            throw StreamingHTTPError.insecureURL
        }
        guard let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else {
            throw StreamingHTTPError.invalidAuthority
        }
        return url
    }
}