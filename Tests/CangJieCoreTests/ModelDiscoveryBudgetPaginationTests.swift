import Foundation
import XCTest
@_spi(ModelDiscoveryCredentialBinding) @_spi(ModelDiscoveryTransport) @testable import CangJieCore

final class ModelDiscoveryBudgetPaginationTests: XCTestCase, ModelDiscoveryContractTestSupport {
    func testAnthropicPaginationMustCompleteBeforeSelection() throws {
        let first = try readySession(
            provider: .anthropic,
            baseURL: URL(string: "https://api.anthropic.com")!
        )
        let firstResult = try receive(
            #"{"data":[{"id":"claude-a"},{"id":"claude-b"}],"has_more":true,"first_id":"claude-a","last_id":"claude-b"}"#,
            for: first
        )
        let second = try nextSession(from: firstResult)

        XCTAssertEqual(second.request.identity.sequence, first.request.identity.sequence + 1)
        XCTAssertEqual(
            second.request.url.absoluteString,
            "https://api.anthropic.com/v1/models?limit=1000&after_id=claude-b"
        )
        XCTAssertThrowsError(
            try ModelDiscoveryFlow.selectModel("claude-a", from: firstResult)
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .catalogIncomplete)
        }

        let finalResult = try receive(
            #"{"data":[{"id":"claude-c"}],"has_more":false,"first_id":"claude-c","last_id":"claude-c"}"#,
            for: second
        )
        XCTAssertEqual(
            try completeCatalog(from: finalResult).modelIDs,
            ["claude-a", "claude-b", "claude-c"]
        )
    }

    func testGeminiPaginationPreservesExactReturnedModelNames() throws {
        let first = try readySession(
            provider: .gemini,
            baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        )
        let firstResult = try receive(
            #"{"models":[{"name":"models/gemini-a"}],"nextPageToken":"opaque-token"}"#,
            for: first
        )
        let second = try nextSession(from: firstResult)

        XCTAssertEqual(
            second.request.url.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000&pageToken=opaque-token"
        )

        let finalResult = try receive(
            #"{"models":[{"name":"models/gemini-b"}]}"#,
            for: second
        )
        XCTAssertEqual(
            try completeCatalog(from: finalResult).modelIDs,
            ["models/gemini-a", "models/gemini-b"]
        )
    }

    func testOpenRouterFollowsSameEndpointPaginationAndVerifiesTotalCount() throws {
        let first = try readySession(
            provider: .openRouter,
            baseURL: URL(string: "https://openrouter.ai/api/v1")!
        )
        let firstResult = try receive(
            #"{"data":[{"id":"router/a"},{"id":"router/b"}],"total_count":3,"links":{"next":"/api/v1/models?offset=2&limit=1000"}}"#,
            for: first
        )
        let second = try nextSession(from: firstResult)

        XCTAssertEqual(second.request.identity.sequence, 2)
        XCTAssertEqual(
            second.request.url.absoluteString,
            "https://openrouter.ai/api/v1/models?offset=2&limit=1000"
        )

        let finalResult = try receive(
            #"{"data":[{"id":"router/c"}],"total_count":3,"links":{"next":null}}"#,
            for: second
        )
        XCTAssertEqual(
            try completeCatalog(from: finalResult).modelIDs,
            ["router/a", "router/b", "router/c"]
        )
        XCTAssertEqual(
            try ModelDiscoveryFlow.selectModel("router/c", from: finalResult).source,
            .publicCatalogAfterCredentialProbe
        )
    }

    func testRejectsCrossEndpointOrIncompleteOpenRouterPagination() throws {
        let session = try readySession(
            provider: .openRouter,
            baseURL: URL(string: "https://openrouter.ai/api/v1")!
        )

        XCTAssertThrowsError(
            try receive(
                #"{"data":[{"id":"router/a"}],"total_count":2,"links":{"next":"https://attacker.example/models?offset=1&limit=1000"}}"#,
                for: session
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .nextPageEndpointMismatch)
        }

        XCTAssertThrowsError(
            try receive(
                #"{"data":[{"id":"router/a"}],"total_count":2,"links":{"next":null}}"#,
                for: session
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .totalCountMismatch)
        }
    }

    func testRejectsRepeatedCursorAndMalformedAnthropicBoundaries() throws {
        let first = try readySession(
            provider: .gemini,
            baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        )
        let firstResult = try receive(
            #"{"models":[{"name":"models/a"}],"nextPageToken":"same-token"}"#,
            for: first
        )
        let second = try nextSession(from: firstResult)

        XCTAssertThrowsError(
            try receive(
                #"{"models":[{"name":"models/b"}],"nextPageToken":"same-token"}"#,
                for: second
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .repeatedPaginationCursor)
        }

        XCTAssertThrowsError(
            try receive(
                #"{"models":[],"nextPageToken":"another-token"}"#,
                for: first
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .invalidPagination)
        }

        let anthropic = try readySession(
            provider: .anthropic,
            baseURL: URL(string: "https://api.anthropic.com")!
        )
        XCTAssertThrowsError(
            try receive(
                #"{"data":[{"id":"claude-a"}],"has_more":true,"first_id":"wrong","last_id":"claude-a"}"#,
                for: anthropic
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .invalidPagination)
        }
    }

    func testRejectsDuplicatesAcrossPagesAndCatalogsAboveHardLimit() throws {
        let first = try readySession(
            provider: .anthropic,
            baseURL: URL(string: "https://api.anthropic.com")!
        )
        let firstResult = try receive(
            #"{"data":[{"id":"claude-a"}],"has_more":true,"first_id":"claude-a","last_id":"claude-a"}"#,
            for: first
        )
        let second = try nextSession(from: firstResult)

        XCTAssertThrowsError(
            try receive(
                #"{"data":[{"id":"claude-a"}],"has_more":false,"first_id":"claude-a","last_id":"claude-a"}"#,
                for: second
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .duplicateModelIdentifier)
        }

        let openAI = try readySession(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        let entries = (0...ModelDiscoveryFlow.maximumCatalogModels).map {
            ["id": "model-\($0)"]
        }
        let body = try JSONSerialization.data(withJSONObject: ["data": entries])
        XCTAssertThrowsError(
            try receive(body, for: openAI)
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .tooManyModels)
        }
    }

    func testCatalogPageBudgetStopsBeforeRequestSeventeen() throws {
        var session = try readySession(
            provider: .gemini,
            baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        )

        for page in 0..<(ModelDiscoveryFlow.maximumCatalogPages - 1) {
            let result = try receive(
                #"{"models":[{"name":"models/page-\#(page)"}],"nextPageToken":"token-\#(page)"}"#,
                for: session
            )
            session = try nextSession(from: result)
        }

        XCTAssertEqual(
            session.request.identity.sequence,
            ModelDiscoveryFlow.maximumCatalogPages - 1
        )
        XCTAssertThrowsError(
            try receive(
                #"{"models":[{"name":"models/final-budget-page"}],"nextPageToken":"one-page-too-many"}"#,
                for: session
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .discoveryBudgetExceeded)
        }
    }

    func testTotalResponseByteBudgetCoversTheWholeDiscovery() throws {
        var session = try readySession(
            provider: .gemini,
            baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        )
        let fullPages = ModelDiscoveryFlow.maximumTotalResponseBytes
            / ModelDiscoveryFlow.maximumResponseBytes

        for page in 0..<fullPages {
            let body = paddedGeminiPage(
                modelID: "models/large-\(page)",
                nextToken: "large-token-\(page)",
                byteCount: ModelDiscoveryFlow.maximumResponseBytes
            )
            let result = try receive(body, for: session)
            session = try nextSession(from: result)
        }

        XCTAssertThrowsError(
            try receive(
                #"{"models":[{"name":"models/over-total"}]}"#,
                for: session
            )
        ) { error in
            XCTAssertEqual(error as? ModelDiscoveryError, .discoveryBudgetExceeded)
        }
    }
}
