import CangJieCore
import Foundation
import XCTest
@testable import CangJie

final class ModelDiscoveryNetworkSecurityTests: XCTestCase {
    private let discoveryID = UUID(
        uuidString: "35000000-0000-0000-0000-000000000035"
    )!
    private let connectionID = UUID(
        uuidString: "40000000-0000-0000-0000-000000000004"
    )!
    private let credentialID = UUID(
        uuidString: "45000000-0000-0000-0000-000000000045"
    )!
    private let secret = "fixture-secret-value"

    func testOpenRouterProbeFailuresNeverRequestThePublicCatalog() async throws {
        let staleAttempt = try makeAttempt(discoveryID: UUID())
        let staleIdentity = try probeIdentity(from: staleAttempt.start)
        let failures: [(QueuedResponse, ModelDiscoveryError)] = [
            (
                QueuedResponse(401, #"{"data":{"label":"masked"}}"#),
                .connectionProbeFailed
            ),
            (
                QueuedResponse(200, "{}"),
                .malformedResponse
            ),
            (
                QueuedResponse(
                    200,
                    Data(
                        repeating: 0x20,
                        count: ModelDiscoveryFlow.maximumProbeResponseBytes + 1
                    )
                ),
                .responseTooLarge
            ),
            (
                QueuedResponse(
                    200,
                    #"{"data":{"label":"masked"}}"#,
                    identityOverride: staleIdentity
                ),
                .responseRequestMismatch
            )
        ]

        for (failure, expectedError) in failures {
            let transport = RecordingTransport(
                responses: [
                    failure,
                    QueuedResponse(
                        200,
                        #"{"data":[{"id":"router/model"}],"total_count":1,"links":{"next":null}}"#
                    )
                ]
            )
            do {
                _ = try await ModelDiscoveryNetworkClient(
                    transport: transport,
                    resolver: SequenceResolver([])
                ).discover(try makeAttempt())
                XCTFail("Expected OpenRouter probe failure: \(expectedError)")
            } catch {
                XCTAssertEqual(error as? ModelDiscoveryError, expectedError)
            }

            let requests = await transport.requests()
            XCTAssertEqual(requests.count, 1)
            XCTAssertEqual(requests.first?.identity.kind, .connectionProbe)
        }
    }

    func testOpenRouterVerifiedProbeAuthorizesItsPublicCatalogSelection() async throws {
        let attempt = try makeAttempt()
        let result = try await ModelDiscoveryNetworkClient(
            transport: RecordingTransport(
                responses: [
                    QueuedResponse(200, #"{"data":{"label":"masked"}}"#),
                    QueuedResponse(
                        200,
                        #"{"data":[{"id":"router/model"}],"total_count":1,"links":{"next":null}}"#
                    )
                ]
            ),
            resolver: SequenceResolver([])
        ).discover(attempt)
        let selection = try ModelDiscoveryFlow.selectModel(
            "router/model",
            from: result.discoveryResult
        )

        XCTAssertEqual(selection.source, .publicCatalogAfterCredentialProbe)
        let candidate = try attempt.prepareConnection(
            name: "Verified OpenRouter model",
            selection: selection
        )
        XCTAssertEqual(candidate.connection.selectedModel, "router/model")
        XCTAssertEqual(candidate.credentialBinding, attempt.credentialBinding)
    }

    func testOpenRouterProbeBytesCountTowardTheWholeDiscoveryBudget() async throws {
        var responses = [
            QueuedResponse(200, #"{"data":{"label":"masked"}}"#)
        ]
        for page in 0..<4 {
            let nextURL = page < 3
                ? "https://openrouter.ai/api/v1/models?offset=\(page + 1)&limit=1000"
                : nil
            responses.append(
                QueuedResponse(
                    200,
                    try paddedOpenRouterPage(
                        modelID: "router/model-\(page)",
                        nextURL: nextURL,
                        totalCount: 4,
                        byteCount: ModelDiscoveryFlow.maximumResponseBytes
                    )
                )
            )
        }
        let transport = RecordingTransport(responses: responses)

        do {
            _ = try await ModelDiscoveryNetworkClient(
                transport: transport,
                resolver: SequenceResolver([])
            ).discover(try makeAttempt())
            XCTFail("Expected the probe plus four full pages to exceed the total budget")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryError,
                .discoveryBudgetExceeded
            )
        }

        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 5)
        XCTAssertEqual(requests.first?.identity.kind, .connectionProbe)
        XCTAssertEqual(
            requests.dropFirst().map(\.identity.kind),
            Array(repeating: .catalogPage, count: 4)
        )
    }

    private func makeAttempt(
        discoveryID: UUID? = nil
    ) throws -> ModelDiscoveryAttempt {
        try ModelDiscoveryAttempt(
            discoveryID: discoveryID ?? self.discoveryID,
            connectionID: connectionID,
            credentialID: credentialID,
            provider: .openRouter,
            baseURL: URL(string: "https://openrouter.ai/api/v1")!,
            secret: secret
        )
    }

    private func probeIdentity(
        from start: ModelDiscoveryStart,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> ModelDiscoveryRequestIdentity {
        guard case let .connectionProbeRequired(challenge) = start else {
            XCTFail("Expected a connection probe", file: file, line: line)
            throw ModelDiscoveryError.connectionProbeFailed
        }
        return challenge.request.identity
    }

    private func paddedOpenRouterPage(
        modelID: String,
        nextURL: String?,
        totalCount: Int,
        byteCount: Int
    ) throws -> Data {
        let next: Any = nextURL ?? NSNull()
        let object: [String: Any] = [
            "data": [["id": modelID]],
            "total_count": totalCount,
            "links": ["next": next]
        ]
        var data = try JSONSerialization.data(withJSONObject: object)
        guard data.last == 0x7D,
              data.count <= byteCount else {
            throw ModelDiscoveryNetworkError.invalidResponse
        }
        let paddingCount = byteCount - data.count
        data.removeLast()
        data.append(Data(repeating: 0x20, count: paddingCount))
        data.append(0x7D)
        return data
    }
}
