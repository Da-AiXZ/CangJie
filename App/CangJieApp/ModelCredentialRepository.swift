@_spi(ModelCredentialVerification) import CangJieCore
import CryptoKit
import Foundation

enum ModelCredentialRepositoryError: Error, Equatable {
    case emptySecret
    case secretTooLarge
    case invalidSecret
    case invalidStoredCredential
    case credentialBindingMismatch
    case credentialVersionConflict
    case writeVerificationFailed
    case revocationCompensationFailed
    case legacyCredentialCleanupFailed
    case deleteVerificationFailed
}

/// Keychain binding evidence only. Provider connectivity and capability testing
/// remain separate gates before any request may be prepared or sent.
struct KeychainBoundModelCredential: Equatable {
    let reference: ModelCredentialReference
    let secret: String
    let credentialVersionProof: String
    let credentialPayloadHash: String
    let setupAuthorizationHash: String?
}

protocol ModelCredentialRepository {
    func save(
        _ secret: String,
        versionProof: String,
        setupAuthorizationHash: String?,
        for connection: ModelConnection
    ) throws
    func resolve(for connection: ModelConnection) throws -> KeychainBoundModelCredential?
    func delete(for connection: ModelConnection) throws
}

extension ModelCredentialRepository {
    func save(
        _ secret: String,
        versionProof: String,
        for connection: ModelConnection
    ) throws {
        try save(
            secret,
            versionProof: versionProof,
            setupAuthorizationHash: nil,
            for: connection
        )
    }

    func verifiedConnection(
        for connection: ModelConnection,
        matchingSecret expectedSecret: String? = nil
    ) throws -> VerifiedModelConnection? {
        guard let credential = try resolve(for: connection) else {
            return nil
        }
        guard expectedSecret == nil || credential.secret == expectedSecret else {
            return nil
        }
        let verification = try ModelCredentialVerification(
            reference: credential.reference,
            credentialVersionProof: credential.credentialVersionProof,
            credentialPayloadHash: credential.credentialPayloadHash,
            setupAuthorizationHash: credential.setupAuthorizationHash
        )
        return try VerifiedModelConnection(
            connection: connection,
            credentialVerification: verification
        )
    }
}

/// Serializes every process-local credential mutation and any higher-level
/// Keychain/SQLite compensation sequence that uses this coordinator.
enum ModelCredentialOperationCoordinator {
    private static let lock = NSRecursiveLock()

    static func withExclusiveAccess<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

struct KeychainModelCredentialRepository: ModelCredentialRepository {
    static let maximumSecretUTF8Bytes = ModelCredentialSecretValidator.maximumUTF8Bytes

    struct CredentialEnvelope: Codable, Equatable {
        let version: Int
        let credentialID: UUID
        let connectionID: UUID
        let provider: ModelProvider
        let allowedHost: String
        let allowedPort: Int?
        let credentialVersionID: UUID
        let credentialVersionProof: String
        let setupAuthorizationHash: String?
        let secret: String
    }

    struct VerificationEnvelope: Codable, Equatable {
        enum State: String, Codable {
            case active
            case migrationPending
            case revoked
        }

        let version: Int
        let credentialID: UUID
        let connectionID: UUID
        let provider: ModelProvider
        let allowedHost: String
        let allowedPort: Int?
        let credentialVersionID: UUID
        let credentialVersionProof: String
        let state: State
        let credentialPayloadHash: String?
        let setupAuthorizationHash: String?
    }

    static let envelopeVersion = 2
    private static let accountPrefix = "model-credential-v2:"
    let secrets: any SecretRepository

    init(secrets: any SecretRepository = KeychainSecretRepository()) {
        self.secrets = secrets
    }

