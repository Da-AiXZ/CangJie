@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

final class ProviderGenerationNetworkClientTests: XCTestCase {
    func testPreparedRequestValidatesWithoutStartingTransport() async throws {
        let fixture = try makeFixture(provider: .openAI)
        let transport = RecordingProviderGenerationTransport(events: [])
        let client = ProviderGenerationNetworkClient(transport: transport)

        XCTAssertNoThrow(
            try client.validate(
                request: fixture.preparedRequest,
                verifiedConnection: fixture.verifiedConnection,
                secret: "fixture-secret",
                systemPrompt: "system",
                userPrompt: fixture.intent.userRequest
            )
        )
        let recordedRequests = await transport.requests()
        XCTAssertTrue(recordedRequests.isEmpty)
    }

    func testDeepSeekRequestStreamsTextToolCallsUsageAndFinish() async throws {
        let fixture = try makeFixture(provider: .deepSeek)
        let transport = RecordingProviderGenerationTransport(
            events: [
                .response(
                    ProviderGenerationHTTPMetadata(
                        statusCode: 200,
                        responseURL: URL(string: "https://api.deepseek.com/chat/completions")!,
                        contentType: "text/event-stream; charset=utf-8"
                    )
                ),
                .event(sse(#"{"choices":[{"delta":{"role":"assistant"},"finish_reason":null}]}"#)),
                .event(sse(#"{"choices":[{"delta":{"content":"你好"},"finish_reason":null}]}"#)),
                .event(sse(#"{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call-1","function":{"name":"project_create","arguments":"{\"title\":"}}]},"finish_reason":null}]}"#)),
                .event(sse(#"{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"星河\"}"}}]},"finish_reason":null}]}"#)),
                .event(sse(#"{"choices":[{"delta":{},"finish_reason":"tool_calls"}]}"#)),
                .event(sse(#"{"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":7,"total_tokens":19}}"#)),
                .event(sse("[DONE]"))
            ]
        )
        let client = ProviderGenerationNetworkClient(transport: transport)

        let events = try await collect(
            client.stream(
                request: fixture.request,
                verifiedConnection: fixture.verifiedConnection,
                secret: "fixture-secret",
                systemPrompt: "You are CangJie.",
                userPrompt: fixture.intent.userRequest
            )
        )

        XCTAssertEqual(
            events,
            [
                .textDelta("你好"),
                .toolCallDelta(
                    index: 0,
                    id: "call-1",
                    name: "project_create",
                    argumentsFragment: #"{"title":"#
                ),
                .toolCallDelta(
                    index: 0,
                    id: nil,
                    name: nil,
                    argumentsFragment: #""星河"}"#
                ),
                .finished(reason: "tool_calls"),
                .usage(
                    ProviderUsage(
                        inputTokens: 12,
                        outputTokens: 7,
                        totalTokens: 19
                    )
                )
            ]
        )
        let recordedRequests = await transport.requests()
        let recorded = try XCTUnwrap(recordedRequests.first)
        XCTAssertEqual(
            recorded.request.url,
            URL(string: "https://api.deepseek.com/chat/completions")!
        )
        XCTAssertEqual(recorded.request.httpMethod, "POST")
        XCTAssertEqual(
            recorded.request.value(forHTTPHeaderField: "Authorization"),
            "Bearer fixture-secret"
        )
        XCTAssertEqual(
            recorded.requestID,
            fixture.request.identity.requestID
        )
        let body = try XCTUnwrap(recorded.request.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["model"] as? String, "deepseek-chat")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual((json["tools"] as? [[String: Any]])?.count, 2)
        XCTAssertFalse(
            try XCTUnwrap(String(data: body, encoding: .utf8))
                .contains("fixture-secret")
        )
    }

    func testAuthenticationRejectionIsDefiniteButServerFailureIsUnknown() async throws {
        let fixture = try makeFixture(provider: .openAI)
        let unauthorizedTransport = RecordingProviderGenerationTransport(
            events: [
                .response(
                    ProviderGenerationHTTPMetadata(
                        statusCode: 401,
                        responseURL: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        contentType: "application/json"
                    )
                )
            ]
        )
        do {
            _ = try await collect(
                ProviderGenerationNetworkClient(
                    transport: unauthorizedTransport
                ).stream(
                    request: fixture.request,
                    verifiedConnection: fixture.verifiedConnection,
                    secret: "fixture-secret",
                    systemPrompt: "system",
                    userPrompt: fixture.intent.userRequest
                )
            )
            XCTFail("Expected authentication rejection")
        } catch {
            XCTAssertEqual(
                error as? ProviderGenerationError,
                .rejected(.authentication)
            )
        }

        let unavailableTransport = RecordingProviderGenerationTransport(
            events: [
                .response(
                    ProviderGenerationHTTPMetadata(
                        statusCode: 503,
                        responseURL: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        contentType: "application/json"
                    )
                )
            ]
        )
        do {
            _ = try await collect(
                ProviderGenerationNetworkClient(
                    transport: unavailableTransport
                ).stream(
                    request: fixture.request,
                    verifiedConnection: fixture.verifiedConnection,
                    secret: "fixture-secret",
                    systemPrompt: "system",
                    userPrompt: fixture.intent.userRequest
                )
            )
            XCTFail("Expected unknown outcome")
        } catch {
            XCTAssertEqual(
                error as? ProviderGenerationError,
                .outcomeUnknown(.providerUnavailable)
            )
        }
    }

    func testMissingUsageOrDoneMarkerIsUnknown() async throws {
        let fixture = try makeFixture(provider: .openRouter)
        let transport = RecordingProviderGenerationTransport(
            events: [
                .response(
                    ProviderGenerationHTTPMetadata(
                        statusCode: 200,
                        responseURL: URL(string: "https://openrouter.ai/api/v1/chat/completions")!,
                        contentType: "text/event-stream"
                    )
                ),
                .event(sse(#"{"choices":[{"delta":{"content":"partial"},"finish_reason":"stop"}]}"#))
            ]
        )

        do {
            _ = try await collect(
                ProviderGenerationNetworkClient(transport: transport).stream(
                    request: fixture.request,
                    verifiedConnection: fixture.verifiedConnection,
                    secret: "fixture-secret",
                    systemPrompt: "system",
                    userPrompt: fixture.intent.userRequest
                )
            )
            XCTFail("Expected truncated stream to remain unknown")
        } catch {
            XCTAssertEqual(
                error as? ProviderGenerationError,
                .outcomeUnknown(.invalidResponse)
            )
        }
    }

    func testUnsupportedAndCustomProvidersFailBeforeTransport() async throws {
        for provider in [ModelProvider.anthropic, .gemini, .custom] {
            let fixture = try makeFixture(provider: provider)
            let transport = RecordingProviderGenerationTransport(events: [])
            do {
                _ = try await collect(
                    ProviderGenerationNetworkClient(transport: transport).stream(
                        request: fixture.request,
                        verifiedConnection: fixture.verifiedConnection,
                        secret: "fixture-secret",
                        systemPrompt: "system",
                        userPrompt: fixture.intent.userRequest
                    )
                )
                XCTFail("Expected unsupported provider")
            } catch {
                XCTAssertEqual(
                    error as? ProviderGenerationError,
                    provider == .custom
                        ? .customDestinationPinningUnavailable
                        : .unsupportedProvider
                )
            }
            let recordedRequests = await transport.requests()
            XCTAssertTrue(recordedRequests.isEmpty)
        }
    }

    private func makeFixture(
        provider: ModelProvider
    ) throws -> (
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        preparedRequest: ProviderRequestSnapshot,
        request: ProviderRequestSnapshot
    ) {
        let baseURL: URL
        switch provider {
        case .deepSeek:
            baseURL = URL(string: "https://api.deepseek.com")!
        case .openAI:
            baseURL = URL(string: "https://api.openai.com/v1")!
        case .openRouter:
            baseURL = URL(string: "https://openrouter.ai/api/v1")!
        case .anthropic:
            baseURL = URL(string: "https://api.anthropic.com")!
        case .gemini:
            baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        case .custom:
            baseURL = URL(string: "https://models.example/v1")!
        }
        let now = Date(timeIntervalSince1970: 3_000)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: UUID(),
            projectID: nil,
            branchID: nil,
            userRequest: "创建一本悬疑小说",
            createdAt: now
        )
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: provider,
            baseURL: baseURL,
            credentialID: UUID(),
            selectedModel: provider == .deepSeek ? "deepseek-chat" : "fixture-model",
            secret: "fixture-secret"
        )
        let verification = try ModelCredentialVerification(
            reference: connection.credential,
            credentialVersionProof: hash("a"),
            credentialPayloadHash: hash("b")
        )
        let verified = try VerifiedModelConnection(
            connection: connection,
            credentialVerification: verification
        )
        let prepared = try ProviderRequestLifecycle.prepare(
            requestID: UUID(),
            runID: UUID(),
            idempotencyKey: "provider.request.\(intent.id.uuidString).1",
            intent: intent,
            verifiedConnection: verified,
            responseAssetID: UUID(),
            promptManifestHash: hash("1"),
            contextManifestHash: hash("2"),
            toolCatalogManifestHash: hash("3"),
            disclosureScopeHash: hash("4"),
            requestPolicyHash: hash("5"),
            now: now
        )
        let request = try ProviderRequestLifecycle.markSending(
            prepared,
            now: now.addingTimeInterval(1)
        )
        return (intent, verified, prepared, request)
    }

    private func collect(
        _ stream: AsyncThrowingStream<ProviderGenerationEvent, Error>
    ) async throws -> [ProviderGenerationEvent] {
        var result: [ProviderGenerationEvent] = []
        for try await event in stream {
            result.append(event)
        }
        return result
    }

    private func sse(_ data: String) -> ServerSentEvent {
        ServerSentEvent(event: nil, data: data, id: nil, retryMilliseconds: nil)
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}

private struct RecordedProviderGenerationRequest: Sendable {
    let request: URLRequest
    let requestID: UUID
}

private actor RecordingProviderGenerationTransport:
    ProviderGenerationHTTPTransport
{
    private let events: [ProviderGenerationTransportEvent]
    private var recorded: [RecordedProviderGenerationRequest] = []

    init(events: [ProviderGenerationTransportEvent]) {
        self.events = events
    }

    func stream(
        _ request: URLRequest,
        requestID: UUID
    ) async -> AsyncThrowingStream<ProviderGenerationTransportEvent, Error> {
        recorded.append(
            RecordedProviderGenerationRequest(
                request: request,
                requestID: requestID
            )
        )
        let events = self.events
        return AsyncThrowingStream { continuation in
            events.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func requests() -> [RecordedProviderGenerationRequest] {
        recorded
    }
}
