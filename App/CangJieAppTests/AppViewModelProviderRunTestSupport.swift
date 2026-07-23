@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
@testable import CangJie

final class AppViewModelProviderGenerationService:
    ProviderGenerationServing
{
    private let events: [ProviderGenerationEvent]
    private let hangsAfterEvents: Bool
    private(set) var callCount = 0

    init(
        events: [ProviderGenerationEvent],
        hangsAfterEvents: Bool = false
    ) {
        self.events = events
        self.hangsAfterEvents = hangsAfterEvents
    }

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        callCount += 1
        return AsyncThrowingStream { continuation in
            events.forEach { continuation.yield($0) }
            guard hangsAfterEvents else {
                continuation.finish()
                return
            }
            let task = Task {
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(nanoseconds: 10_000_000)
                    }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: CancellationError())
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

final class FIFOAppViewModelProviderGenerationService:
    ProviderGenerationServing
{
    private var firstContinuation:
        AsyncThrowingStream<ProviderGenerationEvent, Error>.Continuation?
    private(set) var callCount = 0

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        callCount += 1
        if callCount == 1 {
            return AsyncThrowingStream { continuation in
                firstContinuation = continuation
                continuation.yield(.textDelta("第一件事正在处理。"))
            }
        }
        return AsyncThrowingStream { continuation in
            continuation.yield(.textDelta("第二件事已经处理。"))
            continuation.yield(.finished(reason: "stop"))
            continuation.yield(
                .usage(
                    ProviderUsage(
                        inputTokens: 4,
                        outputTokens: 4,
                        totalTokens: 8
                    )
                )
            )
            continuation.finish()
        }
    }

    func finishFirstRequest() {
        firstContinuation?.yield(.finished(reason: "stop"))
        firstContinuation?.yield(
            .usage(
                ProviderUsage(
                    inputTokens: 5,
                    outputTokens: 5,
                    totalTokens: 10
                )
            )
        )
        firstContinuation?.finish()
        firstContinuation = nil
    }
}

@MainActor
final class TestNetworkAvailabilityObserver:
    NetworkAvailabilityObserving
{
    private(set) var state: NetworkAvailabilityState
    private var handler: ((NetworkAvailabilityState) -> Void)?

    init(state: NetworkAvailabilityState) {
        self.state = state
    }

    func start(
        _ handler: @escaping (NetworkAvailabilityState) -> Void
    ) {
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    func update(_ state: NetworkAvailabilityState) {
        self.state = state
        handler?(state)
    }
}
