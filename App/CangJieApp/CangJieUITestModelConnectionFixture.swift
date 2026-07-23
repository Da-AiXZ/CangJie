#if DEBUG
@_spi(ModelDiscoveryTransport) import CangJieCore
import Foundation

enum CangJieUITestModelConnectionFixture {
    static func makeSetupCandidate(
        name: String,
        modelID: String,
        secret: String
    ) throws -> ModelConnectionSetupCandidate {
        let attempt = try ModelDiscoveryAttempt(
            discoveryID: UUID(),
            connectionID: UUID(),
            credentialID: UUID(),
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            secret: secret
        )
        guard case let .ready(session) = attempt.start else {
            throw ModelDiscoveryAttemptError.selectionAttemptMismatch
        }
        let result = try ModelDiscoveryFlow.receive(
            ModelDiscoveryResponse(
                requestIdentity: session.request.identity,
                requestURL: session.request.url,
                statusCode: 200,
                body: try JSONSerialization.data(
                    withJSONObject: ["data": [["id": modelID]]]
                )
            ),
            for: session
        )
        return try attempt.prepareConnection(
            name: name,
            selection: ModelDiscoveryFlow.selectModel(modelID, from: result)
        )
    }
}
#endif
