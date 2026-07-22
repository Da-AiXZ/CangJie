@_spi(ModelDiscoveryTransport) import CangJieCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum ModelDiscoveryNetworkError: Error, Equatable {
    case invalidCredential
    case invalidResponse
    case responseTooLarge
    case redirectRejected
    case destinationResolutionFailed
    case destinationAddressNotPublic
    case customDestinationPinningUnavailable
    case customAuthenticationUnavailable
    case customAuthenticationEvidenceMismatch
    case customSelectionNotCredentialProven
    case discoveryDeadlineExceeded
}

enum ModelDiscoveryCustomDestinationCapability: Equatable, Sendable {
    case unavailable
    case verifiedAddressSet
}

struct ModelDiscoveryVerifiedDestination: Equatable, Sendable {
    let host: String
    let port: Int
    let addresses: Set<ModelDiscoveryResolvedAddress>
}

struct ModelDiscoveryAuthenticatedConnectionEvidence: Equatable, Sendable {
    let requestIdentity: ModelDiscoveryRequestIdentity
    let requestURL: URL
    let credentialBinding: ModelDiscoveryCredentialBinding
    let verifiedDestination: ModelDiscoveryVerifiedDestination
}

struct ModelDiscoveryTransportResponse: Equatable, Sendable {
    let requestIdentity: ModelDiscoveryRequestIdentity
    let requestURL: URL
    let statusCode: Int
    let body: Data
}

struct ModelDiscoveryNetworkResult: Sendable {
    let discoveryResult: ModelDiscoveryResult
    private let authenticatedCustomEvidence:
        ModelDiscoveryAuthenticatedConnectionEvidence?

    fileprivate init(
        discoveryResult: ModelDiscoveryResult,
        authenticatedCustomEvidence: ModelDiscoveryAuthenticatedConnectionEvidence?
    ) {
        self.discoveryResult = discoveryResult
        self.authenticatedCustomEvidence = authenticatedCustomEvidence
    }

    func credentialProvenCustomSelection(
        _ rawModelID: String
    ) throws -> CredentialProvenCustomModelSelection {
        guard let authenticatedCustomEvidence else {
            throw ModelDiscoveryNetworkError.customSelectionNotCredentialProven
        }

        let selection: ModelSelection
        switch discoveryResult {
        case .nextPage:
            throw ModelDiscoveryNetworkError.customSelectionNotCredentialProven
        case .complete:
            selection = try ModelDiscoveryFlow.selectModel(
                rawModelID,
                from: discoveryResult
            )
        case let .manualEntryAllowed(authorization):
            selection = try authorization.selectModel(rawModelID)
        }
        guard selection.provider == .custom,
              selection.discoveryID
                == authenticatedCustomEvidence.requestIdentity.discoveryID,
              selection.connectionID
                == authenticatedCustomEvidence.requestIdentity.connectionID,
              selection.credentialBinding
                == authenticatedCustomEvidence.requestIdentity.credentialBinding,
              selection.credentialBinding
                == authenticatedCustomEvidence.credentialBinding else {
            throw ModelDiscoveryNetworkError.customSelectionNotCredentialProven
        }
        return try CredentialProvenCustomModelSelection(selection: selection)
    }
}

protocol ModelDiscoveryHTTPTransport: Sendable {
    var customDestinationCapability: ModelDiscoveryCustomDestinationCapability { get }

    func authenticateCustomConnection(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination
    ) async throws -> ModelDiscoveryAuthenticatedConnectionEvidence?

    func send(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination?
    ) async throws -> ModelDiscoveryTransportResponse
}

protocol ModelDiscoveryHostResolver: Sendable {
    func resolve(host: String, port: Int) throws -> Set<ModelDiscoveryResolvedAddress>
}

protocol ModelDiscoveryMonotonicClock: Sendable {
    func now() -> TimeInterval
    func sleep(for duration: TimeInterval) async throws
}

