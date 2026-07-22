import CangJieCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import CangJie

final class ModelDiscoveryNetworkCustomAuthenticationTests: XCTestCase {
    private let publicDestination = ModelDiscoveryVerifiedDestination(
        host: "models.example",
        port: 443,
        addresses: [.ipv4(8, 8, 8, 8)]
    )

    func testOrdinaryPinnedCustomResponsesCannotMintOrPrepareCandidates() async throws {
        let cases: [(QueuedResponse, String)] = [
            (
                QueuedResponse(200, #"{"data":[{"id":"public-model"}]}"#),
                "public-model"
            ),
            (QueuedResponse(404, ""), "manual-model")
        ]

        for (response, modelID) in cases {
            let attempt = try makeAttempt()
            let transport = CustomAuthenticationRecordingTransport(
                response: response,
                evidenceMode: .none
            )
            let result = try await makeClient(transport: transport).discover(attempt)

            XCTAssertThrowsError(
                try result.credentialProvenCustomSelection(modelID)
            ) { error in
                XCTAssertEqual(
                    error as? ModelDiscoveryNetworkError,
                    .customSelectionNotCredentialProven
                )
            }

            switch result.discoveryResult {
            case .nextPage:
                XCTFail("Custom discovery must not paginate")
            case .complete:
                let selection = try ModelDiscoveryFlow.selectModel(
                    modelID,
                    from: result.discoveryResult
                )
                XCTAssertThrowsError(
                    try attempt.prepareConnection(
                        name: "Unverified public catalog",
                        selection: selection
                    )
                ) { error in
                    XCTAssertEqual(
                        error as? ModelDiscoveryAttemptError,
                        .customCatalogSelectionRequiresVerifiedConnection
                    )
                }
            case let .manualEntryAllowed(authorization):
                let selection = try authorization.selectModel(modelID)
                XCTAssertThrowsError(
                    try attempt.prepareConnection(
                        name: "Unverified manual model",
                        selection: selection
                    )
                ) { error in
                    XCTAssertEqual(
                        error as? ModelDiscoveryAttemptError,
                        .manualSelectionRequiresVerifiedConnection
                    )
                }
            }

            let state = await transport.state()
            XCTAssertEqual(state.authenticationRequests.count, 1)
            XCTAssertEqual(state.catalogRequests.count, 1)
        }
    }

    func testExplicitAuthenticatedPathProducesCatalogAndManualCandidates() async throws {
        let cases: [(QueuedResponse, String, ModelSelectionSource)] = [
            (
                QueuedResponse(200, #"{"data":[{"id":"authenticated-model"}]}"#),
                "authenticated-model",
                .customCatalogWithoutCredentialProbe
            ),
            (
                QueuedResponse(404, ""),
                "manual-model",
                .manualAfterUnsupportedDiscovery(statusCode: 404)
            )
        ]

        for (response, modelID, expectedSource) in cases {
            let attempt = try makeAttempt()
            let transport = CustomAuthenticationRecordingTransport(
                response: response,
                evidenceMode: .exact
            )
            let result = try await makeClient(transport: transport).discover(attempt)
            let selection = try result.credentialProvenCustomSelection(modelID)
            let candidate = try attempt.prepareConnection(
                name: "Authenticated custom connection",
                credentialProvenSelection: selection
            )

            XCTAssertEqual(selection.source, expectedSource)
            XCTAssertEqual(candidate.connection.provider, .custom)
            XCTAssertEqual(candidate.connection.selectedModel, modelID)
            XCTAssertEqual(candidate.credentialBinding, attempt.credentialBinding)
            XCTAssertEqual(candidate.secret, ModelDiscoveryNetworkFixture.secret)

            let state = await transport.state()
            let authentication = try XCTUnwrap(state.authenticationRequests.first)
            XCTAssertEqual(state.authenticationRequests.count, 1)
            XCTAssertEqual(state.catalogRequests.count, 1)
            XCTAssertEqual(authentication.identity, try catalogIdentity(from: attempt))
            XCTAssertEqual(authentication.verifiedDestination, publicDestination)
            XCTAssertEqual(
                authentication.request.value(forHTTPHeaderField: "Authorization"),
                "Bearer \(ModelDiscoveryNetworkFixture.secret)"
            )
            XCTAssertNil(authentication.request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertFalse(
                authentication.request.url?.absoluteString.contains(
                    ModelDiscoveryNetworkFixture.secret
                ) ?? true
            )
            XCTAssertEqual(authentication.request.timeoutInterval, 30, accuracy: 0.001)
        }
    }

    func testAuthenticatedEvidenceFromAnotherAttemptIsRejectedBeforeCatalogSend() async throws {
        let attempt = try makeAttempt()
        let staleAttempt = try makeAttempt(discoveryID: UUID())
        let transport = CustomAuthenticationRecordingTransport(
            response: QueuedResponse(200, #"{"data":[]}"#),
            evidenceMode: .overridden(
                identity: try catalogIdentity(from: staleAttempt),
                credentialBinding: staleAttempt.credentialBinding
            )
        )

        do {
            _ = try await makeClient(transport: transport).discover(attempt)
            XCTFail("Expected stale attempt evidence to fail closed")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryNetworkError,
                .customAuthenticationEvidenceMismatch
            )
        }

        let state = await transport.state()
        XCTAssertEqual(state.authenticationRequests.count, 1)
        XCTAssertTrue(state.catalogRequests.isEmpty)
    }

    func testAuthenticatedEvidenceWithReplayedCredentialBindingIsRejected() async throws {
        let sharedDiscoveryID = UUID()
        let sharedConnectionID = UUID()
        let sharedCredentialID = UUID()
        let sharedVersionID = UUID()
        let attempt = try makeAttempt(
            discoveryID: sharedDiscoveryID,
            connectionID: sharedConnectionID,
            credentialID: sharedCredentialID,
            credentialVersionID: sharedVersionID
        )
        let replayedAttempt = try makeAttempt(
            discoveryID: sharedDiscoveryID,
            connectionID: sharedConnectionID,
            credentialID: sharedCredentialID,
            credentialVersionID: sharedVersionID
        )
        XCTAssertNotEqual(
            attempt.credentialBinding.versionProof,
            replayedAttempt.credentialBinding.versionProof
        )
        let transport = CustomAuthenticationRecordingTransport(
            response: QueuedResponse(200, #"{"data":[]}"#),
            evidenceMode: .overridden(
                identity: try catalogIdentity(from: attempt),
                credentialBinding: replayedAttempt.credentialBinding
            )
        )

        do {
            _ = try await makeClient(transport: transport).discover(attempt)
            XCTFail("Expected credential-binding replay to fail closed")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryNetworkError,
                .customAuthenticationEvidenceMismatch
            )
        }

        let state = await transport.state()
        XCTAssertEqual(state.authenticationRequests.count, 1)
        XCTAssertTrue(state.catalogRequests.isEmpty)
    }

    func testAuthenticatedPathRejectsUnsafeAddressBeforeCredentialOrTransport() async throws {
        let transport = CustomAuthenticationRecordingTransport(
            response: QueuedResponse(200, #"{"data":[]}"#),
            evidenceMode: .exact
        )
        let client = ModelDiscoveryNetworkClient(
            transport: transport,
            resolver: SequenceResolver([[.ipv4(127, 0, 0, 1)]])
        )

        do {
            _ = try await client.discover(try makeAttempt())
            XCTFail("Expected private destination rejection")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryNetworkError,
                .destinationAddressNotPublic
            )
        }

        let state = await transport.state()
        XCTAssertTrue(state.authenticationRequests.isEmpty)
        XCTAssertTrue(state.catalogRequests.isEmpty)
    }

    func testAuthenticatedPathUsesTheSameRequestDeadlineAndCancelsBeforeCatalogSend() async throws {
        let transport = HangingCustomAuthenticationTransport()
        let client = ModelDiscoveryNetworkClient(
            transport: transport,
            resolver: SequenceResolver([[.ipv4(8, 8, 8, 8)]]),
            clock: CustomAuthenticationStartClock(transport: transport),
            maximumDiscoveryDuration: 120,
            maximumRequestDuration: 30
        )

        do {
            _ = try await client.discover(try makeAttempt())
            XCTFail("Expected the authentication deadline to cancel the transport")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryNetworkError,
                .discoveryDeadlineExceeded
            )
        }

        let state = await transport.state()
        XCTAssertTrue(state.didStartAuthentication)
        XCTAssertTrue(state.didCancelAuthentication)
        XCTAssertEqual(state.catalogSendCount, 0)
    }

    func testShippingURLSessionTransportHasNoAuthenticatedCustomPath() async throws {
        let attempt = try makeAttempt()
        let identity = try catalogIdentity(from: attempt)
        let url = try XCTUnwrap(catalogURL(from: attempt))
        var request = URLRequest(url: url)
        request.setValue(
            "Bearer \(ModelDiscoveryNetworkFixture.secret)",
            forHTTPHeaderField: "Authorization"
        )

        do {
            _ = try await URLSessionModelDiscoveryTransport()
                .authenticateCustomConnection(
                    request,
                    requestIdentity: identity,
                    maximumResponseBytes: ModelDiscoveryFlow.maximumResponseBytes,
                    verifiedDestination: publicDestination
                )
            XCTFail("Expected the shipping transport to reject Custom authentication")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryNetworkError,
                .customAuthenticationUnavailable
            )
        }
    }

    private func makeClient(
        transport: any ModelDiscoveryHTTPTransport
    ) -> ModelDiscoveryNetworkClient {
        ModelDiscoveryNetworkClient(
            transport: transport,
            resolver: SequenceResolver([publicDestination.addresses])
        )
    }

    private func makeAttempt(
        discoveryID: UUID? = nil,
        connectionID: UUID? = nil,
        credentialID: UUID? = nil,
        credentialVersionID: UUID? = nil
    ) throws -> ModelDiscoveryAttempt {
        try ModelDiscoveryNetworkFixture.makeAttempt(
            discoveryID: discoveryID,
            connectionID: connectionID,
            credentialID: credentialID,
            credentialVersionID: credentialVersionID,
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!
        )
    }

    private func catalogIdentity(
        from attempt: ModelDiscoveryAttempt
    ) throws -> ModelDiscoveryRequestIdentity {
        guard case let .ready(session) = attempt.start else {
            throw ModelDiscoveryNetworkError.invalidResponse
        }
        return session.request.identity
    }

    private func catalogURL(from attempt: ModelDiscoveryAttempt) -> URL? {
        guard case let .ready(session) = attempt.start else {
            return nil
        }
        return session.request.url
    }
}

private enum CustomAuthenticationEvidenceMode: Sendable {
    case none
    case exact
    case overridden(
        identity: ModelDiscoveryRequestIdentity,
        credentialBinding: ModelDiscoveryCredentialBinding
    )
}

private actor CustomAuthenticationRecordingTransport: ModelDiscoveryHTTPTransport {
    nonisolated let customDestinationCapability: ModelDiscoveryCustomDestinationCapability =
        .verifiedAddressSet

    private let response: QueuedResponse
    private let evidenceMode: CustomAuthenticationEvidenceMode
    private var authenticationRequests: [RecordedRequest] = []
    private var catalogRequests: [RecordedRequest] = []

    init(
        response: QueuedResponse,
        evidenceMode: CustomAuthenticationEvidenceMode
    ) {
        self.response = response
        self.evidenceMode = evidenceMode
    }

    func authenticateCustomConnection(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination
    ) async throws -> ModelDiscoveryAuthenticatedConnectionEvidence? {
        authenticationRequests.append(
            RecordedRequest(
                request: request,
                identity: requestIdentity,
                maximumResponseBytes: maximumResponseBytes,
                verifiedDestination: verifiedDestination
            )
        )
        guard let requestURL = request.url else {
            throw ModelDiscoveryNetworkError.invalidResponse
        }
        switch evidenceMode {
        case .none:
            return nil
        case .exact:
            return ModelDiscoveryAuthenticatedConnectionEvidence(
                requestIdentity: requestIdentity,
                requestURL: requestURL,
                credentialBinding: requestIdentity.credentialBinding,
                verifiedDestination: verifiedDestination
            )
        case let .overridden(identity, credentialBinding):
            return ModelDiscoveryAuthenticatedConnectionEvidence(
                requestIdentity: identity,
                requestURL: requestURL,
                credentialBinding: credentialBinding,
                verifiedDestination: verifiedDestination
            )
        }
    }

    func send(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination?
    ) async throws -> ModelDiscoveryTransportResponse {
        catalogRequests.append(
            RecordedRequest(
                request: request,
                identity: requestIdentity,
                maximumResponseBytes: maximumResponseBytes,
                verifiedDestination: verifiedDestination
            )
        )
        guard let requestURL = request.url else {
            throw ModelDiscoveryNetworkError.invalidResponse
        }
        return ModelDiscoveryTransportResponse(
            requestIdentity: response.identityOverride ?? requestIdentity,
            requestURL: response.urlOverride ?? requestURL,
            statusCode: response.statusCode,
            body: response.body
        )
    }

    func state() -> (
        authenticationRequests: [RecordedRequest],
        catalogRequests: [RecordedRequest]
    ) {
        (authenticationRequests, catalogRequests)
    }
}

private actor HangingCustomAuthenticationTransport: ModelDiscoveryHTTPTransport {
    nonisolated let customDestinationCapability: ModelDiscoveryCustomDestinationCapability =
        .verifiedAddressSet
    private var didStartAuthentication = false
    private var didCancelAuthentication = false
    private var catalogSendCount = 0
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func authenticateCustomConnection(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination
    ) async throws -> ModelDiscoveryAuthenticatedConnectionEvidence? {
        didStartAuthentication = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        do {
            try await Task.sleep(nanoseconds: UInt64.max)
        } catch is CancellationError {
            didCancelAuthentication = true
            throw CancellationError()
        }
        throw ModelDiscoveryNetworkError.invalidResponse
    }

    func send(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination?
    ) async throws -> ModelDiscoveryTransportResponse {
        catalogSendCount += 1
        throw ModelDiscoveryNetworkError.invalidResponse
    }

    func waitUntilAuthenticationStarted() async {
        if didStartAuthentication {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func state() -> (
        didStartAuthentication: Bool,
        didCancelAuthentication: Bool,
        catalogSendCount: Int
    ) {
        (didStartAuthentication, didCancelAuthentication, catalogSendCount)
    }
}

private struct CustomAuthenticationStartClock: ModelDiscoveryMonotonicClock {
    let transport: HangingCustomAuthenticationTransport

    func now() -> TimeInterval {
        0
    }

    func sleep(for duration: TimeInterval) async throws {
        await transport.waitUntilAuthenticationStarted()
    }
}
