import Foundation

public enum ModelSelectionSource: Equatable, Sendable {
    case discovered
    case publicCatalogAfterCredentialProbe
    case customCatalogWithoutCredentialProbe
    case manualAfterUnsupportedDiscovery(statusCode: Int)
}

public struct ModelSelection: Equatable, Sendable {
    public let discoveryID: UUID
    public let connectionID: UUID
    public let provider: ModelProvider
    public let baseURL: URL
    public let credentialBinding: ModelDiscoveryCredentialBinding
    public let modelID: String
    public let source: ModelSelectionSource

    init(
        discoveryID: UUID,
        connectionID: UUID,
        provider: ModelProvider,
        baseURL: URL,
        credentialBinding: ModelDiscoveryCredentialBinding,
        modelID: String,
        source: ModelSelectionSource
    ) {
        self.discoveryID = discoveryID
        self.connectionID = connectionID
        self.provider = provider
        self.baseURL = baseURL
        self.credentialBinding = credentialBinding
        self.modelID = modelID
        self.source = source
    }
}

public struct CredentialProvenCustomModelSelection: Equatable, Sendable {
    let selection: ModelSelection

    public var discoveryID: UUID { selection.discoveryID }
    public var connectionID: UUID { selection.connectionID }
    public var provider: ModelProvider { selection.provider }
    public var baseURL: URL { selection.baseURL }
    public var credentialBinding: ModelDiscoveryCredentialBinding {
        selection.credentialBinding
    }
    public var modelID: String { selection.modelID }
    public var source: ModelSelectionSource { selection.source }

    @_spi(ModelDiscoveryTransport)
    public init(selection: ModelSelection) throws {
        guard selection.provider == .custom else {
            throw ModelConnectionError.unverifiedModelSelection
        }
        switch selection.source {
        case .customCatalogWithoutCredentialProbe,
             .manualAfterUnsupportedDiscovery:
            self.selection = selection
        case .discovered, .publicCatalogAfterCredentialProbe:
            throw ModelConnectionError.unverifiedModelSelection
        }
    }
}

public enum ModelDiscoveryError: Error, Equatable, Sendable {
    case responseRequestMismatch
    case invalidCredentialBinding
    case unexpectedHTTPStatus
    case connectionProbeFailed
    case responseTooLarge
    case malformedResponse
    case invalidModelIdentifier
    case modelIdentifierTooLarge
    case duplicateModelIdentifier
    case tooManyModels
    case invalidPagination
    case repeatedPaginationCursor
    case nextPageEndpointMismatch
    case totalCountMismatch
    case catalogIncomplete
    case explicitSelectionRequired
    case modelNotInCatalog
    case manualEntryNotAuthorized
    case discoveryBudgetExceeded
}

public struct ModelDiscoveryScope: Equatable, Sendable {
    public let discoveryID: UUID
    public let connectionID: UUID
    public let provider: ModelProvider
    public let baseURL: URL
    public let credentialBinding: ModelDiscoveryCredentialBinding

    init(
        discoveryID: UUID,
        credentialBinding: ModelDiscoveryCredentialBinding
    ) {
        self.discoveryID = discoveryID
        connectionID = credentialBinding.connectionID
        provider = credentialBinding.provider
        baseURL = credentialBinding.baseURL
        self.credentialBinding = credentialBinding
    }
}

public struct DiscoveredModelCatalog: Equatable, Sendable {
    public let discoveryID: UUID
    public let connectionID: UUID
    public let provider: ModelProvider
    public let baseURL: URL
    public let credentialBinding: ModelDiscoveryCredentialBinding
    public let modelIDs: [String]

    fileprivate init(scope: ModelDiscoveryScope, modelIDs: [String]) {
        discoveryID = scope.discoveryID
        connectionID = scope.connectionID
        provider = scope.provider
        baseURL = scope.baseURL
        credentialBinding = scope.credentialBinding
        self.modelIDs = modelIDs
    }

