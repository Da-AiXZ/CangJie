import Foundation
import XCTest
@_spi(ModelCredentialVerification) @_spi(ModelDiscoveryCredentialBinding) @_spi(ModelDiscoveryTransport) @testable import CangJieCore

final class ModelConnectionContractTests: XCTestCase {
    func testOfficialConnectorRegistryMatchesFrozenUserChoicesAndEndpoints() {
        XCTAssertEqual(
            ProviderConnectorRegistry.officialConnectors,
            [
                ProviderConnector(
                    provider: .deepSeek,
                    displayName: "DeepSeek",
                    defaultBaseURL: URL(string: "https://api.deepseek.com")!,
                    modelDiscoveryPath: "/models",
                    allowsManualModelFallback: false
                ),
                ProviderConnector(
                    provider: .anthropic,
                    displayName: "Claude / Anthropic",
                    defaultBaseURL: URL(string: "https://api.anthropic.com")!,
                    modelDiscoveryPath: "/v1/models",
                    allowsManualModelFallback: false
                ),
                ProviderConnector(
                    provider: .openAI,
                    displayName: "GPT / OpenAI",
                    defaultBaseURL: URL(string: "https://api.openai.com/v1")!,
                    modelDiscoveryPath: "/models",
                    allowsManualModelFallback: false
                ),
                ProviderConnector(
                    provider: .gemini,
                    displayName: "Gemini",
                    defaultBaseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
                    modelDiscoveryPath: "/models",
                    allowsManualModelFallback: false
                ),
                ProviderConnector(
                    provider: .openRouter,
                    displayName: "OpenRouter",
                    defaultBaseURL: URL(string: "https://openrouter.ai/api/v1")!,
                    modelDiscoveryPath: "/models",
                    allowsManualModelFallback: false
                )
            ]
        )
    }

    func testCustomConnectorCannotGuessAHostAndAllowsExplicitModelFallback() {
        XCTAssertEqual(
            ProviderConnectorRegistry.customConnector,
            ProviderConnector(
                provider: .custom,
                displayName: "Custom service",
                defaultBaseURL: nil,
                modelDiscoveryPath: "/models",
                allowsManualModelFallback: true
            )
        )
    }

    func testBuildsConnectionFromExplicitProviderCredentialReferenceAndSelectedModel() throws {
        let connectionID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let credentialID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let credentialVersionID = UUID(
            uuidString: "30000000-0000-0000-0000-000000000003"
        )!

        let connection = try ModelConnection.make(
            id: connectionID,
            name: "  我的 DeepSeek  ",
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: credentialID,
            credentialVersionID: credentialVersionID,
            selectedModel: "  deepseek-chat  "
        )

        XCTAssertEqual(connection.id, connectionID)
        XCTAssertEqual(connection.name, "我的 DeepSeek")
        XCTAssertEqual(connection.provider, .deepSeek)
        XCTAssertEqual(connection.baseURL.absoluteString, "https://api.deepseek.com")
        XCTAssertEqual(
            connection.credential,
            ModelCredentialReference(
                id: credentialID,
                connectionID: connectionID,
                provider: .deepSeek,
                allowedHost: "api.deepseek.com",
                versionID: credentialVersionID
            )
        )
        XCTAssertEqual(connection.selectedModel, "deepseek-chat")
    }

