import CangJieCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum ProviderGenerationError: Error, Equatable {
    case invalidPreparedRequest
    case unsupportedProvider
    case customDestinationPinningUnavailable
    case rejected(ProviderRequestFailure)
    case outcomeUnknown(ProviderRequestInterruption)
}

struct ProviderGenerationHTTPMetadata: Equatable, Sendable {
    let statusCode: Int
    let responseURL: URL
    let contentType: String?
}

enum ProviderGenerationTransportEvent: Equatable, Sendable {
    case response(ProviderGenerationHTTPMetadata)
    case event(ServerSentEvent)
}

enum ProviderGenerationEvent: Equatable, Sendable {
    case textDelta(String)
    case toolCallDelta(
        index: Int,
        id: String?,
        name: String?,
        argumentsFragment: String
    )
    case finished(reason: String)
    case usage(ProviderUsage)
}

protocol ProviderGenerationServing {
    func validate(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) throws

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error>

    func validate(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        prompt: ProviderGenerationPrompt
    ) throws

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        prompt: ProviderGenerationPrompt
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error>
}

extension ProviderGenerationServing {
    func validate(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) throws {}

    func validate(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        prompt: ProviderGenerationPrompt
    ) throws {
        guard prompt.isInitial else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        try validate(
            request: request,
            verifiedConnection: verifiedConnection,
            secret: secret,
            systemPrompt: prompt.systemPrompt,
            userPrompt: prompt.userPrompt
        )
    }

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        prompt: ProviderGenerationPrompt
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        guard prompt.isInitial else {
            return AsyncThrowingStream {
                $0.finish(
                    throwing: ProviderGenerationError.invalidPreparedRequest
                )
            }
        }
        return stream(
            request: request,
            verifiedConnection: verifiedConnection,
            secret: secret,
            systemPrompt: prompt.systemPrompt,
            userPrompt: prompt.userPrompt
        )
    }
}

protocol ProviderGenerationHTTPTransport: Sendable {
    func stream(
        _ request: URLRequest,
        requestID: UUID
    ) async -> AsyncThrowingStream<ProviderGenerationTransportEvent, Error>
}

private final class ProviderGenerationRedirectDelegate:
    NSObject,
    URLSessionTaskDelegate,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var didReject = false

    var rejectedRedirect: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didReject
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.lock()
        didReject = true
        lock.unlock()
        completionHandler(nil)
    }
}

