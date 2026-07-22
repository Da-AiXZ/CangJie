import Foundation
import XCTest
@_spi(ModelDiscoveryCredentialBinding) @_spi(ModelDiscoveryTransport) @testable import CangJieCore

final class ModelDiscoveryContractTests: XCTestCase, ModelDiscoveryContractTestSupport {

    func testBuildsProviderBoundCredentialFreeRequestPlansAndIdentities() throws {
        let cases: [(
            provider: ModelProvider,
            baseURL: String,
            requestURL: String,
            credential: ModelDiscoveryCredentialAttachment,
            headers: [String: String]
        )] = [
            (
                .deepSeek,
                "https://api.deepseek.com",
                "https://api.deepseek.com/models",
                .bearerAuthorizationHeader,
                [:]
            ),
            (
                .anthropic,
                "https://api.anthropic.com",
                "https://api.anthropic.com/v1/models?limit=1000",
                .header(name: "x-api-key"),
                ["anthropic-version": "2023-06-01"]
            ),
            (
                .openAI,
                "https://api.openai.com/v1",
                "https://api.openai.com/v1/models",
                .bearerAuthorizationHeader,
                [:]
            ),
            (
                .gemini,
                "https://generativelanguage.googleapis.com/v1beta",
                "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000",
                .header(name: "x-goog-api-key"),
                [:]
            ),
            (
                .custom,
                "https://models.example/openai/v1/",
                "https://models.example/openai/v1/models",
                .bearerAuthorizationHeader,
                [:]
            )
        ]

        for item in cases {
            let session = try readySession(
                provider: item.provider,
                baseURL: URL(string: item.baseURL)!
            )

            XCTAssertEqual(session.scope.discoveryID, discoveryID)
            XCTAssertEqual(session.scope.connectionID, connectionID)
            XCTAssertEqual(session.scope.provider, item.provider)
            XCTAssertEqual(session.request.identity.discoveryID, discoveryID)
            XCTAssertEqual(session.request.identity.connectionID, connectionID)
            XCTAssertEqual(
                session.request.identity.credentialBinding,
                session.scope.credentialBinding
            )
            XCTAssertEqual(session.request.identity.sequence, 0)
            XCTAssertEqual(session.request.identity.kind, .catalogPage)
            XCTAssertEqual(session.request.method, .get)
            XCTAssertEqual(session.request.url.absoluteString, item.requestURL)
            XCTAssertEqual(session.request.credentialAttachment, item.credential)
            XCTAssertEqual(session.request.additionalHeaders, item.headers)
            XCTAssertEqual(
                session.request.maximumResponseBytes,
                ModelDiscoveryFlow.maximumResponseBytes
            )
        }
    }

    func testOpenRouterRequiresVerifiedProbeBeforeItsPublicCatalog() throws {
        let start = try ModelDiscoveryFlow.start(
            discoveryID: discoveryID,
            credentialBinding: try credentialBinding(
                provider: .openRouter,
                baseURL: URL(string: "https://openrouter.ai/api/v1")!
            )
        )
        let challenge = try probeChallenge(from: start)
        let probe = challenge.request

        XCTAssertEqual(challenge.scope.discoveryID, discoveryID)
        XCTAssertEqual(challenge.scope.connectionID, connectionID)
        XCTAssertEqual(probe.identity.discoveryID, discoveryID)
        XCTAssertEqual(probe.identity.connectionID, connectionID)
        XCTAssertEqual(probe.identity.sequence, 0)
        XCTAssertEqual(probe.identity.kind, .connectionProbe)
        XCTAssertEqual(probe.method, .get)
        XCTAssertEqual(probe.url.absoluteString, "https://openrouter.ai/api/v1/key")
        XCTAssertEqual(probe.credentialAttachment, .bearerAuthorizationHeader)
        XCTAssertEqual(probe.additionalHeaders, [:])
        XCTAssertEqual(
            probe.maximumResponseBytes,
            ModelDiscoveryFlow.maximumProbeResponseBytes
        )

        let session = try verify(challenge)
        XCTAssertEqual(session.request.identity.sequence, 1)
        XCTAssertEqual(session.request.identity.kind, .catalogPage)
        XCTAssertEqual(session.request.credentialAttachment, .none)

        for provider in [
            ModelProvider.deepSeek,
            .anthropic,
            .openAI,
            .gemini,
            .custom
        ] {
            let baseURL = ProviderConnectorRegistry.connector(for: provider).defaultBaseURL
                ?? URL(string: "https://models.example/v1")!
            guard case .ready = try ModelDiscoveryFlow.start(
                discoveryID: discoveryID,
                credentialBinding: try credentialBinding(
                    provider: provider,
                    baseURL: baseURL
                )
            ) else {
                return XCTFail("Only OpenRouter may require the separate key probe")
            }
        }
    }

