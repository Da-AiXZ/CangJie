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
        XCTAssertEqual(json["max_tokens"] as? Int, 4_096)
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual((json["tools"] as? [[String: Any]])?.count, 5)
        XCTAssertFalse(
            try XCTUnwrap(String(data: body, encoding: .utf8))
                .contains("fixture-secret")
        )
    }

    func testLegacyCatalogManifestSendsOnlyLegacyTools() async throws {
        let fixture = try makeFixture(
            provider: .openAI,
            toolCatalogVersion: .v1,
            requestPolicyVersion: .v1
        )
        let transport = RecordingProviderGenerationTransport(
            events: [
                .response(
                    ProviderGenerationHTTPMetadata(
                        statusCode: 200,
                        responseURL: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        contentType: "text/event-stream"
                    )
                ),
                .event(sse(#"{"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}"#)),
                .event(sse(#"{"choices":[],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}"#)),
                .event(sse("[DONE]"))
            ]
        )

        _ = try await collect(
            ProviderGenerationNetworkClient(transport: transport).stream(
                request: fixture.request,
                verifiedConnection: fixture.verifiedConnection,
                secret: "fixture-secret",
                systemPrompt: "system",
                userPrompt: fixture.intent.userRequest
            )
        )

        let recordedRequests = await transport.requests()
        let recorded = try XCTUnwrap(recordedRequests.first)
        let body = try XCTUnwrap(recorded.request.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let tools = try XCTUnwrap(json["tools"] as? [[String: Any]])
        XCTAssertNil(json["max_tokens"])
        let names = try tools.map { tool in
            try XCTUnwrap(
                (tool["function"] as? [String: Any])?["name"] as? String
            )
        }
        XCTAssertEqual(names, ["project_create", "project_status"])
    }

    func testCurrentCatalogSendsOnlyGovernedProjectTools() async throws {
        let fixture = try makeFixture(
            provider: .openAI,
            toolCatalogVersion: .v3
        )
        let transport = RecordingProviderGenerationTransport(
            events: [
                .response(
                    ProviderGenerationHTTPMetadata(
                        statusCode: 200,
                        responseURL: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        contentType: "text/event-stream"
                    )
                ),
                .event(sse(#"{"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}"#)),
                .event(sse(#"{"choices":[],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}"#)),
                .event(sse("[DONE]"))
            ]
        )

        _ = try await collect(
            ProviderGenerationNetworkClient(transport: transport).stream(
                request: fixture.request,
                verifiedConnection: fixture.verifiedConnection,
                secret: "fixture-secret",
                systemPrompt: "system",
                userPrompt: fixture.intent.userRequest
            )
        )

        let recordedRequests = await transport.requests()
        let recorded = try XCTUnwrap(recordedRequests.first)
        let body = try XCTUnwrap(recorded.request.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let tools = try XCTUnwrap(json["tools"] as? [[String: Any]])
        let names = try tools.map { tool in
            try XCTUnwrap(
                (tool["function"] as? [String: Any])?["name"] as? String
            )
        }
        XCTAssertEqual(
            names,
            ["project_create", "project_list", "project_status"]
        )
        XCTAssertFalse(names.contains("project_switch"))
        XCTAssertFalse(names.contains("project_save_discussion"))
        let createFunction = try XCTUnwrap(
            (tools.first?["function"] as? [String: Any])
        )
        let parameters = try XCTUnwrap(
            createFunction["parameters"] as? [String: Any]
        )
        let properties = try XCTUnwrap(
            parameters["properties"] as? [String: [String: Any]]
        )
        for name in ["title", "premise"] {
            let description = try XCTUnwrap(
                properties[name]?["description"] as? String
            )
            XCTAssertTrue(description.contains("exact"))
            XCTAssertTrue(description.contains("do not"))
        }
    }

    func testUnknownCatalogManifestFailsBeforeTransport() async throws {
        let fixture = try makeFixture(
            provider: .openAI,
            toolCatalogManifestHash: hash("3")
        )
        let transport = RecordingProviderGenerationTransport(events: [])
        let client = ProviderGenerationNetworkClient(transport: transport)

        XCTAssertThrowsError(
            try client.validate(
                request: fixture.preparedRequest,
                verifiedConnection: fixture.verifiedConnection,
                secret: "fixture-secret",
                systemPrompt: "system",
                userPrompt: fixture.intent.userRequest
            )
        ) { error in
            XCTAssertEqual(
                error as? ProviderGenerationError,
                .invalidPreparedRequest
            )
        }
        let recordedRequests = await transport.requests()
        XCTAssertTrue(recordedRequests.isEmpty)
    }

    func testContinuationRequestCarriesExactAssistantCallAndToolResult() async throws {
        let fixture = try makeFixture(provider: .openAI)
        let transport = RecordingProviderGenerationTransport(
            events: [
                .response(
                    ProviderGenerationHTTPMetadata(
                        statusCode: 200,
                        responseURL: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        contentType: "text/event-stream"
                    )
                ),
                .event(sse(#"{"choices":[{"delta":{"content":"完成"},"finish_reason":"stop"}]}"#)),
                .event(sse(#"{"choices":[],"usage":{"prompt_tokens":20,"completion_tokens":2,"total_tokens":22}}"#)),
                .event(sse("[DONE]"))
            ]
        )
        let client = ProviderGenerationNetworkClient(transport: transport)
        let response = ProviderResponsePayload(
            text: "",
            toolCalls: [
                ProviderToolCallPayload(
                    index: 0,
                    id: "call-1",
                    name: "project_status",
                    argumentsJSON: "{}"
                )
            ],
            finishReason: "tool_calls"
        )
        let resultJSON = #"{"receiptID":"receipt-1","status":"noCurrentProject"}"#
        let prompt = try ProviderGenerationPrompt.continuation(
            systemPrompt: "You are CangJie.",
            userPrompt: fixture.intent.userRequest,
            assistantResponse: response,
            toolResults: [
                ProviderGenerationToolResult(
                    callID: "call-1",
                    callIndex: 0,
                    contentJSON: resultJSON
                )
            ],
            allowsToolCalls: false
        )
        let preparedContinuation = try ProviderRequestLifecycle.prepare(
            requestID: UUID(),
            runID: fixture.request.identity.runID,
            idempotencyKey: "provider.request.continuation",
            attemptNumber: 1,
            turnSequence: 2,
            previousRequestID: fixture.request.identity.requestID,
            intent: fixture.intent,
            verifiedConnection: fixture.verifiedConnection,
            responseAssetID: UUID(),
            promptManifestHash: hash("6"),
            contextManifestHash: hash("2"),
            toolCatalogManifestHash: fixture.request.toolCatalogManifestHash,
            disclosureScopeHash: hash("4"),
            requestPolicyHash: fixture.request.requestPolicyHash,
            now: fixture.request.updatedAt
        )
        let continuationRequest = try ProviderRequestLifecycle.markSending(
            preparedContinuation,
            now: fixture.request.updatedAt.addingTimeInterval(1)
        )

        _ = try await collect(
            client.stream(
                request: continuationRequest,
                verifiedConnection: fixture.verifiedConnection,
                secret: "fixture-secret",
                prompt: prompt
            )
        )

        let recordedRequests = await transport.requests()
        let recorded = try XCTUnwrap(recordedRequests.first)
        let body = try XCTUnwrap(recorded.request.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.map { $0["role"] as? String }, [
            "system", "user", "assistant", "tool"
        ])
        let assistantCalls = try XCTUnwrap(
            messages[2]["tool_calls"] as? [[String: Any]]
        )
        XCTAssertEqual(assistantCalls.first?["id"] as? String, "call-1")
        let function = try XCTUnwrap(
            assistantCalls.first?["function"] as? [String: Any]
        )
        XCTAssertEqual(function["name"] as? String, "project_status")
        XCTAssertEqual(function["arguments"] as? String, "{}")
        XCTAssertEqual(messages[3]["tool_call_id"] as? String, "call-1")
        XCTAssertEqual(messages[3]["content"] as? String, resultJSON)
        XCTAssertEqual(json["tool_choice"] as? String, "none")
        XCTAssertNil(json["tools"])
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
        provider: ModelProvider,
        toolCatalogVersion: ProviderToolCatalogVersion = .v2,
        toolCatalogManifestHash: String? = nil,
        requestPolicyVersion: ProviderRequestPolicyVersion = .v2
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
            toolCatalogManifestHash: toolCatalogManifestHash
                ?? toolCatalogVersion.manifestHash,
            disclosureScopeHash: hash("4"),
            requestPolicyHash: requestPolicyVersion.manifestHash(
                provider: connection.provider,
                baseURL: connection.baseURL,
                modelID: connection.selectedModel
            ),
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