    func save(
        _ secret: String,
        versionProof: String,
        setupAuthorizationHash: String?,
        for connection: ModelConnection
    ) throws {
        try ModelCredentialSecretValidator.validate(secret)
        try Self.validateCredentialVersionProof(versionProof)
        try Self.validateSetupAuthorizationHash(setupAuthorizationHash)
        try ModelCredentialOperationCoordinator.withExclusiveAccess {
            try validateExistingItemsForSave(
                secret: secret,
                versionProof: versionProof,
                setupAuthorizationHash: setupAuthorizationHash,
                reference: connection.credential
            )
            let verificationAccount = Self.verificationAccount(
                for: connection.credential.id
            )
            try writeRevokedVerification(
                reference: connection.credential,
                versionProof: versionProof,
                account: verificationAccount
            )

            let credentialEnvelope = Self.credentialEnvelope(
                secret: secret,
                versionProof: versionProof,
                setupAuthorizationHash: setupAuthorizationHash,
                connection: connection
            )
            let credentialPayload = try Self.encode(credentialEnvelope)
            let credentialAccount = Self.credentialAccount(
                for: connection.credential.id
            )
            do {
                try secrets.save(credentialPayload, account: credentialAccount)
                guard try secrets.read(account: credentialAccount) == credentialPayload else {
                    throw ModelCredentialRepositoryError.writeVerificationFailed
                }
                try revokeLegacyVerificationIfPresent(
                    for: connection.credential
                )

                let verificationEnvelope = Self.verificationEnvelope(
                    payload: credentialPayload,
                    versionProof: versionProof,
                    setupAuthorizationHash: setupAuthorizationHash,
                    connection: connection
                )
                let verificationPayload = try Self.encode(verificationEnvelope)
                try secrets.save(verificationPayload, account: verificationAccount)
                guard try secrets.read(account: verificationAccount) == verificationPayload else {
                    throw ModelCredentialRepositoryError.writeVerificationFailed
                }
            } catch let operationError {
                do {
                    try writeRevokedVerification(
                        reference: connection.credential,
                        versionProof: versionProof,
                        account: verificationAccount
                    )
                } catch {
                    throw ModelCredentialRepositoryError.revocationCompensationFailed
                }
                throw operationError
            }
            try deleteLegacyCredentialItems(for: connection.credential)
        }
    }

    func resolve(for connection: ModelConnection) throws -> KeychainBoundModelCredential? {
        try ModelCredentialOperationCoordinator.withExclusiveAccess {
            let verificationAccount = Self.verificationAccount(
                for: connection.credential.id
            )
            var verificationPayload = try secrets.read(account: verificationAccount)
            if verificationPayload == nil {
                guard try secrets.read(
                    account: Self.credentialAccount(for: connection.credential.id)
                ) == nil else {
                    throw ModelCredentialRepositoryError.invalidStoredCredential
                }
                guard try migrateLegacyCredentialIfPresent(for: connection) else {
                    return nil
                }
                verificationPayload = try secrets.read(account: verificationAccount)
            }
            guard let verificationPayload else {
                return nil
            }
            var verification = try Self.decode(
                VerificationEnvelope.self,
                from: verificationPayload
            )
            try Self.validateBinding(verification, against: connection.credential)
            switch verification.state {
            case .revoked:
                return nil
            case .migrationPending:
                try resumeLegacyMigration(
                    for: connection,
                    pendingVerification: verification
                )
                guard let migratedVerificationPayload = try secrets.read(
                    account: verificationAccount
                ) else {
                    throw ModelCredentialRepositoryError.invalidStoredCredential
                }
                verification = try Self.decode(
                    VerificationEnvelope.self,
                    from: migratedVerificationPayload
                )
                try Self.validateBinding(
                    verification,
                    against: connection.credential
                )
            case .active:
                break
            }
            guard verification.state == .active else { return nil }

            let credentialAccount = Self.credentialAccount(
                for: connection.credential.id
            )
            guard let credentialPayload = try secrets.read(account: credentialAccount) else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            let credential = try Self.decode(
                CredentialEnvelope.self,
                from: credentialPayload
            )
            try Self.validateBinding(credential, against: connection.credential)
            guard let credentialPayloadHash = verification.credentialPayloadHash,
                  credential.credentialVersionProof
                      == verification.credentialVersionProof,
                  credential.setupAuthorizationHash
                      == verification.setupAuthorizationHash,
                  credentialPayloadHash == Self.payloadHash(credentialPayload) else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            try deleteLegacyCredentialItems(for: connection.credential)

            return KeychainBoundModelCredential(
                reference: connection.credential,
                secret: credential.secret,
                credentialVersionProof: credential.credentialVersionProof,
                credentialPayloadHash: credentialPayloadHash,
                setupAuthorizationHash: credential.setupAuthorizationHash
            )
        }
    }

