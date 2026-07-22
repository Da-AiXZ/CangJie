import Foundation
import XCTest
@_spi(ModelDiscoveryCredentialBinding) @_spi(ModelDiscoveryTransport) @testable import CangJieCore

final class ModelDiscoveryCredentialBindingTests: XCTestCase {
    private let discoveryID = UUID(
        uuidString: "20000000-0000-0000-0000-000000000002"
    )!
    private let connectionID = UUID(
        uuidString: "30000000-0000-0000-0000-000000000003"
    )!
    private let credentialID = UUID(
        uuidString: "40000000-0000-0000-0000-000000000004"
    )!

    func testDiscoveryScopeReusesOfficialEndpointAndSafetyValidation() {
        XCTAssertThrowsError(
            try ModelDiscoveryFlow.start(
                discoveryID: discoveryID,
                credentialBinding: try credentialBinding(
                    provider: .openAI,
                    baseURL: URL(string: "https://attacker.example/v1")!
                )
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .providerBaseURLMismatch)
        }

        XCTAssertThrowsError(
            try ModelDiscoveryFlow.start(
                discoveryID: discoveryID,
                credentialBinding: try credentialBinding(
                    provider: .custom,
                    baseURL: URL(string: "https://user:secret@models.example/v1")!
                )
            )
        ) { error in
            XCTAssertEqual(error as? ModelConnectionError, .unsafeBaseURL)
        }
    }

    func testCredentialBindingRequiresCanonicalOpaqueVersionProof() {
        for invalidProof in [
            "",
            String(repeating: "a", count: 63),
            String(repeating: "A", count: 64),
            String(repeating: "g", count: 64)
        ] {
            XCTAssertThrowsError(
                try ModelDiscoveryCredentialBinding(
                    credentialID: credentialID,
                    connectionID: connectionID,
                    provider: .openAI,
                    baseURL: URL(string: "https://api.openai.com/v1")!,
                    versionID: UUID(),
                    versionProof: invalidProof
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelDiscoveryError,
                    .invalidCredentialBinding
                )
            }
        }
    }

    func testCredentialBindingOwnsTheCompleteDiscoveryScope() throws {
        let baseURL = URL(string: "https://models.example/v1")!
        let binding = try credentialBinding(provider: .custom, baseURL: baseURL)
        let start = try ModelDiscoveryFlow.start(
            discoveryID: discoveryID,
            credentialBinding: binding
        )
        guard case let .ready(session) = start else {
            return XCTFail("Custom discovery should start with its bound catalog request")
        }

        XCTAssertEqual(session.scope.connectionID, connectionID)
        XCTAssertEqual(session.scope.provider, .custom)
        XCTAssertEqual(session.scope.baseURL, baseURL)
        XCTAssertNotEqual(
            binding,
            try credentialBinding(
                connectionID: UUID(
                    uuidString: "30000000-0000-0000-0000-000000000099"
                )!,
                provider: .custom,
                baseURL: baseURL
            )
        )
        XCTAssertNotEqual(
            binding,
            try credentialBinding(
                provider: .custom,
                baseURL: URL(string: "https://models.example/other/v1")!
            )
        )
        let openAIBaseURL = URL(string: "https://api.openai.com/v1")!
        XCTAssertNotEqual(
            try credentialBinding(provider: .openAI, baseURL: openAIBaseURL),
            try credentialBinding(provider: .custom, baseURL: openAIBaseURL)
        )
    }

    private func credentialBinding(
        connectionID: UUID? = nil,
        provider: ModelProvider = .openAI,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!
    ) throws -> ModelDiscoveryCredentialBinding {
        try ModelDiscoveryCredentialBinding(
            credentialID: credentialID,
            connectionID: connectionID ?? self.connectionID,
            provider: provider,
            baseURL: baseURL,
            versionID: UUID(
                uuidString: "50000000-0000-0000-0000-000000000005"
            )!,
            versionProof: String(repeating: "a", count: 64)
        )
    }
}