struct SystemModelDiscoveryMonotonicClock: ModelDiscoveryMonotonicClock {
    func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    func sleep(for duration: TimeInterval) async throws {
        let nanoseconds = UInt64(duration * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

struct ModelDiscoveryNetworkClient: Sendable {
    private let transport: any ModelDiscoveryHTTPTransport
    private let resolver: any ModelDiscoveryHostResolver
    private let clock: any ModelDiscoveryMonotonicClock
    private let maximumDiscoveryDuration: TimeInterval
    private let maximumRequestDuration: TimeInterval

    init(
        transport: any ModelDiscoveryHTTPTransport = URLSessionModelDiscoveryTransport(),
        resolver: any ModelDiscoveryHostResolver = SystemModelDiscoveryHostResolver(),
        clock: any ModelDiscoveryMonotonicClock = SystemModelDiscoveryMonotonicClock(),
        maximumDiscoveryDuration: TimeInterval = 120,
        maximumRequestDuration: TimeInterval = 30
    ) {
        precondition(maximumDiscoveryDuration > 0 && maximumDiscoveryDuration.isFinite)
        precondition(maximumRequestDuration > 0 && maximumRequestDuration.isFinite)
        self.transport = transport
        self.resolver = resolver
        self.clock = clock
        self.maximumDiscoveryDuration = maximumDiscoveryDuration
        self.maximumRequestDuration = maximumRequestDuration
    }

    func discover(
        _ attempt: ModelDiscoveryAttempt
    ) async throws -> ModelDiscoveryNetworkResult {
        let startedAt = clock.now()
        guard startedAt.isFinite,
              startedAt <= TimeInterval.greatestFiniteMagnitude - maximumDiscoveryDuration else {
            throw ModelDiscoveryNetworkError.discoveryDeadlineExceeded
        }
        let deadline = startedAt + maximumDiscoveryDuration
        var session: ModelDiscoverySession

        switch attempt.start {
        case let .ready(readySession):
            session = readySession
        case let .connectionProbeRequired(challenge):
            let response = try await send(
                challenge.request,
                scope: challenge.scope,
                secret: attempt.secret,
                deadline: deadline
            )
            session = try ModelDiscoveryFlow.validateConnectionProbe(
                coreResponse(from: response),
                for: challenge
            )
        }

        while true {
            let exchange = try await send(
                session.request,
                scope: session.scope,
                secret: attempt.secret,
                deadline: deadline
            )
            let result = try ModelDiscoveryFlow.receive(
                coreResponse(from: exchange.response),
                for: session
            )
            switch result {
            case let .nextPage(next):
                session = next
            case .complete, .manualEntryAllowed:
                return ModelDiscoveryNetworkResult(
                    discoveryResult: result,
                    authenticatedCustomEvidence: session.scope.provider == .custom
                        ? exchange.authenticatedCustomEvidence
                        : nil
                )
            }
        }
    }

    private struct CatalogTransportExchange: Sendable {
        let response: ModelDiscoveryTransportResponse
        let authenticatedCustomEvidence:
            ModelDiscoveryAuthenticatedConnectionEvidence?
    }

    private func send(
        _ plan: ModelDiscoveryRequestPlan,
        scope: ModelDiscoveryScope,
        secret: String,
        deadline: TimeInterval
    ) async throws -> CatalogTransportExchange {
        _ = try remainingDuration(until: deadline)
        let verifiedDestination = try verifiedDestination(
            for: scope.provider,
            url: plan.url
        )
        let authenticatedCustomEvidence: ModelDiscoveryAuthenticatedConnectionEvidence?
        if scope.provider == .custom {
            guard let verifiedDestination else {
                throw ModelDiscoveryNetworkError.customDestinationPinningUnavailable
            }
            authenticatedCustomEvidence = try await authenticateCustomConnection(
                identity: plan.identity,
                url: plan.url,
                method: plan.method,
                credentialAttachment: plan.credentialAttachment,
                additionalHeaders: plan.additionalHeaders,
                maximumResponseBytes: plan.maximumResponseBytes,
                scope: scope,
                secret: secret,
                verifiedDestination: verifiedDestination,
                deadline: deadline
            )
        } else {
            authenticatedCustomEvidence = nil
        }
        let response = try await send(
            identity: plan.identity,
            url: plan.url,
            method: plan.method,
            credentialAttachment: plan.credentialAttachment,
            additionalHeaders: plan.additionalHeaders,
            maximumResponseBytes: plan.maximumResponseBytes,
            scope: scope,
            secret: secret,
            verifiedDestination: verifiedDestination,
            deadline: deadline
        )
        return CatalogTransportExchange(
            response: response,
            authenticatedCustomEvidence: authenticatedCustomEvidence
        )
    }

    private func send(
        _ plan: ModelConnectionProbePlan,
        scope: ModelDiscoveryScope,
        secret: String,
        deadline: TimeInterval
    ) async throws -> ModelDiscoveryTransportResponse {
        _ = try remainingDuration(until: deadline)
        let verifiedDestination = try verifiedDestination(
            for: scope.provider,
            url: plan.url
        )
        return try await send(
            identity: plan.identity,
            url: plan.url,
            method: plan.method,
            credentialAttachment: plan.credentialAttachment,
            additionalHeaders: plan.additionalHeaders,
            maximumResponseBytes: plan.maximumResponseBytes,
            scope: scope,
            secret: secret,
            verifiedDestination: verifiedDestination,
            deadline: deadline
        )
    }

    private func send(
        identity: ModelDiscoveryRequestIdentity,
        url: URL,
        method: ModelDiscoveryHTTPMethod,
        credentialAttachment: ModelDiscoveryCredentialAttachment,
        additionalHeaders: [String: String],
        maximumResponseBytes: Int,
        scope: ModelDiscoveryScope,
        secret: String,
        verifiedDestination: ModelDiscoveryVerifiedDestination?,
        deadline: TimeInterval
    ) async throws -> ModelDiscoveryTransportResponse {
        let remaining = try remainingDuration(until: deadline)
        let request = try authorizedRequest(
            url: url,
            method: method,
            credentialAttachment: credentialAttachment,
            additionalHeaders: additionalHeaders,
            secret: secret,
            timeoutInterval: min(maximumRequestDuration, remaining)
        )
        return try await sendWithDeadline(
            request,
            identity: identity,
            maximumResponseBytes: maximumResponseBytes,
            verifiedDestination: verifiedDestination,
            allowedDuration: min(maximumRequestDuration, remaining)
        )
    }

    private func authenticateCustomConnection(
        identity: ModelDiscoveryRequestIdentity,
        url: URL,
        method: ModelDiscoveryHTTPMethod,
        credentialAttachment: ModelDiscoveryCredentialAttachment,
        additionalHeaders: [String: String],
        maximumResponseBytes: Int,
        scope: ModelDiscoveryScope,
        secret: String,
        verifiedDestination: ModelDiscoveryVerifiedDestination,
        deadline: TimeInterval
    ) async throws -> ModelDiscoveryAuthenticatedConnectionEvidence? {
        let remaining = try remainingDuration(until: deadline)
        let request = try authorizedRequest(
            url: url,
            method: method,
            credentialAttachment: credentialAttachment,
            additionalHeaders: additionalHeaders,
            secret: secret,
            timeoutInterval: min(maximumRequestDuration, remaining)
        )
        let evidence = try await authenticateWithDeadline(
            request,
            identity: identity,
            maximumResponseBytes: maximumResponseBytes,
            verifiedDestination: verifiedDestination,
            allowedDuration: min(maximumRequestDuration, remaining)
        )
        guard let evidence else {
            return nil
        }
        guard evidence.requestIdentity == identity,
              evidence.requestURL.absoluteString == url.absoluteString,
              evidence.credentialBinding == scope.credentialBinding,
              evidence.verifiedDestination == verifiedDestination else {
            throw ModelDiscoveryNetworkError.customAuthenticationEvidenceMismatch
        }
        return evidence
    }

    private func authenticateWithDeadline(
        _ request: URLRequest,
        identity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination,
        allowedDuration: TimeInterval
    ) async throws -> ModelDiscoveryAuthenticatedConnectionEvidence? {
        try await withThrowingTaskGroup(
            of: ModelDiscoveryAuthenticatedConnectionEvidence?.self
        ) { group in
            group.addTask {
                try await transport.authenticateCustomConnection(
                    request,
                    requestIdentity: identity,
                    maximumResponseBytes: maximumResponseBytes,
                    verifiedDestination: verifiedDestination
                )
            }
            group.addTask {
                try await clock.sleep(for: allowedDuration)
                try Task.checkCancellation()
                throw ModelDiscoveryNetworkError.discoveryDeadlineExceeded
            }
            defer { group.cancelAll() }
            guard let evidence = try await group.next() else {
                throw ModelDiscoveryNetworkError.invalidResponse
            }
            return evidence
        }
    }

    private func sendWithDeadline(
        _ request: URLRequest,
        identity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination?,
        allowedDuration: TimeInterval
    ) async throws -> ModelDiscoveryTransportResponse {
        try await withThrowingTaskGroup(
            of: ModelDiscoveryTransportResponse.self
        ) { group in
            group.addTask {
                try await transport.send(
                    request,
                    requestIdentity: identity,
                    maximumResponseBytes: maximumResponseBytes,
                    verifiedDestination: verifiedDestination
                )
            }
            group.addTask {
                try await clock.sleep(for: allowedDuration)
                try Task.checkCancellation()
                throw ModelDiscoveryNetworkError.discoveryDeadlineExceeded
            }
            defer { group.cancelAll() }
            guard let response = try await group.next() else {
                throw ModelDiscoveryNetworkError.invalidResponse
            }
            return response
        }
    }

    private func authorizedRequest(
        url: URL,
        method: ModelDiscoveryHTTPMethod,
        credentialAttachment: ModelDiscoveryCredentialAttachment,
        additionalHeaders: [String: String],
        secret: String,
        timeoutInterval: TimeInterval
    ) throws -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeoutInterval
        )
        request.httpMethod = method.rawValue
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }
        switch credentialAttachment {
        case .none:
            break
        case .bearerAuthorizationHeader:
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        case let .header(name):
            request.setValue(secret, forHTTPHeaderField: name)
        }
        guard request.url == url else {
            throw ModelDiscoveryNetworkError.invalidResponse
        }
        return request
    }

