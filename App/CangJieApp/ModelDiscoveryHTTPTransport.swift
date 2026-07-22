import CangJieCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class ModelDiscoveryRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var didRejectRedirect = false

    var rejectedRedirect: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didRejectRedirect
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.lock()
        didRejectRedirect = true
        lock.unlock()
        completionHandler(nil)
    }
}

struct ModelDiscoveryResponseAccumulator {
    private let maximumBytes: Int
    private(set) var data = Data()

    init(maximumBytes: Int) {
        self.maximumBytes = maximumBytes
    }

    mutating func prepare(expectedContentLength: Int64) throws {
        guard expectedContentLength < 0 || expectedContentLength <= maximumBytes else {
            throw ModelDiscoveryNetworkError.responseTooLarge
        }
        if expectedContentLength > 0 {
            data.reserveCapacity(Int(expectedContentLength))
        }
    }

    mutating func append(_ chunk: Data) throws {
        guard chunk.count <= maximumBytes - data.count else {
            throw ModelDiscoveryNetworkError.responseTooLarge
        }
        data.append(chunk)
    }

    mutating func append(byte: UInt8) throws {
        guard data.count < maximumBytes else {
            throw ModelDiscoveryNetworkError.responseTooLarge
        }
        data.append(byte)
    }
}

struct URLSessionModelDiscoveryTransport: ModelDiscoveryHTTPTransport {
    let customDestinationCapability: ModelDiscoveryCustomDestinationCapability = .unavailable

    func authenticateCustomConnection(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination
    ) async throws -> ModelDiscoveryAuthenticatedConnectionEvidence? {
        throw ModelDiscoveryNetworkError.customAuthenticationUnavailable
    }

    func send(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination?
    ) async throws -> ModelDiscoveryTransportResponse {
#if canImport(Darwin)
        guard verifiedDestination == nil else {
            throw ModelDiscoveryNetworkError.customDestinationPinningUnavailable
        }
        let delegate = ModelDiscoveryRedirectDelegate()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        let (bytes, response) = try await session.bytes(for: request)
        guard !delegate.rejectedRedirect else {
            throw ModelDiscoveryNetworkError.redirectRejected
        }
        guard let http = response as? HTTPURLResponse,
              let responseURL = Self.responseURL(from: http) else {
            throw ModelDiscoveryNetworkError.invalidResponse
        }

        var accumulator = ModelDiscoveryResponseAccumulator(
            maximumBytes: maximumResponseBytes
        )
        try accumulator.prepare(expectedContentLength: response.expectedContentLength)
        for try await byte in bytes {
            try Task.checkCancellation()
            try accumulator.append(byte: byte)
        }
        guard !delegate.rejectedRedirect else {
            throw ModelDiscoveryNetworkError.redirectRejected
        }
        return ModelDiscoveryTransportResponse(
            requestIdentity: requestIdentity,
            requestURL: responseURL,
            statusCode: http.statusCode,
            body: accumulator.data
        )
#else
        throw ModelDiscoveryNetworkError.invalidResponse
#endif
    }

    static func responseURL(from response: HTTPURLResponse) -> URL? {
        response.url
    }
}