    func delete(for connection: ModelConnection) throws {
        try ModelCredentialOperationCoordinator.withExclusiveAccess {
            let versionProof = try validateExistingItems(
                for: connection.credential
            )
            let verificationAccount = Self.verificationAccount(
                for: connection.credential.id
            )
            if let versionProof {
                try writeRevokedVerification(
                    reference: connection.credential,
                    versionProof: versionProof,
                    account: verificationAccount
                )
            }
            try revokeLegacyVerificationIfPresent(
                for: connection.credential
            )

            let credentialAccount = Self.credentialAccount(
                for: connection.credential.id
            )
            try secrets.delete(account: credentialAccount)
            guard try secrets.read(account: credentialAccount) == nil else {
                throw ModelCredentialRepositoryError.deleteVerificationFailed
            }
            try deleteLegacyCredentialItemsAfterRevocation(
                for: connection.credential
            )
            try secrets.delete(account: verificationAccount)
            guard try secrets.read(account: verificationAccount) == nil else {
                throw ModelCredentialRepositoryError.deleteVerificationFailed
            }
        }
    }

    static func credentialAccount(for credentialID: UUID) -> String {
        accountPrefix + credentialID.uuidString.lowercased() + ":payload"
    }

    static func verificationAccount(for credentialID: UUID) -> String {
        accountPrefix + credentialID.uuidString.lowercased() + ":verified"
    }

    private func validateExistingItemsForSave(
        secret: String,
        versionProof: String,
        setupAuthorizationHash: String?,
        reference: ModelCredentialReference
    ) throws {
        if let credentialPayload = try secrets.read(
            account: Self.credentialAccount(for: reference.id)
        ) {
            let credential = try Self.decode(
                CredentialEnvelope.self,
                from: credentialPayload
            )
            try Self.validateStableBinding(credential, against: reference)
            if credential.credentialVersionID == reference.versionID,
               (credential.secret != secret
                || credential.credentialVersionProof != versionProof
                || credential.setupAuthorizationHash != setupAuthorizationHash) {
                throw ModelCredentialRepositoryError.credentialVersionConflict
            }
        }
        if let verificationPayload = try secrets.read(
            account: Self.verificationAccount(for: reference.id)
        ) {
            let verification = try Self.decode(
                VerificationEnvelope.self,
                from: verificationPayload
            )
            try Self.validateStableBinding(verification, against: reference)
            if verification.credentialVersionID == reference.versionID,
               (verification.credentialVersionProof != versionProof
                || (verification.state != .revoked
                    && verification.setupAuthorizationHash
                        != setupAuthorizationHash)) {
                throw ModelCredentialRepositoryError.credentialVersionConflict
            }
        }
    }

    private func validateExistingItems(
        for reference: ModelCredentialReference
    ) throws -> String? {
        var versionProof: String?
        if let credentialPayload = try secrets.read(
            account: Self.credentialAccount(for: reference.id)
        ) {
            let credential = try Self.decode(
                CredentialEnvelope.self,
                from: credentialPayload
            )
            try Self.validateBinding(credential, against: reference)
            versionProof = credential.credentialVersionProof
        }
        if let verificationPayload = try secrets.read(
            account: Self.verificationAccount(for: reference.id)
        ) {
            let verification = try Self.decode(
                VerificationEnvelope.self,
                from: verificationPayload
            )
            try Self.validateBinding(verification, against: reference)
            if let versionProof,
               versionProof != verification.credentialVersionProof {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            versionProof = verification.credentialVersionProof
        }
        return versionProof
    }

    private func writeRevokedVerification(
        reference: ModelCredentialReference,
        versionProof: String,
        account: String
    ) throws {
        let revoked = VerificationEnvelope(
            version: Self.envelopeVersion,
            credentialID: reference.id,
            connectionID: reference.connectionID,
            provider: reference.provider,
            allowedHost: reference.allowedHost,
            allowedPort: reference.allowedPort,
            credentialVersionID: reference.versionID,
            credentialVersionProof: versionProof,
            state: .revoked,
            credentialPayloadHash: nil,
            setupAuthorizationHash: nil
        )
        let payload = try Self.encode(revoked)
        try secrets.save(payload, account: account)
        guard try secrets.read(account: account) == payload else {
            throw ModelCredentialRepositoryError.writeVerificationFailed
        }
    }

    static func credentialEnvelope(
        secret: String,
        versionProof: String,
        setupAuthorizationHash: String?,
        connection: ModelConnection
    ) -> CredentialEnvelope {
        CredentialEnvelope(
            version: envelopeVersion,
            credentialID: connection.credential.id,
            connectionID: connection.credential.connectionID,
            provider: connection.credential.provider,
            allowedHost: connection.credential.allowedHost,
            allowedPort: connection.credential.allowedPort,
            credentialVersionID: connection.credential.versionID,
            credentialVersionProof: versionProof,
            setupAuthorizationHash: setupAuthorizationHash,
            secret: secret
        )
    }

    static func verificationEnvelope(
        payload: String,
        versionProof: String,
        setupAuthorizationHash: String?,
        connection: ModelConnection
    ) -> VerificationEnvelope {
        VerificationEnvelope(
            version: envelopeVersion,
            credentialID: connection.credential.id,
            connectionID: connection.credential.connectionID,
            provider: connection.credential.provider,
            allowedHost: connection.credential.allowedHost,
            allowedPort: connection.credential.allowedPort,
            credentialVersionID: connection.credential.versionID,
            credentialVersionProof: versionProof,
            state: .active,
            credentialPayloadHash: payloadHash(payload),
            setupAuthorizationHash: setupAuthorizationHash
        )
    }

    static func encode<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard let encoded = String(data: data, encoding: .utf8) else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        return encoded
    }

