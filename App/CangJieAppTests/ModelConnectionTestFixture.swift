@_spi(ModelDiscoveryTransport) @testable import CangJieCore
import Foundation
@testable import CangJie

enum ModelConnectionTestFixture {
    static func makeConnection(
        id: UUID = UUID(),
        name: String = "Test connection",
        provider: ModelProvider = .openAI,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        credentialID: UUID = UUID(),
        credentialVersionID: UUID = UUID(),
        selectedModel: String = "test-model",
        secret: String = "fixture-secret"
    ) throws -> ModelConnection {
        if provider == .custom {
            return try ModelConnection.make(
                id: id,
                name: name,
                provider: provider,
                baseURL: baseURL,
                credentialID: credentialID,
                credentialVersionID: credentialVersionID,
                selectedModel: selectedModel
            )
        }
        return try makeSetupCandidate(
            id: id,
            name: name,
            provider: provider,
            baseURL: baseURL,
            credentialID: credentialID,
            credentialVersionID: credentialVersionID,
            selectedModel: selectedModel,
            secret: secret
        ).connection
    }

    static func makeSetupCandidate(
        discoveryID: UUID = UUID(),
        id: UUID = UUID(),
        name: String = "Test connection",
        provider: ModelProvider = .openAI,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        credentialID: UUID = UUID(),
        credentialVersionID: UUID = UUID(),
        selectedModel: String = "test-model",
        secret: String = "fixture-secret"
    ) throws -> ModelConnectionSetupCandidate {
        let attempt = try ModelDiscoveryAttempt(
            discoveryID: discoveryID,
            connectionID: id,
            credentialID: credentialID,
            credentialVersionID: credentialVersionID,
            provider: provider,
            baseURL: baseURL,
            secret: secret
        )
        return try attempt.prepareConnection(
            name: name,
            selection: makeSelection(
                from: attempt,
                provider: provider,
                selectedModel: selectedModel
            )
        )
    }

    static func makeSelection(
        discoveryID: UUID = UUID(),
        connectionID: UUID = UUID(),
        credentialID: UUID = UUID(),
        credentialVersionID: UUID = UUID(),
        provider: ModelProvider = .openAI,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        selectedModel: String = "test-model",
        secret: String = "fixture-secret"
    ) throws -> ModelSelection {
        let attempt = try ModelDiscoveryAttempt(
            discoveryID: discoveryID,
            connectionID: connectionID,
            credentialID: credentialID,
            credentialVersionID: credentialVersionID,
            provider: provider,
            baseURL: baseURL,
            secret: secret
        )
        return try makeSelection(
            from: attempt,
            provider: provider,
            selectedModel: selectedModel
        )
    }

    private static func makeSelection(
        from attempt: ModelDiscoveryAttempt,
        provider: ModelProvider,
        selectedModel: String
    ) throws -> ModelSelection {
        let session: ModelDiscoverySession
        switch attempt.start {
        case let .ready(ready):
            session = ready
        case let .connectionProbeRequired(challenge):
            session = try ModelDiscoveryFlow.validateConnectionProbe(
                ModelDiscoveryResponse(
                    requestIdentity: challenge.request.identity,
                    requestURL: challenge.request.url,
                    statusCode: 200,
                    body: Data(#"{"data":{"label":"fixture"}}"#.utf8)
                ),
                for: challenge
            )
        }

        let result = try ModelDiscoveryFlow.receive(
            ModelDiscoveryResponse(
                requestIdentity: session.request.identity,
                requestURL: session.request.url,
                statusCode: 200,
                body: try catalogBody(provider: provider, modelID: selectedModel)
            ),
            for: session
        )
        return try ModelDiscoveryFlow.selectModel(selectedModel, from: result)
    }

    private static func catalogBody(
        provider: ModelProvider,
        modelID: String
    ) throws -> Data {
        let object: [String: Any]
        switch provider {
        case .deepSeek, .openAI, .custom:
            object = ["data": [["id": modelID]]]
        case .anthropic:
            object = [
                "data": [["id": modelID]],
                "has_more": false,
                "first_id": modelID,
                "last_id": modelID
            ]
        case .gemini:
            object = ["models": [["name": modelID]]]
        case .openRouter:
            object = [
                "data": [["id": modelID]],
                "total_count": 1,
                "links": ["next": NSNull()]
            ]
        }
        return try JSONSerialization.data(withJSONObject: object)
    }
}
