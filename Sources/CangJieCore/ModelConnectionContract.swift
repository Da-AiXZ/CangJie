import Foundation

public enum ModelProvider: String, CaseIterable, Codable, Sendable {
    case deepSeek
    case anthropic
    case openAI
    case gemini
    case openRouter
    case custom
}

public struct ProviderConnector: Equatable, Sendable {
    public let provider: ModelProvider
    public let displayName: String
    public let defaultBaseURL: URL?
    public let modelDiscoveryPath: String
    public let allowsManualModelFallback: Bool

    public init(
        provider: ModelProvider,
        displayName: String,
        defaultBaseURL: URL?,
        modelDiscoveryPath: String,
        allowsManualModelFallback: Bool
    ) {
        self.provider = provider
        self.displayName = displayName
        self.defaultBaseURL = defaultBaseURL
        self.modelDiscoveryPath = modelDiscoveryPath
        self.allowsManualModelFallback = allowsManualModelFallback
    }
}

public enum ProviderConnectorRegistry {
    private static let deepSeek = ProviderConnector(
        provider: .deepSeek,
        displayName: "DeepSeek",
        defaultBaseURL: URL(string: "https://api.deepseek.com")!,
        modelDiscoveryPath: "/models",
        allowsManualModelFallback: false
    )

    private static let anthropic = ProviderConnector(
        provider: .anthropic,
        displayName: "Claude / Anthropic",
        defaultBaseURL: URL(string: "https://api.anthropic.com")!,
        modelDiscoveryPath: "/v1/models",
        allowsManualModelFallback: false
    )

    private static let openAI = ProviderConnector(
        provider: .openAI,
        displayName: "GPT / OpenAI",
        defaultBaseURL: URL(string: "https://api.openai.com/v1")!,
        modelDiscoveryPath: "/models",
        allowsManualModelFallback: false
    )

    private static let gemini = ProviderConnector(
        provider: .gemini,
        displayName: "Gemini",
        defaultBaseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
        modelDiscoveryPath: "/models",
        allowsManualModelFallback: false
    )

    private static let openRouter = ProviderConnector(
        provider: .openRouter,
        displayName: "OpenRouter",
        defaultBaseURL: URL(string: "https://openrouter.ai/api/v1")!,
        modelDiscoveryPath: "/models",
        allowsManualModelFallback: false
    )

    public static let officialConnectors: [ProviderConnector] = [
        deepSeek,
        anthropic,
        openAI,
        gemini,
        openRouter
    ]

    public static let customConnector = ProviderConnector(
        provider: .custom,
        displayName: "Custom service",
        defaultBaseURL: nil,
        modelDiscoveryPath: "/models",
        allowsManualModelFallback: true
    )

    public static func connector(for provider: ModelProvider) -> ProviderConnector {
        switch provider {
        case .deepSeek:
            return deepSeek
        case .anthropic:
            return anthropic
        case .openAI:
            return openAI
        case .gemini:
            return gemini
        case .openRouter:
            return openRouter
        case .custom:
            return customConnector
        }
    }
}

public struct ModelCredentialReference: Hashable, Codable, Sendable {
    public let id: UUID
    public let connectionID: UUID
    public let provider: ModelProvider
    public let allowedHost: String
    public let allowedPort: Int?
    public let versionID: UUID

    init(
        id: UUID,
        connectionID: UUID,
        provider: ModelProvider,
        allowedHost: String,
        allowedPort: Int? = nil,
        versionID: UUID
    ) {
        self.id = id
        self.connectionID = connectionID
        self.provider = provider
        self.allowedHost = allowedHost
        self.allowedPort = allowedPort
        self.versionID = versionID
    }
}

public enum ModelConnectionError: Error, Equatable, Sendable {
    case emptyName
    case nameTooLarge
    case invalidName
    case missingSelectedModel
    case selectedModelTooLarge
    case invalidSelectedModel
    case unsafeBaseURL
    case providerBaseURLMismatch
    case credentialBindingMismatch
    case unverifiedModelSelection
}

