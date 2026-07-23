@_spi(ModelDiscoveryCredentialBinding) import CangJieCore
import Foundation

enum ModelDiscoveryAttemptError: Error, Equatable {
    case selectionAttemptMismatch
    case customCatalogSelectionRequiresVerifiedConnection
    case manualSelectionRequiresVerifiedConnection
}

struct ModelConnectionSetupCandidate: Sendable {
    let connection: ModelConnection
    let credentialBinding: ModelDiscoveryCredentialBinding
    let secret: String

    fileprivate init(
        connection: ModelConnection,
        credentialBinding: ModelDiscoveryCredentialBinding,
        secret: String
    ) {
        self.connection = connection
        self.credentialBinding = credentialBinding
        self.secret = secret
    }
}

struct ModelDiscoveryAttempt: Sendable {
    let start: ModelDiscoveryStart
    let credentialBinding: ModelDiscoveryCredentialBinding
    let secret: String

    init(
        discoveryID: UUID,
        connectionID: UUID,
        credentialID: UUID,
        credentialVersionID: UUID = UUID(),
        provider: ModelProvider,
        baseURL: URL,
        secret: String
    ) throws {
        do {
            try ModelCredentialSecretValidator.validate(secret)
        } catch {
            throw ModelDiscoveryNetworkError.invalidCredential
        }
        let credentialBinding = try ModelDiscoveryCredentialBinding(
            credentialID: credentialID,
            connectionID: connectionID,
            provider: provider,
            baseURL: baseURL,
            versionID: credentialVersionID,
            versionProof: Self.makeOpaqueVersionProof()
        )
        self.start = try ModelDiscoveryFlow.start(
            discoveryID: discoveryID,
            credentialBinding: credentialBinding
        )
        self.credentialBinding = credentialBinding
        self.secret = secret
    }

    func prepareConnection(
        name: String,
        selection: ModelSelection
    ) throws -> ModelConnectionSetupCandidate {
        let scope = discoveryScope
        guard selection.discoveryID == scope.discoveryID,
              selection.connectionID == scope.connectionID,
              selection.provider == scope.provider,
              selection.baseURL == scope.baseURL,
              selection.credentialBinding == credentialBinding else {
            throw ModelDiscoveryAttemptError.selectionAttemptMismatch
        }
        switch selection.source {
        case .discovered, .publicCatalogAfterCredentialProbe:
            break
        case .customCatalogWithoutCredentialProbe:
            throw ModelDiscoveryAttemptError.customCatalogSelectionRequiresVerifiedConnection
        case .manualAfterUnsupportedDiscovery:
            throw ModelDiscoveryAttemptError.manualSelectionRequiresVerifiedConnection
        }
        return ModelConnectionSetupCandidate(
            connection: try ModelConnection.make(
                name: name,
                selection: selection
            ),
            credentialBinding: credentialBinding,
            secret: secret
        )
    }

    func prepareConnection(
        name: String,
        credentialProvenSelection: CredentialProvenCustomModelSelection
    ) throws -> ModelConnectionSetupCandidate {
        let scope = discoveryScope
        guard credentialProvenSelection.discoveryID == scope.discoveryID,
              credentialProvenSelection.connectionID == scope.connectionID,
              credentialProvenSelection.provider == scope.provider,
              credentialProvenSelection.baseURL == scope.baseURL,
              credentialProvenSelection.credentialBinding == credentialBinding else {
            throw ModelDiscoveryAttemptError.selectionAttemptMismatch
        }
        return ModelConnectionSetupCandidate(
            connection: try ModelConnection.make(
                name: name,
                credentialProvenSelection: credentialProvenSelection
            ),
            credentialBinding: credentialBinding,
            secret: secret
        )
    }

    private var discoveryScope: ModelDiscoveryScope {
        switch start {
        case let .ready(session):
            return session.scope
        case let .connectionProbeRequired(challenge):
            return challenge.scope
        }
    }

    private static func makeOpaqueVersionProof() -> String {
        [UUID(), UUID()]
            .map {
                $0.uuidString
                    .replacingOccurrences(of: "-", with: "")
                    .lowercased()
            }
            .joined()
    }
}