    fileprivate func selectModel(_ rawModelID: String?) throws -> ModelSelection {
        guard let rawModelID else {
            throw ModelDiscoveryError.explicitSelectionRequired
        }
        let modelID = rawModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty else {
            throw ModelDiscoveryError.explicitSelectionRequired
        }
        guard modelIDs.contains(modelID) else {
            throw ModelDiscoveryError.modelNotInCatalog
        }
        let source: ModelSelectionSource
        switch provider {
        case .openRouter:
            source = .publicCatalogAfterCredentialProbe
        case .custom:
            source = .customCatalogWithoutCredentialProbe
        case .deepSeek, .anthropic, .openAI, .gemini:
            source = .discovered
        }
        return ModelSelection(
            discoveryID: discoveryID,
            connectionID: connectionID,
            provider: provider,
            baseURL: baseURL,
            credentialBinding: credentialBinding,
            modelID: modelID,
            source: source
        )
    }
}

public struct ManualModelEntryAuthorization: Equatable, Sendable {
    public let discoveryID: UUID
    public let connectionID: UUID
    public let provider: ModelProvider
    public let baseURL: URL
    public let credentialBinding: ModelDiscoveryCredentialBinding
    public let unsupportedStatusCode: Int

    fileprivate init(scope: ModelDiscoveryScope, unsupportedStatusCode: Int) {
        discoveryID = scope.discoveryID
        connectionID = scope.connectionID
        provider = scope.provider
        baseURL = scope.baseURL
        credentialBinding = scope.credentialBinding
        self.unsupportedStatusCode = unsupportedStatusCode
    }

    public func selectModel(_ rawModelID: String) throws -> ModelSelection {
        guard provider == .custom else {
            throw ModelDiscoveryError.manualEntryNotAuthorized
        }
        let modelID = rawModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty,
              modelID.utf8.count <= ModelConnection.maximumModelIdentifierUTF8Bytes,
              !ModelConnection.containsUnsafeDisplayControl(modelID) else {
            if modelID.utf8.count > ModelConnection.maximumModelIdentifierUTF8Bytes {
                throw ModelDiscoveryError.modelIdentifierTooLarge
            }
            throw ModelDiscoveryError.invalidModelIdentifier
        }
        return ModelSelection(
            discoveryID: discoveryID,
            connectionID: connectionID,
            provider: provider,
            baseURL: baseURL,
            credentialBinding: credentialBinding,
            modelID: modelID,
            source: .manualAfterUnsupportedDiscovery(
                statusCode: unsupportedStatusCode
            )
        )
    }
}

public enum ModelDiscoveryResult: Equatable, Sendable {
    case nextPage(ModelDiscoverySession)
    case complete(DiscoveredModelCatalog)
    case manualEntryAllowed(ManualModelEntryAuthorization)
}

public enum ModelDiscoveryStart: Equatable, Sendable {
    case connectionProbeRequired(ModelConnectionProbeChallenge)
    case ready(ModelDiscoverySession)
}

public struct ModelConnectionProbeChallenge: Equatable, Sendable {
    public let scope: ModelDiscoveryScope
    public let request: ModelConnectionProbePlan

    init(scope: ModelDiscoveryScope, request: ModelConnectionProbePlan) {
        self.scope = scope
        self.request = request
    }
}

public struct ModelDiscoverySession: Equatable, Sendable {
    public let scope: ModelDiscoveryScope
    public let request: ModelDiscoveryRequestPlan

    fileprivate let collectedModelIDs: [String]
    fileprivate let seenModelIDs: Set<String>
    fileprivate let seenPaginationCursors: Set<String>
    fileprivate let expectedTotalCount: Int?
    fileprivate let pagesReceived: Int
    fileprivate let receivedResponseBytes: Int

    fileprivate func withReceivedResponseBytes(
        _ receivedResponseBytes: Int
    ) -> ModelDiscoverySession {
        ModelDiscoverySession(
            scope: scope,
            request: request,
            collectedModelIDs: collectedModelIDs,
            seenModelIDs: seenModelIDs,
            seenPaginationCursors: seenPaginationCursors,
            expectedTotalCount: expectedTotalCount,
            pagesReceived: pagesReceived,
            receivedResponseBytes: receivedResponseBytes
        )
    }
}

public enum ModelDiscoveryFlow {
    public static let maximumResponseBytes = 2 * 1_024 * 1_024
    public static let maximumProbeResponseBytes = 64 * 1_024
    public static let maximumTotalResponseBytes = 8 * 1_024 * 1_024
    public static let maximumCatalogModels = 10_000
    public static let maximumCatalogPages = 16