    func testConnectionProbeRequiresExactIdentityURLSuccessfulBoundResponse() throws {
        let challenge = try probeChallenge(
            from: ModelDiscoveryFlow.start(
                discoveryID: discoveryID,
                credentialBinding: try credentialBinding(
                    provider: .openRouter,
                    baseURL: URL(string: "https://openrouter.ai/api/v1")!
                )
            )
        )
        let otherChallenge = try probeChallenge(
            from: ModelDiscoveryFlow.start(
                discoveryID: UUID(
                    uuidString: "20000000-0000-0000-0000-000000000099"
                )!,
                credentialBinding: try credentialBinding(
                    provider: .openRouter,
                    baseURL: URL(string: "https://openrouter.ai/api/v1")!
                )
            )
        )

        XCTAssertNoThrow(try verify(challenge))
        XCTAssertThrowsError(
            try ModelDiscoveryFlow.validateConnectionProbe(
                ModelDiscoveryResponse(
                    requestIdentity: otherChallenge.request.identity,
                    requestURL: challenge.request.url,
                    statusCode: 200,
                    body: Data(#"{"data":{}}"#.utf8)
                ),
                for: challenge
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .responseRequestMismatch)
        }
        XCTAssertThrowsError(
            try ModelDiscoveryFlow.validateConnectionProbe(
                ModelDiscoveryResponse(
                    requestIdentity: challenge.request.identity,
                    requestURL: URL(string: "https://openrouter.ai/api/v1/models")!,
                    statusCode: 200,
                    body: Data(#"{"data":{}}"#.utf8)
                ),
                for: challenge
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .responseRequestMismatch)
        }
        XCTAssertThrowsError(
            try ModelDiscoveryFlow.validateConnectionProbe(
                ModelDiscoveryResponse(
                    requestIdentity: challenge.request.identity,
                    requestURL: challenge.request.url,
                    statusCode: 401,
                    body: Data()
                ),
                for: challenge
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .connectionProbeFailed)
        }
        XCTAssertThrowsError(
            try ModelDiscoveryFlow.validateConnectionProbe(
                ModelDiscoveryResponse(
                    requestIdentity: challenge.request.identity,
                    requestURL: challenge.request.url,
                    statusCode: 200,
                    body: Data(#"{"data":null}"#.utf8)
                ),
                for: challenge
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .malformedResponse)
        }
    }

    func testRejectsSameURLResponsesFromAnotherDiscoveryOrConnection() throws {
        let first = try readySession(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        let otherDiscovery = try readySession(
            discoveryID: UUID(
                uuidString: "20000000-0000-0000-0000-000000000088"
            )!,
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        let otherConnection = try readySession(
            connectionID: UUID(
                uuidString: "30000000-0000-0000-0000-000000000077"
            )!,
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )

        for staleIdentity in [
            otherDiscovery.request.identity,
            otherConnection.request.identity
        ] {
            XCTAssertEqual(first.request.url, otherDiscovery.request.url)
            XCTAssertThrowsError(
                try ModelDiscoveryFlow.receive(
                    ModelDiscoveryResponse(
                        requestIdentity: staleIdentity,
                        requestURL: first.request.url,
                        statusCode: 200,
                        body: Data(#"{"data":[]}"#.utf8)
                    ),
                    for: first
                )
            ) { error in
                XCTAssertEqual(error as? ModelDiscoveryError, .responseRequestMismatch)
            }
        }
    }

    func testParsesOpenAIStyleProvidersAndRequiresExplicitSelection() throws {
        for provider in [ModelProvider.deepSeek, .openAI, .custom] {
            let baseURL = provider == .deepSeek
                ? URL(string: "https://api.deepseek.com")!
                : provider == .openAI
                    ? URL(string: "https://api.openai.com/v1")!
                    : URL(string: "https://models.example/v1")!
            let session = try readySession(provider: provider, baseURL: baseURL)
            let result = try receive(
                #"{"object":"list","data":[{"id":"model-a"},{"id":"model-b"}]}"#,
                for: session
            )
            let catalog = try completeCatalog(from: result)

            XCTAssertEqual(catalog.discoveryID, discoveryID)
            XCTAssertEqual(catalog.modelIDs, ["model-a", "model-b"])
            XCTAssertThrowsError(
                try ModelDiscoveryFlow.selectModel(nil, from: result)
            ) { error in
                XCTAssertEqual(error as? ModelDiscoveryError, .explicitSelectionRequired)
            }
            XCTAssertThrowsError(
                try ModelDiscoveryFlow.selectModel("model-c", from: result)
            ) { error in
                XCTAssertEqual(error as? ModelDiscoveryError, .modelNotInCatalog)
            }

            let expectedSource: ModelSelectionSource = provider == .custom
                ? .customCatalogWithoutCredentialProbe
                : .discovered
            XCTAssertEqual(
                try ModelDiscoveryFlow.selectModel("model-b", from: result),
                ModelSelection(
                    discoveryID: discoveryID,
                    connectionID: connectionID,
                    provider: provider,
                    baseURL: baseURL,
                    credentialBinding: try credentialBinding(
                        provider: provider,
                        baseURL: baseURL
                    ),
                    modelID: "model-b",
                    source: expectedSource
                )
            )
        }
    }

    func testRejectsInvalidDuplicateAndOversizedModelIdentifiers() throws {
        let session = try readySession(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        let invalidIdentifiers = [
            "",
            " model-a ",
            "model\nforged",
            "model\u{202E}forged"
        ]

        for identifier in invalidIdentifiers {
            let body = try JSONSerialization.data(
                withJSONObject: ["data": [["id": identifier]]]
            )
            XCTAssertThrowsError(
                try receive(body, for: session)
            ) { error in
                XCTAssertEqual(error as? ModelDiscoveryError, .invalidModelIdentifier)
            }
        }

        let oversized = String(
            repeating: "m",
            count: ModelConnection.maximumModelIdentifierUTF8Bytes + 1
        )
        let oversizedBody = try JSONSerialization.data(
            withJSONObject: ["data": [["id": oversized]]]
        )
        XCTAssertThrowsError(
            try receive(oversizedBody, for: session)
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .modelIdentifierTooLarge)
        }

        XCTAssertThrowsError(
            try receive(
                #"{"data":[{"id":"model-a"},{"id":"model-a"}]}"#,
                for: session
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .duplicateModelIdentifier)
        }
    }

    func testCustomManualEntryRequiresExplicitUnsupportedDiscoveryEvidence() throws {
        let custom = try readySession(
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!
        )
        let unsupported = try receive(Data(), for: custom, statusCode: 404)
        let authorization = try manualAuthorization(from: unsupported)

        XCTAssertEqual(authorization.discoveryID, discoveryID)
        XCTAssertEqual(
            try authorization.selectModel("manual-model"),
            ModelSelection(
                discoveryID: discoveryID,
                connectionID: connectionID,
                provider: .custom,
                baseURL: URL(string: "https://models.example/v1")!,
                credentialBinding: try credentialBinding(
                    provider: .custom,
                    baseURL: URL(string: "https://models.example/v1")!
                ),
                modelID: "manual-model",
                source: .manualAfterUnsupportedDiscovery(statusCode: 404)
            )
        )

        let official = try readySession(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        XCTAssertThrowsError(
            try receive(Data(), for: official, statusCode: 404)
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .unexpectedHTTPStatus)
        }

        XCTAssertThrowsError(
            try receive(Data(), for: custom, statusCode: 401)
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .unexpectedHTTPStatus)
        }
    }

    func testRejectsResponseRequestMismatchAndOversizedBodies() throws {
        let session = try readySession(
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!
        )

        XCTAssertThrowsError(
            try ModelDiscoveryFlow.receive(
                ModelDiscoveryResponse(
                    requestIdentity: session.request.identity,
                    requestURL: URL(string: "https://api.deepseek.com/other")!,
                    statusCode: 200,
                    body: Data(#"{"data":[]}"#.utf8)
                ),
                for: session
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .responseRequestMismatch)
        }

        XCTAssertThrowsError(
            try receive(
                Data(
                    repeating: 0x20,
                    count: ModelDiscoveryFlow.maximumResponseBytes + 1
                ),
                for: session
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .responseTooLarge)
        }
    }

}
