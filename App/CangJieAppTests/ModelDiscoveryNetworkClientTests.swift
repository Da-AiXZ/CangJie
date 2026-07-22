import CangJieCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import CangJie

final class ModelDiscoveryNetworkClientTests: XCTestCase {
    private let discoveryID = ModelDiscoveryNetworkFixture.discoveryID
    private let connectionID = ModelDiscoveryNetworkFixture.connectionID
    private let credentialID = ModelDiscoveryNetworkFixture.credentialID
    private let secret = ModelDiscoveryNetworkFixture.secret

    func testAttachesCredentialsOnlyAtTransportBoundaryForEveryOfficialProvider() async throws {
        let cases: [(
            provider: ModelProvider,
            baseURL: URL,
            body: String,
            expectedHeader: String?,
            expectedValue: String?
        )] = [
            (
                .deepSeek,
                URL(string: "https://api.deepseek.com")!,
                #"{"data":[{"id":"deepseek-chat"}]}"#,
                "Authorization",
                "Bearer \(secret)"
            ),
            (
                .anthropic,
                URL(string: "https://api.anthropic.com")!,
                #"{"data":[{"id":"claude-test"}],"has_more":false,"first_id":"claude-test","last_id":"claude-test"}"#,
                "x-api-key",
                secret
            ),
            (
                .openAI,
                URL(string: "https://api.openai.com/v1")!,
                #"{"data":[{"id":"gpt-test"}]}"#,
                "Authorization",
                "Bearer \(secret)"
            ),
            (
                .gemini,
                URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
                #"{"models":[{"name":"models/gemini-test"}]}"#,
                "x-goog-api-key",
                secret
            ),
            (
                .openRouter,
                URL(string: "https://openrouter.ai/api/v1")!,
                #"{"data":[{"id":"openai/gpt-test"}],"total_count":1,"links":{"next":null}}"#,
                nil,
                nil
            )
        ]

        for item in cases {
            let responses: [QueuedResponse] = item.provider == .openRouter
                ? [
                    QueuedResponse(200, #"{"data":{"label":"masked"}}"#),
                    QueuedResponse(200, item.body)
                ]
                : [QueuedResponse(200, item.body)]
            let transport = RecordingTransport(responses: responses)
            let client = ModelDiscoveryNetworkClient(
                transport: transport,
                resolver: SequenceResolver([])
            )

            let result = try await client.discover(
                try makeAttempt(provider: item.provider, baseURL: item.baseURL)
            )
            guard case .complete = result.discoveryResult else {
                return XCTFail("Expected a complete catalog for \(item.provider)")
            }

            let requests = await transport.requests()
            XCTAssertEqual(requests.count, item.provider == .openRouter ? 2 : 1)
            let recorded = try XCTUnwrap(requests.last)
            XCTAssertFalse(recorded.request.url?.absoluteString.contains(secret) ?? true)
            XCTAssertEqual(
                recorded.request.value(
                    forHTTPHeaderField: item.expectedHeader ?? "Authorization"
                ),
                item.expectedValue
            )
            XCTAssertEqual(recorded.request.value(forHTTPHeaderField: "Cookie"), nil)
            XCTAssertNil(recorded.verifiedDestination)
            XCTAssertEqual(recorded.request.timeoutInterval, 30, accuracy: 0.001)
            if item.provider == .anthropic {
                XCTAssertEqual(
                    recorded.request.value(forHTTPHeaderField: "anthropic-version"),
                    "2023-06-01"
                )
            }
            if item.provider == .openRouter {
                let probe = try XCTUnwrap(requests.first)
                XCTAssertEqual(probe.identity.kind, .connectionProbe)
                XCTAssertEqual(probe.identity.sequence, 0)
                XCTAssertEqual(
                    probe.request.url?.absoluteString,
                    "https://openrouter.ai/api/v1/key"
                )
                XCTAssertEqual(
                    probe.request.value(forHTTPHeaderField: "Authorization"),
                    "Bearer \(secret)"
                )
                XCTAssertEqual(recorded.identity.kind, .catalogPage)
                XCTAssertEqual(recorded.identity.sequence, 1)
                XCTAssertEqual(recorded.request.url?.path, "/api/v1/models")
                XCTAssertNil(
                    recorded.request.value(forHTTPHeaderField: "Authorization")
                )
            }
        }
    }

    func testCustomDiscoveryPinsOneExactPublicResolutionBeforeAttachingCredential() async throws {
        let publicAddress: Set<ModelDiscoveryResolvedAddress> = [
            .ipv4(8, 8, 8, 8),
            .ipv6([0x20, 0x01, 0x48, 0x60, 0x48, 0x60, 0, 0, 0, 0, 0, 0, 0, 0, 0x88, 0x88])
        ]
        let transport = RecordingTransport(
            responses: [QueuedResponse(200, #"{"data":[{"id":"custom-model"}]}"#)],
            customDestinationCapability: .verifiedAddressSet
        )
        let resolver = SequenceResolver([publicAddress])
        let client = ModelDiscoveryNetworkClient(
            transport: transport,
            resolver: resolver
        )

        let result = try await client.discover(
            try makeAttempt(
                provider: .custom,
                baseURL: URL(string: "https://models.example/openai/v1")!
            )
        )
        guard case .complete = result.discoveryResult else {
            return XCTFail("Expected custom discovery to complete")
        }

        XCTAssertEqual(resolver.callCount(), 1)
        let customRequests = await transport.requests()
        let request = try XCTUnwrap(customRequests.first)
        XCTAssertEqual(
            request.request.value(forHTTPHeaderField: "Authorization"),
            "Bearer \(secret)"
        )
        XCTAssertEqual(
            request.request.url?.absoluteString,
            "https://models.example/openai/v1/models"
        )
        XCTAssertEqual(
            request.verifiedDestination,
            ModelDiscoveryVerifiedDestination(
                host: "models.example",
                port: 443,
                addresses: publicAddress
            )
        )
    }

    func testPinnedCustomCatalogProducesCredentialProvenSetupCandidate() async throws {
        let attempt = try makeAttempt(
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!
        )
        let result = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [QueuedResponse(200, #"{"data":[{"id":"custom-model"}]}"#)],
                customDestinationCapability: .verifiedAddressSet,
                customAuthenticationMode: .exact
            ),
            resolver: SequenceResolver([[.ipv4(8, 8, 8, 8)]])
        ).discover(attempt)

        let credentialProvenSelection = try result.credentialProvenCustomSelection(
            "custom-model"
        )
        let candidate = try attempt.prepareConnection(
            name: "Pinned custom catalog",
            credentialProvenSelection: credentialProvenSelection
        )

        XCTAssertEqual(candidate.connection.provider, .custom)
        XCTAssertEqual(candidate.connection.selectedModel, "custom-model")
        XCTAssertEqual(candidate.credentialBinding, attempt.credentialBinding)
        XCTAssertEqual(candidate.secret, secret)

        let otherAttempt = try makeAttempt(
            discoveryID: UUID(),
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!
        )
        XCTAssertThrowsError(
            try otherAttempt.prepareConnection(
                name: "Wrong attempt",
                credentialProvenSelection: credentialProvenSelection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelDiscoveryAttemptError,
                .selectionAttemptMismatch
            )
        }
    }

    func testOfficialDiscoveryCannotMintCustomSelectionCapability() async throws {
        let result = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [QueuedResponse(200, #"{"data":[{"id":"gpt-test"}]}"#)]
            ),
            resolver: SequenceResolver([])
        ).discover(
            try makeAttempt(
                provider: .openAI,
                baseURL: URL(string: "https://api.openai.com/v1")!
            )
        )

        XCTAssertThrowsError(
            try result.credentialProvenCustomSelection("gpt-test")
        ) { error in
            XCTAssertEqual(
                error as? ModelDiscoveryNetworkError,
                .customSelectionNotCredentialProven
            )
        }
    }

    func testCustomUnsupportedCatalogReturnsScopedManualSelectionAuthorization() async throws {
        let transport = RecordingTransport(
            responses: [QueuedResponse(404, "")],
            customDestinationCapability: .verifiedAddressSet
        )
        let client = ModelDiscoveryNetworkClient(
            transport: transport,
            resolver: SequenceResolver([[.ipv4(8, 8, 8, 8)]])
        )

        let result = try await client.discover(
            try makeAttempt(
                provider: .custom,
                baseURL: URL(string: "https://models.example/v1")!
            )
        )
        guard case let .manualEntryAllowed(authorization) = result.discoveryResult else {
            return XCTFail("Expected explicit unsupported-discovery evidence")
        }
        let selection = try authorization.selectModel("manual-model")

        XCTAssertEqual(selection.discoveryID, discoveryID)
        XCTAssertEqual(selection.connectionID, connectionID)
        XCTAssertEqual(selection.credentialBinding.credentialID, credentialID)
        XCTAssertEqual(selection.provider, .custom)
        XCTAssertEqual(
            selection.source,
            .manualAfterUnsupportedDiscovery(statusCode: 404)
        )
        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(
            requests[0].request.value(forHTTPHeaderField: "Authorization"),
            "Bearer \(secret)"
        )
    }

    func testPinnedUnsupportedCustomCatalogProducesCredentialProvenManualCandidate() async throws {
        let attempt = try makeAttempt(
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!
        )
        let result = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [QueuedResponse(404, "")],
                customDestinationCapability: .verifiedAddressSet,
                customAuthenticationMode: .exact
            ),
            resolver: SequenceResolver([[.ipv4(8, 8, 8, 8)]])
        ).discover(attempt)

        let credentialProvenSelection = try result.credentialProvenCustomSelection(
            "manual-model"
        )
        let candidate = try attempt.prepareConnection(
            name: "Pinned custom manual model",
            credentialProvenSelection: credentialProvenSelection
        )

        XCTAssertEqual(candidate.connection.provider, .custom)
        XCTAssertEqual(candidate.connection.selectedModel, "manual-model")
        XCTAssertEqual(candidate.credentialBinding, attempt.credentialBinding)
        XCTAssertEqual(candidate.secret, secret)
    }

    func testCustomSuccessfulCatalogCannotCreateSetupCandidateWithoutCredentialProof() async throws {
        let attempt = try makeAttempt(
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!
        )
        let result = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [QueuedResponse(200, #"{"data":[{"id":"public-model"}]}"#)],
                customDestinationCapability: .verifiedAddressSet
            ),
            resolver: SequenceResolver([[.ipv4(8, 8, 8, 8)]])
        ).discover(attempt)
        let selection = try ModelDiscoveryFlow.selectModel(
            "public-model",
            from: result.discoveryResult
        )

        XCTAssertEqual(selection.source, .customCatalogWithoutCredentialProbe)
        XCTAssertThrowsError(
            try attempt.prepareConnection(
                name: "Unverified custom catalog",
                selection: selection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelDiscoveryAttemptError,
                .customCatalogSelectionRequiresVerifiedConnection
            )
        }
    }

    func testCustomDiscoveryFailsClosedWhenTransportCannotPinBeforeResolutionOrSend() async throws {
        let transport = RecordingTransport(
            responses: [QueuedResponse(200, #"{"data":[]}"#)]
        )
        let resolver = SequenceResolver([[.ipv4(8, 8, 8, 8)]])
        let client = ModelDiscoveryNetworkClient(
            transport: transport,
            resolver: resolver
        )

        do {
            _ = try await client.discover(
                try makeAttempt(
                    provider: .custom,
                    baseURL: URL(string: "https://models.example/v1")!
                )
            )
            XCTFail("Expected missing destination-pinning support to fail closed")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryNetworkError,
                .customDestinationPinningUnavailable
            )
        }
        XCTAssertEqual(resolver.callCount(), 0)
        let unavailableRequests = await transport.requests()
        XCTAssertTrue(unavailableRequests.isEmpty)
    }

    func testCustomDiscoveryRejectsNonPublicResolutionBeforeCredentialOrTransport() async throws {
        let unsafeCases: [ModelDiscoveryResolvedAddress] = [
            .ipv4(10, 0, 0, 1),
            .ipv4(127, 0, 0, 1),
            .ipv4(169, 254, 1, 2),
            .ipv4(192, 88, 99, 1),
            .ipv6([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]),
            .ipv6([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF, 127, 0, 0, 1]),
            .ipv6([0xFE, 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]),
            .ipv6([0xFC, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]),
            .ipv6([0x3F, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
        ]

        for address in unsafeCases {
            let transport = RecordingTransport(
                responses: [QueuedResponse(200, #"{"data":[]}"#)],
                customDestinationCapability: .verifiedAddressSet
            )
            let client = ModelDiscoveryNetworkClient(
                transport: transport,
                resolver: SequenceResolver([[address]])
            )
            do {
                _ = try await client.discover(
                    try makeAttempt(
                        provider: .custom,
                        baseURL: URL(string: "https://models.example/v1")!
                    )
                )
                XCTFail("Expected unsafe address rejection: \(address)")
            } catch {
                XCTAssertEqual(
                    error as? ModelDiscoveryNetworkError,
                    .destinationAddressNotPublic
                )
            }
            let unsafeRequests = await transport.requests()
            XCTAssertTrue(unsafeRequests.isEmpty)
        }
    }

    func testReserved2001ProtocolAssignmentRangeIsNotPublic() {
        let reservedAddresses: [ModelDiscoveryResolvedAddress] = [
            .ipv6([0x20, 0x01, 0x00, 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]),
            .ipv6([0x20, 0x01, 0x00, 0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]),
            .ipv6([0x20, 0x01, 0x01, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
        ]

        XCTAssertTrue(reservedAddresses.allSatisfy { !$0.isPublic })
        XCTAssertTrue(
            ModelDiscoveryResolvedAddress.ipv6(
                [0x20, 0x01, 0x02, 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
            ).isPublic
        )
    }

    func testRunsAllPagesThroughTheSameAttemptAndMonotonicIdentity() async throws {
        let transport = RecordingTransport(
            responses: [
                QueuedResponse(
                    200,
                    #"{"data":[{"id":"claude-a"}],"has_more":true,"first_id":"claude-a","last_id":"claude-a"}"#
                ),
                QueuedResponse(
                    200,
                    #"{"data":[{"id":"claude-b"}],"has_more":false,"first_id":"claude-b","last_id":"claude-b"}"#
                )
            ]
        )
        let client = ModelDiscoveryNetworkClient(
            transport: transport,
            resolver: SequenceResolver([])
        )

        let result = try await client.discover(
            try makeAttempt(
                provider: .anthropic,
                baseURL: URL(string: "https://api.anthropic.com")!
            )
        )
        guard case let .complete(catalog) = result.discoveryResult else {
            return XCTFail("Expected a complete Anthropic catalog")
        }
        XCTAssertEqual(catalog.discoveryID, discoveryID)
        XCTAssertEqual(catalog.connectionID, connectionID)
        XCTAssertEqual(catalog.modelIDs, ["claude-a", "claude-b"])

        let requests = await transport.requests()
        XCTAssertEqual(requests.map(\.identity.sequence), [0, 1])
        XCTAssertTrue(
            requests.allSatisfy {
                $0.identity.discoveryID == discoveryID
                    && $0.identity.connectionID == connectionID
                    && $0.request.value(forHTTPHeaderField: "x-api-key") == secret
            }
        )
        XCTAssertEqual(
            requests.last?.request.url?.absoluteString,
            "https://api.anthropic.com/v1/models?limit=1000&after_id=claude-a"
        )
    }

    func testRejectsStaleSameURLResponseIdentityFromAnotherAttempt() async throws {
        let firstAttempt = try makeAttempt(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        let staleAttempt = try makeAttempt(
            discoveryID: UUID(
                uuidString: "35000000-0000-0000-0000-000000000099"
            )!,
            connectionID: UUID(
                uuidString: "40000000-0000-0000-0000-000000000099"
            )!,
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        let staleIdentity = try catalogIdentity(from: staleAttempt.start)
        let transport = RecordingTransport(
            responses: [
                QueuedResponse(
                    200,
                    #"{"data":[]}"#,
                    identityOverride: staleIdentity
                )
            ]
        )
        let client = ModelDiscoveryNetworkClient(
            transport: transport,
            resolver: SequenceResolver([])
        )

        do {
            _ = try await client.discover(firstAttempt)
            XCTFail("Expected stale response identity rejection")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryError,
                .responseRequestMismatch
            )
        }
    }

    func testSelectionCannotBeReboundToAnotherAttemptOrCredential() async throws {
        let firstAttempt = try makeAttempt(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            secret: "first-secret"
        )
        let secondAttempt = try makeAttempt(
            discoveryID: UUID(),
            credentialID: UUID(),
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            secret: "second-secret"
        )
        let firstResult = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [QueuedResponse(200, #"{"data":[{"id":"model-a"}]}"#)]
            ),
            resolver: SequenceResolver([])
        ).discover(firstAttempt)
        let secondResult = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [QueuedResponse(200, #"{"data":[{"id":"model-a"}]}"#)]
            ),
            resolver: SequenceResolver([])
        ).discover(secondAttempt)
        let firstSelection = try ModelDiscoveryFlow.selectModel(
            "model-a",
            from: firstResult.discoveryResult
        )
        let secondSelection = try ModelDiscoveryFlow.selectModel(
            "model-a",
            from: secondResult.discoveryResult
        )

        let candidate = try firstAttempt.prepareConnection(
            name: "First",
            selection: firstSelection
        )
        XCTAssertEqual(candidate.connection.credential.id, credentialID)
        XCTAssertEqual(candidate.secret, "first-secret")
        XCTAssertThrowsError(
            try firstAttempt.prepareConnection(
                name: "Forged",
                selection: secondSelection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelDiscoveryAttemptError,
                .selectionAttemptMismatch
            )
        }
    }

    func testSelectionCannotCrossAttemptsWithTheSameCredentialVersionButDifferentProof() async throws {
        let sharedDiscoveryID = UUID()
        let sharedConnectionID = UUID()
        let sharedCredentialID = UUID()
        let sharedVersionID = UUID()
        let firstAttempt = try makeAttempt(
            discoveryID: sharedDiscoveryID,
            connectionID: sharedConnectionID,
            credentialID: sharedCredentialID,
            credentialVersionID: sharedVersionID,
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        let secondAttempt = try makeAttempt(
            discoveryID: sharedDiscoveryID,
            connectionID: sharedConnectionID,
            credentialID: sharedCredentialID,
            credentialVersionID: sharedVersionID,
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        XCTAssertNotEqual(
            firstAttempt.credentialBinding.versionProof,
            secondAttempt.credentialBinding.versionProof
        )
        let result = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [QueuedResponse(200, #"{"data":[{"id":"model-a"}]}"#)]
            ),
            resolver: SequenceResolver([])
        ).discover(firstAttempt)
        let selection = try ModelDiscoveryFlow.selectModel(
            "model-a",
            from: result.discoveryResult
        )

        XCTAssertThrowsError(
            try secondAttempt.prepareConnection(
                name: "Stale proof",
                selection: selection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelDiscoveryAttemptError,
                .selectionAttemptMismatch
            )
        }
    }

    func testCredentialVersionProofIsFreshWhenVersionIDIsReused() throws {
        let credentialVersionID = UUID()
        let firstAttempt = try makeAttempt(
            credentialVersionID: credentialVersionID,
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!
        )
        let secondAttempt = try makeAttempt(
            credentialVersionID: credentialVersionID,
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!
        )

        XCTAssertEqual(firstAttempt.credentialBinding.versionID, credentialVersionID)
        XCTAssertEqual(secondAttempt.credentialBinding.versionID, credentialVersionID)
        XCTAssertNotEqual(
            firstAttempt.credentialBinding.versionProof,
            secondAttempt.credentialBinding.versionProof
        )
    }

    func testSelectionAndCandidateRemainBoundToTheExactCredentialVersion() async throws {
        let firstVersionID = UUID()
        let secondVersionID = UUID()
        let firstAttempt = try makeAttempt(
            credentialVersionID: firstVersionID,
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            secret: "first-version-secret"
        )
        let secondAttempt = try makeAttempt(
            credentialVersionID: secondVersionID,
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            secret: "second-version-secret"
        )
        let firstResult = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [QueuedResponse(200, #"{"data":[{"id":"model-a"}]}"#)]
            ),
            resolver: SequenceResolver([])
        ).discover(firstAttempt)
        let firstSelection = try ModelDiscoveryFlow.selectModel(
            "model-a",
            from: firstResult.discoveryResult
        )

        XCTAssertNotEqual(firstAttempt.credentialBinding, secondAttempt.credentialBinding)
        XCTAssertThrowsError(
            try secondAttempt.prepareConnection(
                name: "Wrong version",
                selection: firstSelection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelDiscoveryAttemptError,
                .selectionAttemptMismatch
            )
        }

        let candidate = try firstAttempt.prepareConnection(
            name: "Exact version",
            selection: firstSelection
        )
        XCTAssertEqual(candidate.credentialBinding, firstAttempt.credentialBinding)
        XCTAssertEqual(candidate.credentialBinding.versionID, firstVersionID)
        XCTAssertEqual(candidate.secret, "first-version-secret")
    }

    func testManualCustomSelectionCannotCreateSetupCandidateWithoutVerifiedProbe() async throws {
        let attempt = try makeAttempt(
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!
        )
        let result = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [QueuedResponse(404, "")],
                customDestinationCapability: .verifiedAddressSet
            ),
            resolver: SequenceResolver([[.ipv4(8, 8, 8, 8)]])
        ).discover(attempt)
        guard case let .manualEntryAllowed(authorization) = result.discoveryResult else {
            return XCTFail("Expected explicit unsupported-discovery evidence")
        }
        let selection = try authorization.selectModel("manual-model")

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

    func testInvalidCredentialCannotCreateAnAttemptOrReachNetwork() async throws {
        let transport = RecordingTransport(
            responses: [QueuedResponse(200, #"{"data":[]}"#)]
        )
        let client = ModelDiscoveryNetworkClient(
            transport: transport,
            resolver: SequenceResolver([])
        )

        XCTAssertThrowsError(
            try makeAttempt(
                provider: .openAI,
                baseURL: URL(string: "https://api.openai.com/v1")!,
                secret: "forged\nheader"
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryNetworkError, .invalidCredential)
        }
        let invalidCredentialRequests = await transport.requests()
        XCTAssertTrue(invalidCredentialRequests.isEmpty)
        _ = client
    }

    private func makeAttempt(
        discoveryID: UUID? = nil,
        connectionID: UUID? = nil,
        credentialID: UUID? = nil,
        credentialVersionID: UUID? = nil,
        provider: ModelProvider,
        baseURL: URL,
        secret: String? = nil
    ) throws -> ModelDiscoveryAttempt {
        try ModelDiscoveryNetworkFixture.makeAttempt(
            discoveryID: discoveryID,
            connectionID: connectionID,
            credentialID: credentialID,
            credentialVersionID: credentialVersionID,
            provider: provider,
            baseURL: baseURL,
            secret: secret
        )
    }

    private func catalogIdentity(
        from start: ModelDiscoveryStart,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> ModelDiscoveryRequestIdentity {
        guard case let .ready(session) = start else {
            XCTFail("Expected a directly ready catalog session", file: file, line: line)
            throw ModelDiscoveryError.connectionProbeFailed
        }
        return session.request.identity
    }

}