    static let maximumPaginationCursorUTF8Bytes = 4_096
    static let pageSize = 1_000
    private static let unsupportedCustomStatuses: Set<Int> = [404, 405, 501]

    public static func start(
        discoveryID: UUID,
        credentialBinding: ModelDiscoveryCredentialBinding
    ) throws -> ModelDiscoveryStart {
        let scope = ModelDiscoveryScope(
            discoveryID: discoveryID,
            credentialBinding: credentialBinding
        )
        if let probe = try makeConnectionProbe(for: scope, sequence: 0) {
            return .connectionProbeRequired(
                ModelConnectionProbeChallenge(scope: scope, request: probe)
            )
        }
        return .ready(
            try makeSession(
                scope: scope,
                sequence: 0,
                receivedResponseBytes: 0
            )
        )
    }

    @_spi(ModelDiscoveryTransport)
    public static func validateConnectionProbe(
        _ response: ModelDiscoveryResponse,
        for challenge: ModelConnectionProbeChallenge
    ) throws -> ModelDiscoverySession {
        let probe = challenge.request
        guard response.requestIdentity == probe.identity,
              response.requestURL.absoluteString == probe.url.absoluteString else {
            throw ModelDiscoveryError.responseRequestMismatch
        }
        guard response.body.count <= probe.maximumResponseBytes else {
            throw ModelDiscoveryError.responseTooLarge
        }
        guard response.body.count <= maximumTotalResponseBytes else {
            throw ModelDiscoveryError.discoveryBudgetExceeded
        }
        guard response.statusCode == 200 else {
            throw ModelDiscoveryError.connectionProbeFailed
        }
        guard let object = try? JSONSerialization.jsonObject(with: response.body),
              let dictionary = object as? [String: Any],
              dictionary["data"] is [String: Any] else {
            throw ModelDiscoveryError.malformedResponse
        }
        return try makeSession(
            scope: challenge.scope,
            sequence: probe.identity.sequence + 1,
            receivedResponseBytes: response.body.count
        )
    }

    @_spi(ModelDiscoveryTransport)
    public static func receive(
        _ response: ModelDiscoveryResponse,
        for session: ModelDiscoverySession
    ) throws -> ModelDiscoveryResult {
        guard response.requestIdentity == session.request.identity,
              response.requestURL.absoluteString == session.request.url.absoluteString else {
            throw ModelDiscoveryError.responseRequestMismatch
        }
        guard response.body.count <= session.request.maximumResponseBytes else {
            throw ModelDiscoveryError.responseTooLarge
        }
        let (receivedResponseBytes, overflow) = session.receivedResponseBytes
            .addingReportingOverflow(response.body.count)
        guard !overflow,
              receivedResponseBytes <= maximumTotalResponseBytes else {
            throw ModelDiscoveryError.discoveryBudgetExceeded
        }
        if response.statusCode != 200 {
            if session.scope.provider == .custom,
               unsupportedCustomStatuses.contains(response.statusCode),
               session.pagesReceived == 0 {
                return .manualEntryAllowed(
                    ManualModelEntryAuthorization(
                        scope: session.scope,
                        unsupportedStatusCode: response.statusCode
                    )
                )
            }
            throw ModelDiscoveryError.unexpectedHTTPStatus
        }

        do {
            return try decode(
                response.body,
                for: session.withReceivedResponseBytes(receivedResponseBytes)
            )
        } catch let error as ModelDiscoveryError {
            throw error
        } catch {
            throw ModelDiscoveryError.malformedResponse
        }
    }

    public static func selectModel(
        _ modelID: String?,
        from result: ModelDiscoveryResult
    ) throws -> ModelSelection {
        guard case let .complete(catalog) = result else {
            throw ModelDiscoveryError.catalogIncomplete
        }
        return try catalog.selectModel(modelID)
    }

    private static func makeSession(
        scope: ModelDiscoveryScope,
        sequence: Int,
        receivedResponseBytes: Int
    ) throws -> ModelDiscoverySession {
        ModelDiscoverySession(
            scope: scope,
            request: try makeRequest(
                for: scope,
                cursor: nil,
                sequence: sequence
            ),
            collectedModelIDs: [],
            seenModelIDs: [],
            seenPaginationCursors: [],
            expectedTotalCount: nil,
            pagesReceived: 0,
            receivedResponseBytes: receivedResponseBytes
        )
    }

