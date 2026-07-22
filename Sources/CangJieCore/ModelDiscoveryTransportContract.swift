import Foundation

public enum ModelDiscoveryHTTPMethod: String, Equatable, Sendable {
    case get = "GET"
}

public enum ModelDiscoveryCredentialAttachment: Equatable, Sendable {
    case none
    case bearerAuthorizationHeader
    case header(name: String)
}

public enum ModelDiscoveryRequestKind: Hashable, Sendable {
    case connectionProbe
    case catalogPage
}

public struct ModelDiscoveryCredentialBinding: Hashable, Sendable {
    public let credentialID: UUID
    public let connectionID: UUID
    public let provider: ModelProvider
    public let baseURL: URL
    public let versionID: UUID
    public let versionProof: String

    @_spi(ModelDiscoveryCredentialBinding)
    public init(
        credentialID: UUID,
        connectionID: UUID,
        provider: ModelProvider,
        baseURL: URL,
        versionID: UUID,
        versionProof: String
    ) throws {
        guard versionProof.utf8.count == 64,
              versionProof.unicodeScalars.allSatisfy({ scalar in
                switch scalar.value {
                case 0x30...0x39, 0x61...0x66:
                    return true
                default:
                    return false
                }
              }) else {
            throw ModelDiscoveryError.invalidCredentialBinding
        }
        self.credentialID = credentialID
        self.connectionID = connectionID
        self.provider = provider
        self.baseURL = try ModelConnection.validatedBaseURL(
            provider: provider,
            baseURL: baseURL
        )
        self.versionID = versionID
        self.versionProof = versionProof
    }
}

public struct ModelDiscoveryRequestIdentity: Hashable, Sendable {
    public let discoveryID: UUID
    public let connectionID: UUID
    public let credentialBinding: ModelDiscoveryCredentialBinding
    public let sequence: Int
    public let kind: ModelDiscoveryRequestKind

    init(
        discoveryID: UUID,
        connectionID: UUID,
        credentialBinding: ModelDiscoveryCredentialBinding,
        sequence: Int,
        kind: ModelDiscoveryRequestKind
    ) {
        self.discoveryID = discoveryID
        self.connectionID = connectionID
        self.credentialBinding = credentialBinding
        self.sequence = sequence
        self.kind = kind
    }
}

public struct ModelDiscoveryRequestPlan: Equatable, Sendable {
    public let identity: ModelDiscoveryRequestIdentity
    public let method: ModelDiscoveryHTTPMethod
    public let url: URL
    public let credentialAttachment: ModelDiscoveryCredentialAttachment
    public let additionalHeaders: [String: String]
    public let maximumResponseBytes: Int

    init(
        identity: ModelDiscoveryRequestIdentity,
        method: ModelDiscoveryHTTPMethod,
        url: URL,
        credentialAttachment: ModelDiscoveryCredentialAttachment,
        additionalHeaders: [String: String],
        maximumResponseBytes: Int
    ) {
        self.identity = identity
        self.method = method
        self.url = url
        self.credentialAttachment = credentialAttachment
        self.additionalHeaders = additionalHeaders
        self.maximumResponseBytes = maximumResponseBytes
    }
}

public struct ModelConnectionProbePlan: Equatable, Sendable {
    public let identity: ModelDiscoveryRequestIdentity
    public let method: ModelDiscoveryHTTPMethod
    public let url: URL
    public let credentialAttachment: ModelDiscoveryCredentialAttachment
    public let additionalHeaders: [String: String]
    public let maximumResponseBytes: Int

    init(
        identity: ModelDiscoveryRequestIdentity,
        method: ModelDiscoveryHTTPMethod,
        url: URL,
        credentialAttachment: ModelDiscoveryCredentialAttachment,
        additionalHeaders: [String: String],
        maximumResponseBytes: Int
    ) {
        self.identity = identity
        self.method = method
        self.url = url
        self.credentialAttachment = credentialAttachment
        self.additionalHeaders = additionalHeaders
        self.maximumResponseBytes = maximumResponseBytes
    }
}

public struct ModelDiscoveryResponse: Equatable, Sendable {
    public let requestIdentity: ModelDiscoveryRequestIdentity
    public let requestURL: URL
    public let statusCode: Int
    public let body: Data

    @_spi(ModelDiscoveryTransport)
    public init(
        requestIdentity: ModelDiscoveryRequestIdentity,
        requestURL: URL,
        statusCode: Int,
        body: Data
    ) {
        self.requestIdentity = requestIdentity
        self.requestURL = requestURL
        self.statusCode = statusCode
        self.body = body
    }
}
