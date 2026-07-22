import Foundation
import XCTest
@_spi(ModelDiscoveryCredentialBinding) @_spi(ModelDiscoveryTransport) @testable import CangJieCore

protocol ModelDiscoveryContractTestSupport: AnyObject {}

extension ModelDiscoveryContractTestSupport where Self: XCTestCase {
    var discoveryID: UUID {
        UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    }

    var connectionID: UUID {
        UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
    }

    var credentialID: UUID {
        UUID(uuidString: "40000000-0000-0000-0000-000000000004")!
    }

    func readySession(
        discoveryID: UUID? = nil,
        connectionID: UUID? = nil,
        provider: ModelProvider,
        baseURL: URL
    ) throws -> ModelDiscoverySession {
        let start = try ModelDiscoveryFlow.start(
            discoveryID: discoveryID ?? self.discoveryID,
            credentialBinding: try credentialBinding(
                connectionID: connectionID,
                provider: provider,
                baseURL: baseURL
            )
        )
        switch start {
        case let .ready(session):
            return session
        case let .connectionProbeRequired(challenge):
            return try verify(challenge)
        }
    }

    func credentialBinding(
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

    func verify(
        _ challenge: ModelConnectionProbeChallenge
    ) throws -> ModelDiscoverySession {
        try ModelDiscoveryFlow.validateConnectionProbe(
            ModelDiscoveryResponse(
                requestIdentity: challenge.request.identity,
                requestURL: challenge.request.url,
                statusCode: 200,
                body: Data(#"{"data":{"label":"masked"}}"#.utf8)
            ),
            for: challenge
        )
    }

    func probeChallenge(
        from start: ModelDiscoveryStart,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> ModelConnectionProbeChallenge {
        guard case let .connectionProbeRequired(challenge) = start else {
            XCTFail("Expected a connection probe challenge", file: file, line: line)
            throw ModelDiscoveryError.connectionProbeFailed
        }
        return challenge
    }

    func receive(
        _ body: String,
        for session: ModelDiscoverySession,
        statusCode: Int = 200
    ) throws -> ModelDiscoveryResult {
        try receive(Data(body.utf8), for: session, statusCode: statusCode)
    }

    func receive(
        _ body: Data,
        for session: ModelDiscoverySession,
        statusCode: Int = 200
    ) throws -> ModelDiscoveryResult {
        try ModelDiscoveryFlow.receive(
            ModelDiscoveryResponse(
                requestIdentity: session.request.identity,
                requestURL: session.request.url,
                statusCode: statusCode,
                body: body
            ),
            for: session
        )
    }

    func nextSession(
        from result: ModelDiscoveryResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> ModelDiscoverySession {
        guard case let .nextPage(session) = result else {
            XCTFail("Expected another discovery page", file: file, line: line)
            throw ModelDiscoveryError.catalogIncomplete
        }
        return session
    }

    func completeCatalog(
        from result: ModelDiscoveryResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> DiscoveredModelCatalog {
        guard case let .complete(catalog) = result else {
            XCTFail("Expected a complete model catalog", file: file, line: line)
            throw ModelDiscoveryError.catalogIncomplete
        }
        return catalog
    }

    func manualAuthorization(
        from result: ModelDiscoveryResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> ManualModelEntryAuthorization {
        guard case let .manualEntryAllowed(authorization) = result else {
            XCTFail("Expected manual-model authorization", file: file, line: line)
            throw ModelDiscoveryError.manualEntryNotAuthorized
        }
        return authorization
    }

    func paddedGeminiPage(
        modelID: String,
        nextToken: String,
        byteCount: Int
    ) -> Data {
        let prefix = #"{"models":[{"name":"\#(modelID)"}],"nextPageToken":"\#(nextToken)""#
        let suffix = "}"
        let paddingCount = byteCount - prefix.utf8.count - suffix.utf8.count
        precondition(paddingCount >= 0)
        return Data((prefix + String(repeating: " ", count: paddingCount) + suffix).utf8)
    }
}