struct URLSessionProviderGenerationTransport:
    ProviderGenerationHTTPTransport
{
    private static let maximumEvents = 10_000

    func stream(
        _ request: URLRequest,
        requestID: UUID
    ) async -> AsyncThrowingStream<ProviderGenerationTransportEvent, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingOldest(128)) { continuation in
            let task = Task {
#if canImport(Darwin)
                let delegate = ProviderGenerationRedirectDelegate()
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 30
                configuration.timeoutIntervalForResource = 300
                configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                configuration.urlCache = nil
                configuration.httpCookieStorage = nil
                configuration.httpShouldSetCookies = false
                let session = URLSession(
                    configuration: configuration,
                    delegate: delegate,
                    delegateQueue: nil
                )
                defer { session.invalidateAndCancel() }

                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    guard !delegate.rejectedRedirect,
                          let http = response as? HTTPURLResponse,
                          let responseURL = http.url else {
                        throw ProviderGenerationError.outcomeUnknown(
                            .invalidResponse
                        )
                    }
                    try Self.yield(
                        .response(
                            ProviderGenerationHTTPMetadata(
                                statusCode: http.statusCode,
                                responseURL: responseURL,
                                contentType: http.value(
                                    forHTTPHeaderField: "Content-Type"
                                )
                            )
                        ),
                        to: continuation
                    )

                    var parser = SSEByteParser()
                    var eventCount = 0
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        guard !delegate.rejectedRedirect else {
                            throw ProviderGenerationError.outcomeUnknown(
                                .invalidResponse
                            )
                        }
                        if let event = try parser.consume(byte: byte) {
                            eventCount += 1
                            guard eventCount <= Self.maximumEvents else {
                                throw ProviderGenerationError.outcomeUnknown(
                                    .outputLimit
                                )
                            }
                            try Self.yield(.event(event), to: continuation)
                        }
                    }
                    try Task.checkCancellation()
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(
                        throwing: ProviderGenerationError.outcomeUnknown(
                            .cancelled
                        )
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
#else
                continuation.finish(
                    throwing: ProviderGenerationError.outcomeUnknown(.network)
                )
#endif
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func yield(
        _ event: ProviderGenerationTransportEvent,
        to continuation: AsyncThrowingStream<
            ProviderGenerationTransportEvent,
            Error
        >.Continuation
    ) throws {
        switch continuation.yield(event) {
        case .enqueued:
            return
        case .dropped:
            throw ProviderGenerationError.outcomeUnknown(.outputLimit)
        case .terminated:
            throw CancellationError()
        @unknown default:
            throw ProviderGenerationError.outcomeUnknown(.outputLimit)
        }
    }
}

struct ProviderGenerationNetworkClient: Sendable {
    private static let maximumPromptUTF8Bytes = 64 * 1_024
    private static let maximumEvents = 10_000
    private static let maximumToolCalls = 8

    private let transport: any ProviderGenerationHTTPTransport

    init(
        transport: any ProviderGenerationHTTPTransport =
            URLSessionProviderGenerationTransport()
    ) {
        self.transport = transport
    }

    func validate(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) throws {
        try validate(
            request: request,
            verifiedConnection: verifiedConnection,
            secret: secret,
            prompt: .initial(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        )
    }

    func validate(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        prompt: ProviderGenerationPrompt
    ) throws {
        _ = try makeRequest(
            request: request,
            requiredPhase: .prepared,
            verifiedConnection: verifiedConnection,
            secret: secret,
            prompt: prompt
        )
    }

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        stream(
            request: request,
            verifiedConnection: verifiedConnection,
            secret: secret,
            prompt: .initial(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        )
    }

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        prompt: ProviderGenerationPrompt
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingOldest(128)) { continuation in
            let task = Task {
                do {
                    let urlRequest = try makeRequest(
                        request: request,
                        requiredPhase: .sending,
                        verifiedConnection: verifiedConnection,
                        secret: secret,
                        prompt: prompt
                    )
                    let source = await transport.stream(
                        urlRequest,
                        requestID: request.identity.requestID
                    )
                    try await consume(
                        source,
                        expectedURL: try Self.endpoint(
                            for: verifiedConnection.connection
                        ),
                        continuation: continuation
                    )
                    continuation.finish()
                } catch let error as ProviderGenerationError {
                    continuation.finish(throwing: error)
                } catch is CancellationError {
                    continuation.finish(
                        throwing: ProviderGenerationError.outcomeUnknown(
                            .cancelled
                        )
                    )
                } catch {
                    continuation.finish(
                        throwing: ProviderGenerationError.outcomeUnknown(
                            .network
                        )
                    )
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest(
        request: ProviderRequestSnapshot,
        requiredPhase: ProviderRequestPhase,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        prompt: ProviderGenerationPrompt
    ) throws -> URLRequest {
        try prompt.validate()
        guard request.phase == requiredPhase,
              Self.matches(request.identity, verifiedConnection),
              prompt.systemPrompt.utf8.count <= Self.maximumPromptUTF8Bytes,
              prompt.userPrompt.utf8.count <= Self.maximumPromptUTF8Bytes,
              prompt.isInitial == (request.identity.turnSequence == 1) else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        do {
            try ModelCredentialSecretValidator.validate(secret)
        } catch {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        let endpoint = try Self.endpoint(
            for: verifiedConnection.connection
        )
        let body: [String: Any] = [
            "messages": try Self.messages(for: prompt),
            "model": verifiedConnection.connection.selectedModel,
            "stream": true,
            "stream_options": ["include_usage": true],
            "tool_choice": "auto",
            "tools": Self.makeToolCatalog()
        ]
        guard JSONSerialization.isValidJSONObject(body) else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        var urlRequest = URLRequest(
            url: endpoint,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        urlRequest.httpMethod = "POST"
        urlRequest.httpShouldHandleCookies = false
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue(
            "Bearer \(secret)",
            forHTTPHeaderField: "Authorization"
        )
        urlRequest.httpBody = try JSONSerialization.data(
            withJSONObject: body,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return urlRequest
    }

    private static func messages(
        for prompt: ProviderGenerationPrompt
    ) throws -> [[String: Any]] {
        var messages: [[String: Any]] = [
            ["role": "system", "content": prompt.systemPrompt],
            ["role": "user", "content": prompt.userPrompt]
        ]
        guard let response = prompt.assistantResponse else {
            return messages
        }
        let calls: [[String: Any]] = try response.toolCalls.map { call in
            guard let id = call.id, let name = call.name else {
                throw ProviderGenerationError.invalidPreparedRequest
            }
            return [
                "id": id,
                "type": "function",
                "function": [
                    "name": name,
                    "arguments": call.argumentsJSON
                ]
            ]
        }
        messages.append([
            "role": "assistant",
            "content": response.text,
            "tool_calls": calls
        ])
        messages.append(contentsOf: prompt.toolResults.map { result in
            [
                "role": "tool",
                "tool_call_id": result.callID,
                "content": result.contentJSON
            ]
        })
        return messages
    }

    private func consume(
        _ source: AsyncThrowingStream<
            ProviderGenerationTransportEvent,
            Error
        >,
        expectedURL: URL,
        continuation: AsyncThrowingStream<
            ProviderGenerationEvent,
            Error
        >.Continuation
    ) async throws {
        var receivedMetadata = false
        var acceptedEvents = 0
        var sawFinish = false
        var sawUsage = false
        var sawDone = false

        do {
            for try await event in source {
                try Task.checkCancellation()
                switch event {
                case let .response(metadata):
                    guard !receivedMetadata,
                          metadata.responseURL == expectedURL else {
                        throw ProviderGenerationError.outcomeUnknown(
                            .invalidResponse
                        )
                    }
                    receivedMetadata = true
                    switch metadata.statusCode {
                    case 200:
                        guard SSEContentType.isEventStream(
                            metadata.contentType
                        ) else {
                            throw ProviderGenerationError.outcomeUnknown(
                                .invalidResponse
                            )
                        }
                    case 400, 404, 409, 422:
                        throw ProviderGenerationError.rejected(
                            .invalidRequest
                        )
                    case 401:
                        throw ProviderGenerationError.rejected(
                            .authentication
                        )
                    case 403:
                        throw ProviderGenerationError.rejected(
                            .permissionDenied
                        )
                    case 429:
                        throw ProviderGenerationError.rejected(.rateLimited)
                    case 500...599:
                        throw ProviderGenerationError.outcomeUnknown(
                            .providerUnavailable
                        )
                    default:
                        throw ProviderGenerationError.outcomeUnknown(
                            .invalidResponse
                        )
                    }
                case let .event(sse):
                    guard receivedMetadata, !sawDone else {
                        throw ProviderGenerationError.outcomeUnknown(
                            .invalidResponse
                        )
                    }
                    acceptedEvents += 1
                    guard acceptedEvents <= Self.maximumEvents else {
                        throw ProviderGenerationError.outcomeUnknown(
                            .outputLimit
                        )
                    }
                    if sse.data == "[DONE]" {
                        sawDone = true
                        continue
                    }
                    let parsed = try Self.parse(sse)
                    for parsedEvent in parsed {
                        switch parsedEvent {
                        case .finished:
                            sawFinish = true
                        case .usage:
                            sawUsage = true
                        case .textDelta, .toolCallDelta:
                            break
                        }
                        try Self.yield(parsedEvent, to: continuation)
                    }
                }
            }
        } catch let error as ProviderGenerationError {
            throw error
        } catch is CancellationError {
            throw ProviderGenerationError.outcomeUnknown(.cancelled)
        } catch {
            throw ProviderGenerationError.outcomeUnknown(.network)
        }

        guard receivedMetadata, sawFinish, sawUsage, sawDone else {
            throw ProviderGenerationError.outcomeUnknown(.invalidResponse)
        }
    }

    private static func parse(
        _ event: ServerSentEvent
    ) throws -> [ProviderGenerationEvent] {
        guard let data = event.data.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              choices.count <= 1 else {
            throw ProviderGenerationError.outcomeUnknown(.invalidResponse)
        }
        var result: [ProviderGenerationEvent] = []
        if let choice = choices.first {
            guard let delta = choice["delta"] as? [String: Any] else {
                throw ProviderGenerationError.outcomeUnknown(.invalidResponse)
            }
            if let content = delta["content"] as? String, !content.isEmpty {
                result.append(.textDelta(content))
            }
            if let calls = delta["tool_calls"] as? [[String: Any]] {
                guard calls.count <= maximumToolCalls else {
                    throw ProviderGenerationError.outcomeUnknown(.outputLimit)
                }
                for call in calls {
                    guard let index = call["index"] as? Int,
                          (0..<maximumToolCalls).contains(index),
                          let function = call["function"] as? [String: Any]
                    else {
                        throw ProviderGenerationError.outcomeUnknown(
                            .invalidResponse
                        )
                    }
                    let id = call["id"] as? String
                    let name = function["name"] as? String
                    let arguments = function["arguments"] as? String ?? ""
                    guard id?.utf8.count ?? 0 <= 512,
                          name?.utf8.count ?? 0 <= 256,
                          arguments.utf8.count
                              <= ProviderResponsePayload
                                  .maximumToolArgumentsUTF8Bytes else {
                        throw ProviderGenerationError.outcomeUnknown(
                            .outputLimit
                        )
                    }
                    result.append(
                        .toolCallDelta(
                            index: index,
                            id: id,
                            name: name,
                            argumentsFragment: arguments
                        )
                    )
                }
            }
            if let reason = choice["finish_reason"] as? String {
                guard !reason.isEmpty, reason.utf8.count <= 128 else {
                    throw ProviderGenerationError.outcomeUnknown(
                        .invalidResponse
                    )
                }
                result.append(.finished(reason: reason))
            }
        }
        if let usage = root["usage"] as? [String: Any] {
            guard let input = usage["prompt_tokens"] as? Int,
                  let output = usage["completion_tokens"] as? Int,
                  let total = usage["total_tokens"] as? Int else {
                throw ProviderGenerationError.outcomeUnknown(.invalidResponse)
            }
            let (sum, overflow) = input.addingReportingOverflow(output)
            guard input >= 0,
                  output >= 0,
                  total >= 0,
                  !overflow,
                  sum == total else {
                throw ProviderGenerationError.outcomeUnknown(.invalidResponse)
            }
            result.append(
                .usage(
                    ProviderUsage(
                        inputTokens: input,
                        outputTokens: output,
                        totalTokens: total
                    )
                )
            )
        }
        if result.isEmpty, choices.first != nil {
            return []
        }
        guard !result.isEmpty else {
            throw ProviderGenerationError.outcomeUnknown(.invalidResponse)
        }
        return result
    }

    private static func endpoint(
        for connection: ModelConnection
    ) throws -> URL {
        switch connection.provider {
        case .deepSeek, .openAI, .openRouter:
            break
        case .anthropic, .gemini:
            throw ProviderGenerationError.unsupportedProvider
        case .custom:
            throw ProviderGenerationError.customDestinationPinningUnavailable
        }
        guard var components = URLComponents(
            url: connection.baseURL,
            resolvingAgainstBaseURL: false
        ), components.query == nil, components.fragment == nil else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        var path = components.percentEncodedPath
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        components.percentEncodedPath = path + "/chat/completions"
        guard let endpoint = components.url else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        return endpoint
    }

    private static func matches(
        _ identity: ProviderRequestIdentity,
        _ verified: VerifiedModelConnection
    ) -> Bool {
        let connection = verified.connection
        let evidence = verified.credentialVerification
        return identity.connectionID == connection.id
            && identity.provider == connection.provider
            && identity.baseURL == connection.baseURL
            && identity.modelID == connection.selectedModel
            && identity.credentialID == evidence.credentialID
            && identity.credentialVersionID == evidence.versionID
            && identity.credentialVersionProof == evidence.credentialVersionProof
            && identity.credentialPayloadHash == evidence.credentialPayloadHash
            && identity.setupAuthorizationHash == evidence.setupAuthorizationHash
    }

    private static func makeToolCatalog() -> [[String: Any]] {
        [[
            "type": "function",
            "function": [
                "name": "project_create",
                "description": "Create one novel project from the current conversation.",
                "parameters": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["title", "premise"],
                    "properties": [
                        "title": ["type": "string"],
                        "premise": ["type": "string"]
                    ]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "project_status",
                "description": "Read the current project status without changing it.",
                "parameters": [
                    "type": "object",
                    "additionalProperties": false,
                    "properties": [:]
                ]
            ]
        ]]
    }

    private static func yield(
        _ event: ProviderGenerationEvent,
        to continuation: AsyncThrowingStream<
            ProviderGenerationEvent,
            Error
        >.Continuation
    ) throws {
        switch continuation.yield(event) {
        case .enqueued:
            return
        case .dropped:
            throw ProviderGenerationError.outcomeUnknown(.outputLimit)
        case .terminated:
            throw CancellationError()
        @unknown default:
            throw ProviderGenerationError.outcomeUnknown(.outputLimit)
        }
    }
}

extension ProviderGenerationNetworkClient: ProviderGenerationServing {}