    private func verifiedDestination(
        for provider: ModelProvider,
        url: URL
    ) throws -> ModelDiscoveryVerifiedDestination? {
        guard provider == .custom else {
            return nil
        }
        guard transport.customDestinationCapability == .verifiedAddressSet else {
            throw ModelDiscoveryNetworkError.customDestinationPinningUnavailable
        }
        guard let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ), let host = components.host else {
            throw ModelDiscoveryNetworkError.destinationResolutionFailed
        }
        let port = components.port ?? 443
        let addresses = try publicAddresses(host: host, port: port)
        return ModelDiscoveryVerifiedDestination(
            host: host.lowercased(),
            port: port,
            addresses: addresses
        )
    }

    private func publicAddresses(
        host: String,
        port: Int
    ) throws -> Set<ModelDiscoveryResolvedAddress> {
        let addresses: Set<ModelDiscoveryResolvedAddress>
        do {
            addresses = try resolver.resolve(host: host, port: port)
        } catch {
            throw ModelDiscoveryNetworkError.destinationResolutionFailed
        }
        guard !addresses.isEmpty else {
            throw ModelDiscoveryNetworkError.destinationResolutionFailed
        }
        guard addresses.allSatisfy(\.isPublic) else {
            throw ModelDiscoveryNetworkError.destinationAddressNotPublic
        }
        return addresses
    }

    private func remainingDuration(
        until deadline: TimeInterval
    ) throws -> TimeInterval {
        let now = clock.now()
        let remaining = deadline - now
        guard now.isFinite,
              remaining.isFinite,
              remaining > 0 else {
            throw ModelDiscoveryNetworkError.discoveryDeadlineExceeded
        }
        return remaining
    }

    private func coreResponse(
        from response: ModelDiscoveryTransportResponse
    ) -> ModelDiscoveryResponse {
        ModelDiscoveryResponse(
            requestIdentity: response.requestIdentity,
            requestURL: response.requestURL,
            statusCode: response.statusCode,
            body: response.body
        )
    }
}