public struct ModelConnection: Identifiable, Equatable, Codable, Sendable {
    public static let maximumNameUTF8Bytes = 256
    public static let maximumModelIdentifierUTF8Bytes = 1_024
    public static let maximumBaseURLUTF8Bytes = 4_096
    public static let maximumBaseURLHostUTF8Bytes = 253
    public static let maximumBaseURLPathUTF8Bytes = 2_048

    public let id: UUID
    public let name: String
    public let provider: ModelProvider
    public let baseURL: URL
    public let credential: ModelCredentialReference
    public let selectedModel: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case provider
        case baseURL
        case credential
        case selectedModel
    }

    private init(
        id: UUID,
        name: String,
        provider: ModelProvider,
        baseURL: URL,
        credential: ModelCredentialReference,
        selectedModel: String
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.baseURL = baseURL
        self.credential = credential
        self.selectedModel = selectedModel
    }

    static func make(
        id: UUID,
        name rawName: String,
        provider: ModelProvider,
        baseURL: URL,
        credentialID: UUID,
        credentialVersionID: UUID = UUID(),
        selectedModel rawSelectedModel: String
    ) throws -> ModelConnection {
        let fields = try validatedFields(
            name: rawName,
            provider: provider,
            baseURL: baseURL,
            selectedModel: rawSelectedModel
        )
        let credential = ModelCredentialReference(
            id: credentialID,
            connectionID: id,
            provider: provider,
            allowedHost: try validatedHost(fields.baseURL),
            allowedPort: validatedPort(fields.baseURL),
            versionID: credentialVersionID
        )

        return ModelConnection(
            id: id,
            name: fields.name,
            provider: provider,
            baseURL: fields.baseURL,
            credential: credential,
            selectedModel: fields.selectedModel
        )
    }

    public static func make(
        name rawName: String,
        selection: ModelSelection
    ) throws -> ModelConnection {
        switch selection.source {
        case .discovered, .publicCatalogAfterCredentialProbe:
            break
        case .customCatalogWithoutCredentialProbe,
             .manualAfterUnsupportedDiscovery:
            throw ModelConnectionError.unverifiedModelSelection
        }
        return try make(
            id: selection.connectionID,
            name: rawName,
            provider: selection.provider,
            baseURL: selection.baseURL,
            credentialID: selection.credentialBinding.credentialID,
            credentialVersionID: selection.credentialBinding.versionID,
            selectedModel: selection.modelID
        )
    }

    public static func make(
        name rawName: String,
        credentialProvenSelection: CredentialProvenCustomModelSelection
    ) throws -> ModelConnection {
        let selection = credentialProvenSelection.selection
        return try make(
            id: selection.connectionID,
            name: rawName,
            provider: selection.provider,
            baseURL: selection.baseURL,
            credentialID: selection.credentialBinding.credentialID,
            credentialVersionID: selection.credentialBinding.versionID,
            selectedModel: selection.modelID
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let provider = try container.decode(ModelProvider.self, forKey: .provider)
        let credential = try container.decode(ModelCredentialReference.self, forKey: .credential)
        let fields = try Self.validatedFields(
            name: container.decode(String.self, forKey: .name),
            provider: provider,
            baseURL: container.decode(URL.self, forKey: .baseURL),
            selectedModel: container.decode(String.self, forKey: .selectedModel)
        )
        guard credential.connectionID == id,
              credential.provider == provider,
              Self.normalizedHost(credential.allowedHost) == Self.normalizedHost(
                try Self.validatedHost(fields.baseURL)
              ),
              credential.allowedPort == Self.validatedPort(fields.baseURL) else {
            throw ModelConnectionError.credentialBindingMismatch
        }

        self.init(
            id: id,
            name: fields.name,
            provider: provider,
            baseURL: fields.baseURL,
            credential: credential,
            selectedModel: fields.selectedModel
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(provider, forKey: .provider)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(credential, forKey: .credential)
        try container.encode(selectedModel, forKey: .selectedModel)
    }

    private static func isSafeBaseURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              url.absoluteString.utf8.count <= maximumBaseURLUTF8Bytes,
              host.utf8.count <= maximumBaseURLHostUTF8Bytes,
              components.percentEncodedPath.utf8.count <= maximumBaseURLPathUTF8Bytes else {
            return false
        }
        if let port = components.port,
           !(1...65_535).contains(port) {
            return false
        }
        return true
    }

    private static func validatedFields(
        name rawName: String,
        provider: ModelProvider,
        baseURL: URL,
        selectedModel rawSelectedModel: String
    ) throws -> (name: String, baseURL: URL, selectedModel: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw ModelConnectionError.emptyName
        }
        guard name.utf8.count <= maximumNameUTF8Bytes else {
            throw ModelConnectionError.nameTooLarge
        }
        guard !containsUnsafeDisplayControl(name) else {
            throw ModelConnectionError.invalidName
        }

        let selectedModel = rawSelectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedModel.isEmpty else {
            throw ModelConnectionError.missingSelectedModel
        }
        guard selectedModel.utf8.count <= maximumModelIdentifierUTF8Bytes else {
            throw ModelConnectionError.selectedModelTooLarge
        }
        guard !containsUnsafeDisplayControl(selectedModel) else {
            throw ModelConnectionError.invalidSelectedModel
        }

        guard isSafeBaseURL(baseURL) else {
            throw ModelConnectionError.unsafeBaseURL
        }

        let storedBaseURL = try validatedBaseURL(
            provider: provider,
            baseURL: baseURL
        )

        return (name, storedBaseURL, selectedModel)
    }

    private static func validatedHost(_ url: URL) throws -> String {
        guard let host = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.host else {
            throw ModelConnectionError.unsafeBaseURL
        }
        return normalizedHost(host)
    }

    private static func normalizedHost(_ host: String) -> String {
        host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static func validatedPort(_ url: URL) -> Int? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.port
    }

    static func validatedBaseURL(
        provider: ModelProvider,
        baseURL: URL
    ) throws -> URL {
        guard isSafeBaseURL(baseURL) else {
            throw ModelConnectionError.unsafeBaseURL
        }
        guard provider != .custom else {
            return baseURL
        }

        let connector = ProviderConnectorRegistry.connector(for: provider)
        guard let expectedBaseURL = connector.defaultBaseURL,
              equivalentEndpoint(baseURL, expectedBaseURL) else {
            throw ModelConnectionError.providerBaseURLMismatch
        }
        return expectedBaseURL
    }

    static func containsUnsafeDisplayControl(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            if CharacterSet.controlCharacters.contains(scalar) {
                return true
            }
            switch scalar.value {
            case 0x061C, 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x2069:
                return true
            default:
                return false
            }
        }
    }

    private static func equivalentEndpoint(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let left = URLComponents(url: lhs, resolvingAgainstBaseURL: false),
              let right = URLComponents(url: rhs, resolvingAgainstBaseURL: false) else {
            return false
        }
        return left.scheme?.lowercased() == right.scheme?.lowercased()
            && left.host?.lowercased() == right.host?.lowercased()
            && left.port == right.port
            && normalizedPath(left.path) == normalizedPath(right.path)
    }

    private static func normalizedPath(_ path: String) -> String {
        var normalized = path
        while normalized.count > 1 && normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }
}