    func testPublicConnectionCreationConsumesDiscoverySelectionEvidence() throws {
        let discoveryID = UUID(
            uuidString: "30000000-0000-0000-0000-000000000003"
        )!
        let connectionID = UUID(
            uuidString: "40000000-0000-0000-0000-000000000004"
        )!
        let credentialID = UUID(
            uuidString: "50000000-0000-0000-0000-000000000005"
        )!
        let credentialBinding = try ModelDiscoveryCredentialBinding(
            credentialID: credentialID,
            connectionID: connectionID,
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            versionID: UUID(
                uuidString: "60000000-0000-0000-0000-000000000006"
            )!,
            versionProof: String(repeating: "a", count: 64)
        )
        let start = try ModelDiscoveryFlow.start(
            discoveryID: discoveryID,
            credentialBinding: credentialBinding
        )
        guard case let .ready(session) = start else {
            return XCTFail("OpenAI discovery should not require a separate probe")
        }
        let result = try ModelDiscoveryFlow.receive(
            ModelDiscoveryResponse(
                requestIdentity: session.request.identity,
                requestURL: session.request.url,
                statusCode: 200,
                body: Data(#"{"data":[{"id":"gpt-selected"}]}"#.utf8)
            ),
            for: session
        )
        let selection = try ModelDiscoveryFlow.selectModel(
            "gpt-selected",
            from: result
        )

        let connection = try ModelConnection.make(
            name: "Selected OpenAI",
            selection: selection
        )

        XCTAssertEqual(selection.discoveryID, discoveryID)
        XCTAssertEqual(connection.id, connectionID)
        XCTAssertEqual(connection.provider, .openAI)
        XCTAssertEqual(connection.selectedModel, "gpt-selected")
        XCTAssertEqual(connection.credential.id, credentialID)
        XCTAssertEqual(connection.credential.versionID, credentialBinding.versionID)
        XCTAssertThrowsError(
            try CredentialProvenCustomModelSelection(selection: selection)
        ) { error in
            XCTAssertEqual(
                error as? ModelConnectionError,
                .unverifiedModelSelection
            )
        }
    }

    func testRawCustomSelectionsRequireCredentialProvenCapability() throws {
        let credentialBinding = try ModelDiscoveryCredentialBinding(
            credentialID: UUID(),
            connectionID: UUID(),
            provider: .custom,
            baseURL: URL(string: "https://models.example/v1")!,
            versionID: UUID(),
            versionProof: String(repeating: "a", count: 64)
        )
        let start = try ModelDiscoveryFlow.start(
            discoveryID: UUID(),
            credentialBinding: credentialBinding
        )
        guard case let .ready(session) = start else {
            return XCTFail("Custom discovery should start with its catalog request")
        }
        let catalogResult = try ModelDiscoveryFlow.receive(
            ModelDiscoveryResponse(
                requestIdentity: session.request.identity,
                requestURL: session.request.url,
                statusCode: 200,
                body: Data(#"{"data":[{"id":"custom-model"}]}"#.utf8)
            ),
            for: session
        )
        let catalogSelection = try ModelDiscoveryFlow.selectModel(
            "custom-model",
            from: catalogResult
        )
        let unsupportedResult = try ModelDiscoveryFlow.receive(
            ModelDiscoveryResponse(
                requestIdentity: session.request.identity,
                requestURL: session.request.url,
                statusCode: 404,
                body: Data()
            ),
            for: session
        )
        guard case let .manualEntryAllowed(authorization) = unsupportedResult else {
            return XCTFail("Unsupported custom discovery should scope manual entry")
        }
        let manualSelection = try authorization.selectModel("manual-model")

        for selection in [catalogSelection, manualSelection] {
            XCTAssertThrowsError(
                try ModelConnection.make(
                    name: "Unverified custom",
                    selection: selection
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionError,
                    .unverifiedModelSelection
                )
            }

            let credentialProvenSelection = try CredentialProvenCustomModelSelection(
                selection: selection
            )
            let connection = try ModelConnection.make(
                name: "Verified custom",
                credentialProvenSelection: credentialProvenSelection
            )

            XCTAssertEqual(connection.id, selection.connectionID)
            XCTAssertEqual(connection.provider, .custom)
            XCTAssertEqual(connection.baseURL, selection.baseURL)
            XCTAssertEqual(connection.credential.id, selection.credentialBinding.credentialID)
            XCTAssertEqual(connection.selectedModel, selection.modelID)
        }
    }

    func testConnectionRequiresNamedProfileAndExplicitSelectedModel() {
        let baseURL = URL(string: "https://api.openai.com/v1")!

        XCTAssertThrowsError(
            try ModelConnection.make(
                id: UUID(),
                name: " \n ",
                provider: .openAI,
                baseURL: baseURL,
                credentialID: UUID(),
                selectedModel: "gpt-test"
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .emptyName)
        }

        XCTAssertThrowsError(
            try ModelConnection.make(
                id: UUID(),
                name: "OpenAI",
                provider: .openAI,
                baseURL: baseURL,
                credentialID: UUID(),
                selectedModel: "  "
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .missingSelectedModel)
        }
    }

    func testConnectionRejectsOversizedOrControlBearingNameAndModelIdentifier() {
        let baseURL = URL(string: "https://api.openai.com/v1")!

        XCTAssertThrowsError(
            try ModelConnection.make(
                id: UUID(),
                name: String(repeating: "a", count: ModelConnection.maximumNameUTF8Bytes + 1),
                provider: .openAI,
                baseURL: baseURL,
                credentialID: UUID(),
                selectedModel: "gpt-test"
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .nameTooLarge)
        }

        for invalidName in ["显示\n伪造状态", "显示\u{202E}状态"] {
            XCTAssertThrowsError(
                try ModelConnection.make(
                    id: UUID(),
                    name: invalidName,
                    provider: .openAI,
                    baseURL: baseURL,
                    credentialID: UUID(),
                    selectedModel: "gpt-test"
                )
            ) { error in
                XCTAssertEqual(error as? ModelConnectionError, .invalidName)
            }
        }

        XCTAssertThrowsError(
            try ModelConnection.make(
                id: UUID(),
                name: "OpenAI",
                provider: .openAI,
                baseURL: baseURL,
                credentialID: UUID(),
                selectedModel: String(
                    repeating: "m",
                    count: ModelConnection.maximumModelIdentifierUTF8Bytes + 1
                )
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .selectedModelTooLarge)
        }

        for invalidModel in ["model\nforged", "model\u{2066}forged"] {
            XCTAssertThrowsError(
                try ModelConnection.make(
                    id: UUID(),
                    name: "OpenAI",
                    provider: .openAI,
                    baseURL: baseURL,
                    credentialID: UUID(),
                    selectedModel: invalidModel
                )
            ) { error in
                XCTAssertEqual(error as? ModelConnectionError, .invalidSelectedModel)
            }
        }
    }

    func testConnectionRejectsInsecureOrCredentialBearingEndpoint() {
        for endpoint in [
            "http://api.example.com/v1",
            "https://user:password@api.example.com/v1",
            "https://api.example.com/v1?key=secret",
            "https://api.example.com/v1#fragment"
        ] {
            XCTAssertThrowsError(
                try ModelConnection.make(
                    id: UUID(),
                    name: "Custom",
                    provider: .custom,
                    baseURL: URL(string: endpoint)!,
                    credentialID: UUID(),
                    selectedModel: "model-a"
                ),
                "Expected rejection for \(endpoint)"
            ) { error in
                XCTAssertEqual(error as? ModelConnectionError, .unsafeBaseURL)
            }
        }
    }

    func testCustomEndpointRejectsOversizedHostPathAndInvalidPort() {
        let oversizedHost = String(repeating: "a", count: 254)
        let oversizedPath = String(repeating: "p", count: 2_049)
        let endpoints = [
            "https://\(oversizedHost)/v1",
            "https://models.example/\(oversizedPath)",
            "https://models.example:0/v1",
            "https://models.example:65536/v1"
        ]

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else {
                return XCTFail("Foundation must parse the validation fixture: \(endpoint)")
            }
            XCTAssertThrowsError(
                try ModelConnection.make(
                    id: UUID(),
                    name: "Custom",
                    provider: .custom,
                    baseURL: url,
                    credentialID: UUID(),
                    selectedModel: "model-a"
                ),
                "Expected bounded custom endpoint rejection for \(endpoint)"
            ) { error in
                XCTAssertEqual(error as? ModelConnectionError, .unsafeBaseURL)
            }
        }
    }

    func testOfficialProviderCannotSendItsCredentialToAnUnrelatedHost() {
        XCTAssertThrowsError(
            try ModelConnection.make(
                id: UUID(),
                name: "DeepSeek",
                provider: .deepSeek,
                baseURL: URL(string: "https://attacker.example/v1")!,
                credentialID: UUID(),
                selectedModel: "deepseek-chat"
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .providerBaseURLMismatch)
        }
    }

    func testDecodedConnectionRevalidatesTheProviderEndpoint() throws {
        let connectionID = UUID()
        let valid = try ModelConnection.make(
            id: connectionID,
            name: "DeepSeek",
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: UUID(),
            selectedModel: "deepseek-chat"
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any]
        )
        object["baseURL"] = "https://attacker.example/v1"

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                ModelConnection.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        )
    }

    func testDecodedConnectionCannotRetargetAnExistingCredentialBinding() throws {
        let valid = try ModelConnection.make(
            id: UUID(),
            name: "DeepSeek",
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: UUID(),
            selectedModel: "deepseek-chat"
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any]
        )
        object["provider"] = ModelProvider.openAI.rawValue
        object["baseURL"] = "https://api.openai.com/v1"

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                ModelConnection.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .credentialBindingMismatch)
        }
    }

    func testDecodedCustomConnectionCannotRetargetCredentialToAnotherPort() throws {
        let valid = try ModelConnection.make(
            id: UUID(),
            name: "Custom",
            provider: .custom,
            baseURL: URL(string: "https://models.example.com/v1")!,
            credentialID: UUID(),
            selectedModel: "writer-model"
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any]
        )
        object["baseURL"] = "https://models.example.com:8443/v1"

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                ModelConnection.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .credentialBindingMismatch)
        }
    }

    func testCustomConnectionRoundTripPreservesExplicitHostBinding() throws {
        let connectionID = UUID()
        let connection = try ModelConnection.make(
            id: connectionID,
            name: "My compatible service",
            provider: .custom,
            baseURL: URL(string: "https://models.example.com/openai/v1")!,
            credentialID: UUID(),
            selectedModel: "writer-model"
        )

        let restored = try JSONDecoder().decode(
            ModelConnection.self,
            from: JSONEncoder().encode(connection)
        )

        XCTAssertEqual(restored, connection)
        XCTAssertEqual(restored.credential.connectionID, connectionID)
        XCTAssertEqual(restored.credential.provider, .custom)
        XCTAssertEqual(restored.credential.allowedHost, "models.example.com")
        XCTAssertNil(restored.credential.allowedPort)
    }

    func testPendingIntentRejectsABranchWithoutAProjectBinding() {
        XCTAssertThrowsError(
            try PendingModelIntent(
                id: UUID(),
                conversationID: UUID(),
                projectID: nil,
                branchID: UUID(),
                userRequest: "继续",
                createdAt: Date()
            )
        ) { error in
            XCTAssertEqual(error as? PendingModelIntentError, .branchRequiresProject)
        }
    }

    func testDecodedPendingIntentRevalidatesTheUserRequest() throws {
        let valid = try PendingModelIntent(
            id: UUID(),
            conversationID: UUID(),
            projectID: nil,
            branchID: nil,
            userRequest: "继续刚才的念头",
            createdAt: Date(timeIntervalSince1970: 1_752_998_402)
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any]
        )
        object["userRequest"] = "  \n  "

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PendingModelIntent.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        )
    }

    func testNoCurrentConnectionWaitsWithExactIntentAndDoesNotPrepareProviderRequest() throws {
        let intentID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
        let conversationID = UUID(uuidString: "40000000-0000-0000-0000-000000000004")!
        let projectID = UUID(uuidString: "50000000-0000-0000-0000-000000000005")!
        let branchID = UUID(uuidString: "60000000-0000-0000-0000-000000000006")!
        let now = Date(timeIntervalSince1970: 1_752_998_400)

        let decision = try ModelRequestAdmission.decide(
            rawRequest: "  帮我想清楚这个念头  ",
            intentID: intentID,
            conversationID: conversationID,
            projectID: projectID,
            branchID: branchID,
            currentConnection: nil,
            now: now
        )

        XCTAssertEqual(
            decision,
            .modelConnectionRequired(
                try PendingModelIntent(
                    id: intentID,
                    conversationID: conversationID,
                    projectID: projectID,
                    branchID: branchID,
                    userRequest: "帮我想清楚这个念头",
                    createdAt: now
                )
            )
        )
    }

    func testUsableCurrentConnectionPinsPreparationToThatExactConnection() throws {
        let intentID = UUID(uuidString: "70000000-0000-0000-0000-000000000007")!
        let conversationID = UUID(uuidString: "80000000-0000-0000-0000-000000000008")!
        let connectionID = UUID(uuidString: "90000000-0000-0000-0000-000000000009")!
        let now = Date(timeIntervalSince1970: 1_752_998_401)
        let connection = try ModelConnection.make(
            id: connectionID,
            name: "OpenAI",
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "gpt-test"
        )
        let verifiedConnection = try verified(connection)

        let decision = try ModelRequestAdmission.decide(
            rawRequest: "继续刚才的请求",
            intentID: intentID,
            conversationID: conversationID,
            currentConnection: verifiedConnection,
            now: now
        )

        XCTAssertEqual(
            decision,
            .prepareProviderRequest(
                intent: try PendingModelIntent(
                    id: intentID,
                    conversationID: conversationID,
                    projectID: nil,
                    branchID: nil,
                    userRequest: "继续刚才的请求",
                    createdAt: now
                ),
                verifiedConnection: verifiedConnection
            )
        )
    }

    func testResumePreservesTheExactPersistedIntentAndConnectionSnapshot() throws {
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: UUID(),
            projectID: UUID(),
            branchID: UUID(),
            userRequest: "继续最初的请求",
            createdAt: Date(timeIntervalSince1970: 1_752_998_403)
        )
        let connection = try ModelConnection.make(
            id: UUID(),
            name: "OpenRouter",
            provider: .openRouter,
            baseURL: URL(string: "https://openrouter.ai/api/v1")!,
            credentialID: UUID(),
            selectedModel: "provider/model"
        )
        let verifiedConnection = try verified(connection)

        XCTAssertEqual(
            ModelRequestAdmission.resume(intent, with: verifiedConnection),
            .prepareProviderRequest(
                intent: intent,
                verifiedConnection: verifiedConnection
            )
        )
    }

    func testCredentialVerificationFromAnotherVersionCannotAuthorizeTheConnection() throws {
        let connectionID = UUID()
        let credentialID = UUID()
        let connection = try ModelConnection.make(
            id: connectionID,
            name: "Version one",
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: credentialID,
            credentialVersionID: UUID(),
            selectedModel: "gpt-test"
        )
        let rotated = try ModelConnection.make(
            id: connectionID,
            name: "Version one",
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: credentialID,
            credentialVersionID: UUID(),
            selectedModel: "gpt-test"
        )

        XCTAssertThrowsError(
            try VerifiedModelConnection(
                connection: connection,
                credentialVerification: ModelCredentialVerification(
                    reference: rotated.credential,
                    credentialVersionProof: String(repeating: "b", count: 64),
                    credentialPayloadHash: String(repeating: "a", count: 64)
                )
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .credentialBindingMismatch)
        }
    }

    func testCredentialVerificationCarriesCanonicalOptionalSetupAuthorization() throws {
        let connection = try ModelConnection.make(
            id: UUID(),
            name: "Proof-bound",
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            credentialVersionID: UUID(),
            selectedModel: "gpt-test"
        )
        let proof = String(repeating: "b", count: 64)
        let setupAuthorizationHash = String(repeating: "c", count: 64)
        let verification = try ModelCredentialVerification(
            reference: connection.credential,
            credentialVersionProof: proof,
            credentialPayloadHash: String(repeating: "a", count: 64),
            setupAuthorizationHash: setupAuthorizationHash
        )

        XCTAssertEqual(verification.credentialVersionProof, proof)
        XCTAssertEqual(
            verification.setupAuthorizationHash,
            setupAuthorizationHash
        )
        XCTAssertNil(
            try ModelCredentialVerification(
                reference: connection.credential,
                credentialVersionProof: proof,
                credentialPayloadHash: String(repeating: "a", count: 64)
            ).setupAuthorizationHash
        )
        for invalidProof in [
            String(repeating: "a", count: 63),
            String(repeating: "A", count: 64),
            String(repeating: "g", count: 64)
        ] {
            XCTAssertThrowsError(
                try ModelCredentialVerification(
                    reference: connection.credential,
                    credentialVersionProof: invalidProof,
                    credentialPayloadHash: String(repeating: "a", count: 64)
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionError,
                    .credentialBindingMismatch
                )
            }
        }
        for invalidAuthorizationHash in [
            String(repeating: "a", count: 63),
            String(repeating: "A", count: 64),
            String(repeating: "g", count: 64)
        ] {
            XCTAssertThrowsError(
                try ModelCredentialVerification(
                    reference: connection.credential,
                    credentialVersionProof: proof,
                    credentialPayloadHash: String(repeating: "a", count: 64),
                    setupAuthorizationHash: invalidAuthorizationHash
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionError,
                    .credentialBindingMismatch
                )
            }
        }
    }

    private func verified(
        _ connection: ModelConnection
    ) throws -> VerifiedModelConnection {
        try VerifiedModelConnection(
            connection: connection,
            credentialVerification: ModelCredentialVerification(
                reference: connection.credential,
                credentialVersionProof: String(repeating: "b", count: 64),
                credentialPayloadHash: String(repeating: "a", count: 64)
            )
        )
    }
}