    private static func decode(
        _ body: Data,
        for session: ModelDiscoverySession
    ) throws -> ModelDiscoveryResult {
        switch session.scope.provider {
        case .deepSeek, .openAI, .custom:
            let page = try JSONDecoder().decode(OpenAIStylePage.self, from: body)
            return try finish(
                session: session,
                rawModelIDs: page.data.map(\.id),
                pagination: .complete
            )
        case .anthropic:
            let page = try JSONDecoder().decode(AnthropicPage.self, from: body)
            try validateAnthropicBoundaries(page)
            let cursor: PaginationCursor?
            if page.hasMore {
                guard let lastID = page.lastID else {
                    throw ModelDiscoveryError.invalidPagination
                }
                cursor = .anthropic(lastID)
            } else {
                cursor = nil
            }
            return try finish(
                session: session,
                rawModelIDs: page.data.map(\.id),
                pagination: cursor.map(PaginationDisposition.more) ?? .complete
            )
        case .gemini:
            let page = try JSONDecoder().decode(GeminiPage.self, from: body)
            let cursor = try page.nextPageToken.map(validatedPaginationCursor)
            return try finish(
                session: session,
                rawModelIDs: page.models.map(\.name),
                pagination: cursor.map {
                    .more(.gemini($0))
                } ?? .complete
            )
        case .openRouter:
            let page = try JSONDecoder().decode(OpenRouterPage.self, from: body)
            return try finishOpenRouter(page, session: session)
        }
    }

    private static func finish(
        session: ModelDiscoverySession,
        rawModelIDs: [String],
        pagination: PaginationDisposition
    ) throws -> ModelDiscoveryResult {
        let aggregate = try append(rawModelIDs, to: session)
        switch pagination {
        case .complete:
            return .complete(
                DiscoveredModelCatalog(
                    scope: session.scope,
                    modelIDs: aggregate.modelIDs
                )
            )
        case let .more(cursor):
            guard !rawModelIDs.isEmpty else {
                throw ModelDiscoveryError.invalidPagination
            }
            return try nextSession(
                from: session,
                aggregate: aggregate,
                cursor: cursor,
                expectedTotalCount: session.expectedTotalCount
            )
        }
    }

    private static func finishOpenRouter(
        _ page: OpenRouterPage,
        session: ModelDiscoverySession
    ) throws -> ModelDiscoveryResult {
        guard page.totalCount >= 0,
              page.totalCount <= maximumCatalogModels else {
            throw ModelDiscoveryError.tooManyModels
        }
        if let expected = session.expectedTotalCount,
           expected != page.totalCount {
            throw ModelDiscoveryError.totalCountMismatch
        }

        let aggregate = try append(page.data.map(\.id), to: session)
        guard aggregate.modelIDs.count <= page.totalCount else {
            throw ModelDiscoveryError.totalCountMismatch
        }
        guard let rawNext = page.links.next else {
            guard aggregate.modelIDs.count == page.totalCount else {
                throw ModelDiscoveryError.totalCountMismatch
            }
            return .complete(
                DiscoveredModelCatalog(
                    scope: session.scope,
                    modelIDs: aggregate.modelIDs
                )
            )
        }

        guard aggregate.modelIDs.count < page.totalCount else {
            throw ModelDiscoveryError.invalidPagination
        }
        guard !page.data.isEmpty else {
            throw ModelDiscoveryError.invalidPagination
        }
        let nextURL = try validatedOpenRouterNextURL(
            rawNext,
            expectedOffset: aggregate.modelIDs.count,
            firstRequestURL: try makeRequest(
                for: session.scope,
                cursor: nil,
                sequence: 0
            ).url
        )
        return try nextSession(
            from: session,
            aggregate: aggregate,
            cursor: .openRouter(nextURL),
            expectedTotalCount: page.totalCount
        )
    }

    private static func append(
        _ rawModelIDs: [String],
        to session: ModelDiscoverySession
    ) throws -> (modelIDs: [String], seenModelIDs: Set<String>) {
        guard session.collectedModelIDs.count + rawModelIDs.count <= maximumCatalogModels else {
            throw ModelDiscoveryError.tooManyModels
        }

        var newIDs: [String] = []
        newIDs.reserveCapacity(rawModelIDs.count)
        var seen = session.seenModelIDs
        for rawModelID in rawModelIDs {
            let modelID = try validatedDiscoveredModelIdentifier(rawModelID)
            guard seen.insert(modelID).inserted else {
                throw ModelDiscoveryError.duplicateModelIdentifier
            }
            newIDs.append(modelID)
        }
        return (session.collectedModelIDs + newIDs, seen)
    }

