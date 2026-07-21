import Foundation
import XCTest
@testable import CangJieCore

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

        let connection = try ModelConnection.make(
            id: connectionID,
            name: "  我的 DeepSeek  ",
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: credentialID,
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
                allowedHost: "api.deepseek.com"
            )
        )
        XCTAssertEqual(connection.selectedModel, "deepseek-chat")
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

        let decision = try ModelRequestAdmission.decide(
            rawRequest: "继续刚才的请求",
            intentID: intentID,
            conversationID: conversationID,
            currentConnection: connection,
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
                connection: connection
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

        XCTAssertEqual(
            ModelRequestAdmission.resume(intent, with: connection),
            .prepareProviderRequest(intent: intent, connection: connection)
        )
    }
}
