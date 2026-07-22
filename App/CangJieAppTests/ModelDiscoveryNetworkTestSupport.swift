import CangJieCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CangJie

enum ModelDiscoveryNetworkFixture {
    static let discoveryID = UUID(
        uuidString: "35000000-0000-0000-0000-000000000035"
    )!
    static let connectionID = UUID(
        uuidString: "40000000-0000-0000-0000-000000000004"
    )!
    static let credentialID = UUID(
        uuidString: "45000000-0000-0000-0000-000000000045"
    )!
    static let secret = "fixture-secret-value"

    static func makeAttempt(
        discoveryID: UUID? = nil,
        connectionID: UUID? = nil,
        credentialID: UUID? = nil,
        credentialVersionID: UUID? = nil,
        provider: ModelProvider,
        baseURL: URL,
        secret: String? = nil
    ) throws -> ModelDiscoveryAttempt {
        try ModelDiscoveryAttempt(
            discoveryID: discoveryID ?? Self.discoveryID,
            connectionID: connectionID ?? Self.connectionID,
            credentialID: credentialID ?? Self.credentialID,
            credentialVersionID: credentialVersionID ?? UUID(),
            provider: provider,
            baseURL: baseURL,
            secret: secret ?? Self.secret
        )
    }
}

struct QueuedResponse: Sendable {
    let statusCode: Int
    let body: Data
    let identityOverride: ModelDiscoveryRequestIdentity?
    let urlOverride: URL?

    init(
        _ statusCode: Int,
        _ body: String,
        identityOverride: ModelDiscoveryRequestIdentity? = nil,
        urlOverride: URL? = nil
    ) {
        self.init(
            statusCode,
            Data(body.utf8),
            identityOverride: identityOverride,
            urlOverride: urlOverride
        )
    }

    init(
        _ statusCode: Int,
        _ body: Data,
        identityOverride: ModelDiscoveryRequestIdentity? = nil,
        urlOverride: URL? = nil
    ) {
        self.statusCode = statusCode
        self.body = body
        self.identityOverride = identityOverride
        self.urlOverride = urlOverride
    }
}

struct RecordedRequest: Sendable {
    let request: URLRequest
    let identity: ModelDiscoveryRequestIdentity
    let maximumResponseBytes: Int
    let verifiedDestination: ModelDiscoveryVerifiedDestination?
}

enum RecordingCustomAuthenticationMode: Equatable, Sendable {
    case none
    case exact
}

actor RecordingTransport: ModelDiscoveryHTTPTransport {
    nonisolated let customDestinationCapability: ModelDiscoveryCustomDestinationCapability
    private var queuedResponses: [QueuedResponse]
    private let customAuthenticationMode: RecordingCustomAuthenticationMode
    private var recordedRequests: [RecordedRequest] = []

    init(
        responses: [QueuedResponse],
        customDestinationCapability: ModelDiscoveryCustomDestinationCapability = .unavailable,
        customAuthenticationMode: RecordingCustomAuthenticationMode = .none
    ) {
        queuedResponses = responses
        self.customDestinationCapability = customDestinationCapability
        self.customAuthenticationMode = customAuthenticationMode
    }

    func authenticateCustomConnection(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination
    ) async throws -> ModelDiscoveryAuthenticatedConnectionEvidence? {
        guard customAuthenticationMode == .exact else {
            return nil
        }
        guard let requestURL = request.url else {
            throw ModelDiscoveryNetworkError.invalidResponse
        }
        return ModelDiscoveryAuthenticatedConnectionEvidence(
            requestIdentity: requestIdentity,
            requestURL: requestURL,
            credentialBinding: requestIdentity.credentialBinding,
            verifiedDestination: verifiedDestination
        )
    }

    func send(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination?
    ) async throws -> ModelDiscoveryTransportResponse {
        recordedRequests.append(
            RecordedRequest(
                request: request,
                identity: requestIdentity,
                maximumResponseBytes: maximumResponseBytes,
                verifiedDestination: verifiedDestination
            )
        )
        guard !queuedResponses.isEmpty, let requestURL = request.url else {
            throw ModelDiscoveryNetworkError.invalidResponse
        }
        let response = queuedResponses.removeFirst()
        return ModelDiscoveryTransportResponse(
            requestIdentity: response.identityOverride ?? requestIdentity,
            requestURL: response.urlOverride ?? requestURL,
            statusCode: response.statusCode,
            body: response.body
        )
    }

    func requests() -> [RecordedRequest] {
        recordedRequests
    }
}

actor CancellationRecordingTransport: ModelDiscoveryHTTPTransport {
    nonisolated let customDestinationCapability: ModelDiscoveryCustomDestinationCapability = .unavailable
    private var didStart = false
    private var didCancel = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func authenticateCustomConnection(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination
    ) async throws -> ModelDiscoveryAuthenticatedConnectionEvidence? {
        nil
    }

    func send(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination?
    ) async throws -> ModelDiscoveryTransportResponse {
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        do {
            try await Task.sleep(nanoseconds: UInt64.max)
        } catch is CancellationError {
            didCancel = true
            throw CancellationError()
        }
        throw ModelDiscoveryNetworkError.invalidResponse
    }

    func state() -> (didStart: Bool, didCancel: Bool) {
        (didStart, didCancel)
    }

    func waitUntilStarted() async {
        if didStart {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }
}

struct TransportStartClock: ModelDiscoveryMonotonicClock {
    let transport: CancellationRecordingTransport

    func now() -> TimeInterval {
        0
    }

    func sleep(for duration: TimeInterval) async throws {
        await transport.waitUntilStarted()
    }
}

final class SequenceResolver: ModelDiscoveryHostResolver, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Set<ModelDiscoveryResolvedAddress>]
    private var recordedCalls: [(String, Int)] = []

    init(_ results: [Set<ModelDiscoveryResolvedAddress>]) {
        self.results = results
    }

    func resolve(host: String, port: Int) throws -> Set<ModelDiscoveryResolvedAddress> {
        lock.lock()
        defer { lock.unlock() }
        recordedCalls.append((host, port))
        guard !results.isEmpty else {
            throw ModelDiscoveryNetworkError.destinationResolutionFailed
        }
        return results.removeFirst()
    }

    func callCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedCalls.count
    }
}

final class SequenceClock: ModelDiscoveryMonotonicClock, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [TimeInterval]

    init(_ values: [TimeInterval]) {
        self.values = values
    }

    func now() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        if values.count > 1 {
            return values.removeFirst()
        }
        return values.first ?? 0
    }

    func sleep(for duration: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64.max)
    }
}