    private static func nextSession(
        from session: ModelDiscoverySession,
        aggregate: (modelIDs: [String], seenModelIDs: Set<String>),
        cursor: PaginationCursor,
        expectedTotalCount: Int?
    ) throws -> ModelDiscoveryResult {
        guard session.pagesReceived + 1 < maximumCatalogPages else {
            throw ModelDiscoveryError.discoveryBudgetExceeded
        }
        let cursorIdentity = cursor.identity
        guard !session.seenPaginationCursors.contains(cursorIdentity) else {
            throw ModelDiscoveryError.repeatedPaginationCursor
        }
        var seenCursors = session.seenPaginationCursors
        seenCursors.insert(cursorIdentity)
        let request = try makeRequest(
            for: session.scope,
            cursor: cursor,
            sequence: session.request.identity.sequence + 1
        )
        return .nextPage(
            ModelDiscoverySession(
                scope: session.scope,
                request: request,
                collectedModelIDs: aggregate.modelIDs,
                seenModelIDs: aggregate.seenModelIDs,
                seenPaginationCursors: seenCursors,
                expectedTotalCount: expectedTotalCount,
                pagesReceived: session.pagesReceived + 1,
                receivedResponseBytes: session.receivedResponseBytes
            )
        )
    }

    private static func validatedDiscoveredModelIdentifier(
        _ rawModelID: String
    ) throws -> String {
        let trimmed = rawModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == rawModelID,
              !ModelConnection.containsUnsafeDisplayControl(rawModelID) else {
            throw ModelDiscoveryError.invalidModelIdentifier
        }
        guard rawModelID.utf8.count <= ModelConnection.maximumModelIdentifierUTF8Bytes else {
            throw ModelDiscoveryError.modelIdentifierTooLarge
        }
        return rawModelID
    }

    private static func validatedPaginationCursor(_ rawCursor: String) throws -> String {
        let trimmed = rawCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == rawCursor,
              rawCursor.utf8.count <= maximumPaginationCursorUTF8Bytes,
              !ModelConnection.containsUnsafeDisplayControl(rawCursor) else {
            throw ModelDiscoveryError.invalidPagination
        }
        return rawCursor
    }

    private static func validateAnthropicBoundaries(
        _ page: AnthropicPage
    ) throws {
        if page.data.isEmpty {
            guard page.firstID == nil,
                  page.lastID == nil,
                  !page.hasMore else {
                throw ModelDiscoveryError.invalidPagination
            }
            return
        }
        guard page.firstID == page.data.first?.id,
              page.lastID == page.data.last?.id else {
            throw ModelDiscoveryError.invalidPagination
        }
    }

}

private enum PaginationDisposition {
    case complete
    case more(PaginationCursor)
}

enum PaginationCursor: Equatable {
    case anthropic(String)
    case gemini(String)
    case openRouter(URL)

    var identity: String {
        switch self {
        case let .anthropic(value):
            return "anthropic:\(value)"
        case let .gemini(value):
            return "gemini:\(value)"
        case let .openRouter(url):
            return "openRouter:\(url.absoluteString)"
        }
    }
}

private struct ModelIDPayload: Decodable {
    let id: String
}

private struct OpenAIStylePage: Decodable {
    let data: [ModelIDPayload]
}

private struct AnthropicPage: Decodable {
    let data: [ModelIDPayload]
    let hasMore: Bool
    let firstID: String?
    let lastID: String?

    private enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case firstID = "first_id"
        case lastID = "last_id"
    }
}

private struct GeminiModelPayload: Decodable {
    let name: String
}

private struct GeminiPage: Decodable {
    let models: [GeminiModelPayload]
    let nextPageToken: String?
}

private struct OpenRouterPage: Decodable {
    struct Links: Decodable {
        let next: String?
    }

    let data: [ModelIDPayload]
    let totalCount: Int
    let links: Links

    private enum CodingKeys: String, CodingKey {
        case data
        case totalCount = "total_count"
        case links
    }
}