public enum PendingModelIntentError: Error, Equatable, Sendable {
    case branchRequiresProject
}

public struct PendingModelIntent: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let projectID: UUID?
    public let branchID: UUID?
    public let userRequest: String
    public let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationID
        case projectID
        case branchID
        case userRequest
        case createdAt
    }

    public init(
        id: UUID,
        conversationID: UUID,
        projectID: UUID?,
        branchID: UUID?,
        userRequest: String,
        createdAt: Date
    ) throws {
        guard branchID == nil || projectID != nil else {
            throw PendingModelIntentError.branchRequiresProject
        }
        let validatedTurn = try S1ConversationPreview.makeTurn(from: userRequest)

        self.id = id
        self.conversationID = conversationID
        self.projectID = projectID
        self.branchID = branchID
        self.userRequest = validatedTurn.userText
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            conversationID: container.decode(UUID.self, forKey: .conversationID),
            projectID: container.decodeIfPresent(UUID.self, forKey: .projectID),
            branchID: container.decodeIfPresent(UUID.self, forKey: .branchID),
            userRequest: container.decode(String.self, forKey: .userRequest),
            createdAt: container.decode(Date.self, forKey: .createdAt)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encodeIfPresent(projectID, forKey: .projectID)
        try container.encodeIfPresent(branchID, forKey: .branchID)
        try container.encode(userRequest, forKey: .userRequest)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

public struct ModelCredentialVerification: Equatable, Sendable {
    public let credentialID: UUID
    public let connectionID: UUID
    public let provider: ModelProvider
    public let allowedHost: String
    public let allowedPort: Int?
    public let versionID: UUID
    public let credentialVersionProof: String
    public let credentialPayloadHash: String
    public let setupAuthorizationHash: String?

    @_spi(ModelCredentialVerification)
    public init(
        reference: ModelCredentialReference,
        credentialVersionProof: String,
        credentialPayloadHash: String,
        setupAuthorizationHash: String? = nil
    ) throws {
        guard Self.isCanonicalSHA256Hex(credentialVersionProof),
              Self.isCanonicalSHA256Hex(credentialPayloadHash),
              setupAuthorizationHash.map(Self.isCanonicalSHA256Hex) ?? true else {
            throw ModelConnectionError.credentialBindingMismatch
        }
        credentialID = reference.id
        connectionID = reference.connectionID
        provider = reference.provider
        allowedHost = reference.allowedHost
        allowedPort = reference.allowedPort
        versionID = reference.versionID
        self.credentialVersionProof = credentialVersionProof
        self.credentialPayloadHash = credentialPayloadHash
        self.setupAuthorizationHash = setupAuthorizationHash
    }

    private static func isCanonicalSHA256Hex(_ value: String) -> Bool {
        value.utf8.count == 64
            && value.unicodeScalars.allSatisfy { scalar in
                switch scalar.value {
                case 0x30...0x39, 0x61...0x66:
                    return true
                default:
                    return false
                }
            }
    }
}

public struct VerifiedModelConnection: Equatable, Sendable {
    public let connection: ModelConnection
    public let credentialVerification: ModelCredentialVerification

    @_spi(ModelCredentialVerification)
    public init(
        connection: ModelConnection,
        credentialVerification: ModelCredentialVerification
    ) throws {
        guard credentialVerification.credentialID == connection.credential.id,
              credentialVerification.connectionID == connection.id,
              credentialVerification.provider == connection.provider,
              credentialVerification.allowedHost == connection.credential.allowedHost,
              credentialVerification.allowedPort == connection.credential.allowedPort,
              credentialVerification.versionID == connection.credential.versionID else {
            throw ModelConnectionError.credentialBindingMismatch
        }
        self.connection = connection
        self.credentialVerification = credentialVerification
    }
}

public enum ModelRequestAdmissionDecision: Equatable, Sendable {
    case modelConnectionRequired(PendingModelIntent)
    case prepareProviderRequest(
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection
    )
}

public enum ModelRequestAdmission {
    public static func decide(
        rawRequest: String,
        intentID: UUID,
        conversationID: UUID,
        projectID: UUID? = nil,
        branchID: UUID? = nil,
        currentConnection: VerifiedModelConnection?,
        now: Date
    ) throws -> ModelRequestAdmissionDecision {
        let intent = try PendingModelIntent(
            id: intentID,
            conversationID: conversationID,
            projectID: projectID,
            branchID: branchID,
            userRequest: rawRequest,
            createdAt: now
        )

        guard let currentConnection else {
            return .modelConnectionRequired(intent)
        }
        return .prepareProviderRequest(
            intent: intent,
            verifiedConnection: currentConnection
        )
    }

    public static func resume(
        _ intent: PendingModelIntent,
        with connection: VerifiedModelConnection
    ) -> ModelRequestAdmissionDecision {
        .prepareProviderRequest(intent: intent, verifiedConnection: connection)
    }
}