    static func decode<Value: Decodable>(
        _ type: Value.Type,
        from stored: String
    ) throws -> Value {
        guard let data = stored.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(type, from: data) else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        if let credential = envelope as? CredentialEnvelope {
            guard credential.version == envelopeVersion,
                  isCanonicalSHA256Hex(credential.credentialVersionProof),
                  isCanonicalOptionalSHA256Hex(
                    credential.setupAuthorizationHash
                  ) else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            do {
                try ModelCredentialSecretValidator.validate(credential.secret)
            } catch {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
        } else if let verification = envelope as? VerificationEnvelope {
            guard verification.version == envelopeVersion,
                  isCanonicalSHA256Hex(verification.credentialVersionProof),
                  isCanonicalOptionalSHA256Hex(
                    verification.setupAuthorizationHash
                  ) else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            switch verification.state {
            case .active, .migrationPending:
                guard let credentialPayloadHash = verification.credentialPayloadHash,
                      isCanonicalSHA256Hex(credentialPayloadHash) else {
                    throw ModelCredentialRepositoryError.invalidStoredCredential
                }
            case .revoked:
                guard verification.credentialPayloadHash == nil,
                      verification.setupAuthorizationHash == nil else {
                    throw ModelCredentialRepositoryError.invalidStoredCredential
                }
            }
        }
        return envelope
    }

    static func validateBinding(
        _ envelope: CredentialEnvelope,
        against reference: ModelCredentialReference
    ) throws {
        guard envelope.credentialID == reference.id,
              envelope.connectionID == reference.connectionID,
              envelope.provider == reference.provider,
              envelope.allowedHost == reference.allowedHost,
              envelope.allowedPort == reference.allowedPort,
              envelope.credentialVersionID == reference.versionID else {
            throw ModelCredentialRepositoryError.credentialBindingMismatch
        }
    }

    static func validateBinding(
        _ envelope: VerificationEnvelope,
        against reference: ModelCredentialReference
    ) throws {
        guard envelope.credentialID == reference.id,
              envelope.connectionID == reference.connectionID,
              envelope.provider == reference.provider,
              envelope.allowedHost == reference.allowedHost,
              envelope.allowedPort == reference.allowedPort,
              envelope.credentialVersionID == reference.versionID else {
            throw ModelCredentialRepositoryError.credentialBindingMismatch
        }
    }

    private static func validateStableBinding(
        _ envelope: CredentialEnvelope,
        against reference: ModelCredentialReference
    ) throws {
        guard envelope.credentialID == reference.id,
              envelope.connectionID == reference.connectionID,
              envelope.provider == reference.provider,
              envelope.allowedHost == reference.allowedHost,
              envelope.allowedPort == reference.allowedPort else {
            throw ModelCredentialRepositoryError.credentialBindingMismatch
        }
    }

    private static func validateStableBinding(
        _ envelope: VerificationEnvelope,
        against reference: ModelCredentialReference
    ) throws {
        guard envelope.credentialID == reference.id,
              envelope.connectionID == reference.connectionID,
              envelope.provider == reference.provider,
              envelope.allowedHost == reference.allowedHost,
              envelope.allowedPort == reference.allowedPort else {
            throw ModelCredentialRepositoryError.credentialBindingMismatch
        }
    }

    static func payloadHash(_ payload: String) -> String {
        SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func validateCredentialVersionProof(
        _ versionProof: String
    ) throws {
        guard isCanonicalSHA256Hex(versionProof) else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
    }

    private static func validateSetupAuthorizationHash(
        _ setupAuthorizationHash: String?
    ) throws {
        guard isCanonicalOptionalSHA256Hex(setupAuthorizationHash) else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
    }

    private static func isCanonicalOptionalSHA256Hex(
        _ value: String?
    ) -> Bool {
        value.map(isCanonicalSHA256Hex) ?? true
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
