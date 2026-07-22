import Foundation

extension ModelDiscoveryFlow {
    static func makeRequest(
        for scope: ModelDiscoveryScope,
        cursor: PaginationCursor?,
        sequence: Int
    ) throws -> ModelDiscoveryRequestPlan {
        guard sequence >= 0 else {
            throw ModelDiscoveryError.invalidPagination
        }
        let connector = ProviderConnectorRegistry.connector(for: scope.provider)
        var components = try discoveryComponents(
            baseURL: scope.baseURL,
            discoveryPath: connector.modelDiscoveryPath
        )
        var queryItems: [URLQueryItem] = []

        switch scope.provider {
        case .deepSeek, .openAI, .custom:
            guard cursor == nil else {
                throw ModelDiscoveryError.invalidPagination
            }
        case .anthropic:
            queryItems.append(URLQueryItem(name: "limit", value: String(pageSize)))
            if let cursor {
                guard case let .anthropic(afterID) = cursor else {
                    throw ModelDiscoveryError.invalidPagination
                }
                queryItems.append(URLQueryItem(name: "after_id", value: afterID))
            }
        case .gemini:
            queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
            if let cursor {
                guard case let .gemini(pageToken) = cursor else {
                    throw ModelDiscoveryError.invalidPagination
                }
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
        case .openRouter:
            if let cursor {
                guard case let .openRouter(nextURL) = cursor,
                      let next = URLComponents(
                        url: nextURL,
                        resolvingAgainstBaseURL: false
                      ) else {
                    throw ModelDiscoveryError.invalidPagination
                }
                components = next
            } else {
                queryItems = [
                    URLQueryItem(name: "offset", value: "0"),
                    URLQueryItem(name: "limit", value: String(pageSize))
                ]
            }
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw ModelDiscoveryError.invalidPagination
        }
        return ModelDiscoveryRequestPlan(
            identity: ModelDiscoveryRequestIdentity(
                discoveryID: scope.discoveryID,
                connectionID: scope.connectionID,
                credentialBinding: scope.credentialBinding,
                sequence: sequence,
                kind: .catalogPage
            ),
            method: .get,
            url: url,
            credentialAttachment: credentialAttachment(for: scope.provider),
            additionalHeaders: additionalHeaders(for: scope.provider),
            maximumResponseBytes: maximumResponseBytes
        )
    }

    static func makeConnectionProbe(
        for scope: ModelDiscoveryScope,
        sequence: Int
    ) throws -> ModelConnectionProbePlan? {
        guard sequence >= 0 else {
            throw ModelDiscoveryError.invalidPagination
        }
        guard scope.provider == .openRouter else {
            return nil
        }
        let components = try discoveryComponents(
            baseURL: scope.baseURL,
            discoveryPath: "/key"
        )
        guard let url = components.url else {
            throw ModelDiscoveryError.invalidPagination
        }
        return ModelConnectionProbePlan(
            identity: ModelDiscoveryRequestIdentity(
                discoveryID: scope.discoveryID,
                connectionID: scope.connectionID,
                credentialBinding: scope.credentialBinding,
                sequence: sequence,
                kind: .connectionProbe
            ),
            method: .get,
            url: url,
            credentialAttachment: .bearerAuthorizationHeader,
            additionalHeaders: [:],
            maximumResponseBytes: maximumProbeResponseBytes
        )
    }

    private static func discoveryComponents(
        baseURL: URL,
        discoveryPath: String
    ) throws -> URLComponents {
        guard var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw ModelConnectionError.unsafeBaseURL
        }
        var basePath = components.percentEncodedPath
        while basePath.count > 1 && basePath.hasSuffix("/") {
            basePath.removeLast()
        }
        let suffix = discoveryPath.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        if basePath.isEmpty || basePath == "/" {
            components.percentEncodedPath = "/" + suffix
        } else {
            components.percentEncodedPath = basePath + "/" + suffix
        }
        components.queryItems = nil
        components.fragment = nil
        return components
    }

    private static func credentialAttachment(
        for provider: ModelProvider
    ) -> ModelDiscoveryCredentialAttachment {
        switch provider {
        case .deepSeek, .openAI, .custom:
            return .bearerAuthorizationHeader
        case .anthropic:
            return .header(name: "x-api-key")
        case .gemini:
            return .header(name: "x-goog-api-key")
        case .openRouter:
            // The frozen `/models` catalog is publicly readable today. Test the
            // key separately through `/key` and avoid disclosing it to this GET.
            return .none
        }
    }

    private static func additionalHeaders(
        for provider: ModelProvider
    ) -> [String: String] {
        switch provider {
        case .anthropic:
            return ["anthropic-version": "2023-06-01"]
        case .deepSeek, .openAI, .gemini, .openRouter, .custom:
            return [:]
        }
    }

    static func validatedOpenRouterNextURL(
        _ rawNext: String,
        expectedOffset: Int,
        firstRequestURL: URL
    ) throws -> URL {
        guard rawNext.utf8.count <= maximumPaginationCursorUTF8Bytes,
              !ModelConnection.containsUnsafeDisplayControl(rawNext),
              let nextURL = URL(
                string: rawNext,
                relativeTo: firstRequestURL
              )?.absoluteURL,
              let next = URLComponents(
                url: nextURL,
                resolvingAgainstBaseURL: false
              ),
              let first = URLComponents(
                url: firstRequestURL,
                resolvingAgainstBaseURL: false
              ),
              next.scheme?.lowercased() == first.scheme?.lowercased(),
              next.host?.lowercased() == first.host?.lowercased(),
              next.port == first.port,
              normalizedPath(next.percentEncodedPath)
                == normalizedPath(first.percentEncodedPath),
              next.user == nil,
              next.password == nil,
              next.fragment == nil else {
            throw ModelDiscoveryError.nextPageEndpointMismatch
        }

        let queryItems = next.queryItems ?? []
        guard queryItems.count == 2,
              queryItems.filter({ $0.name == "offset" }).count == 1,
              queryItems.filter({ $0.name == "limit" }).count == 1,
              let offsetText = queryItems.first(where: { $0.name == "offset" })?.value,
              let limitText = queryItems.first(where: { $0.name == "limit" })?.value,
              let offset = Int(offsetText),
              let limit = Int(limitText),
              offset == expectedOffset,
              (1...pageSize).contains(limit) else {
            throw ModelDiscoveryError.invalidPagination
        }
        return nextURL
    }

    private static func normalizedPath(_ path: String) -> String {
        var result = path
        while result.count > 1 && result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}
