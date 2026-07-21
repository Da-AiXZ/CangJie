import CangJieCore
import CryptoKit
import Foundation

enum ModelCredentialRepositoryError: Error, Equatable {
    case emptySecret
    case secretTooLarge
    case invalidSecret
    case invalidStoredCredential
    case credentialBindingMismatch
    case writeVerificationFailed
    case deleteVerificationFailed
}

/// Keychain binding evidence only. Provider connectivity and capability testing
/// remain separate gates before any request may be prepared or sent.
struct KeychainBoundModelCredential: Equatable {
    let reference: ModelCredentialReference
    let secret: String
}

protocol ModelCredentialRepository {
    func save(_ secret: String, for connection: ModelConnection) throws
    func resolve(for connection: ModelConnection) throws -> KeychainBoundModelCredential?
    func delete(for connection: ModelConnection) throws
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
    static let maximumSecretUTF8Bytes = 4_096

    private struct CredentialEnvelope: Codable, Equatable {
        let version: Int
        let credentialID: UUID
        let connectionID: UUID
        let provider: ModelProvider
        let allowedHost: String
        let allowedPort: Int?
        let secret: String
    }

    private struct VerificationEnvelope: Codable, Equatable {
        enum State: String, Codable {
            case active
            case revoked
        }

        let version: Int
        let credentialID: UUID
        let connectionID: UUID
        let provider: ModelProvider
        let allowedHost: String
        let allowedPort: Int?
        let state: State
        let credentialPayloadHash: String?
    }

    private static let envelopeVersion = 1
    private static let accountPrefix = "model-credential-v1:"
    private let secrets: any SecretRepository

    init(secrets: any SecretRepository = KeychainSecretRepository()) {
        self.secrets = secrets
    }

    func save(_ secret: String, for connection: ModelConnection) throws {
        try Self.validateNewSecret(secret)
        try ModelCredentialOperationCoordinator.withExclusiveAccess {
            try validateExistingItems(for: connection.credential)
            let verificationAccount = Self.verificationAccount(
                for: connection.credential.id
            )
            try writeRevokedVerification(
                reference: connection.credential,
                account: verificationAccount
            )

            let credentialEnvelope = Self.credentialEnvelope(
                secret: secret,
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

                let verificationEnvelope = Self.verificationEnvelope(
                    payload: credentialPayload,
                    connection: connection
                )
                let verificationPayload = try Self.encode(verificationEnvelope)
                try secrets.save(verificationPayload, account: verificationAccount)
                guard try secrets.read(account: verificationAccount) == verificationPayload else {
                    throw ModelCredentialRepositoryError.writeVerificationFailed
                }
            } catch {
                try? writeRevokedVerification(
                    reference: connection.credential,
                    account: verificationAccount
                )
                throw error
            }
        }
    }

    func resolve(for connection: ModelConnection) throws -> KeychainBoundModelCredential? {
        try ModelCredentialOperationCoordinator.withExclusiveAccess {
            let verificationAccount = Self.verificationAccount(
                for: connection.credential.id
            )
            guard let verificationPayload = try secrets.read(account: verificationAccount) else {
                return nil
            }
            let verification = try Self.decode(
                VerificationEnvelope.self,
                from: verificationPayload
            )
            try Self.validateBinding(verification, against: connection.credential)
            guard verification.state == .active else {
                return nil
            }

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
            guard verification.credentialPayloadHash == Self.payloadHash(credentialPayload) else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }

            return KeychainBoundModelCredential(
                reference: connection.credential,
                secret: credential.secret
            )
        }
    }

    func delete(for connection: ModelConnection) throws {
        try ModelCredentialOperationCoordinator.withExclusiveAccess {
            try validateExistingItems(for: connection.credential)
            let verificationAccount = Self.verificationAccount(
                for: connection.credential.id
            )
            try writeRevokedVerification(
                reference: connection.credential,
                account: verificationAccount
            )

            let credentialAccount = Self.credentialAccount(
                for: connection.credential.id
            )
            try secrets.delete(account: credentialAccount)
            guard try secrets.read(account: credentialAccount) == nil else {
                throw ModelCredentialRepositoryError.deleteVerificationFailed
            }
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

    private func validateExistingItems(
        for reference: ModelCredentialReference
    ) throws {
        if let credentialPayload = try secrets.read(
            account: Self.credentialAccount(for: reference.id)
        ) {
            let credential = try Self.decode(
                CredentialEnvelope.self,
                from: credentialPayload
            )
            try Self.validateBinding(credential, against: reference)
        }
        if let verificationPayload = try secrets.read(
            account: Self.verificationAccount(for: reference.id)
        ) {
            let verification = try Self.decode(
                VerificationEnvelope.self,
                from: verificationPayload
            )
            try Self.validateBinding(verification, against: reference)
        }
    }

    private func writeRevokedVerification(
        reference: ModelCredentialReference,
        account: String
    ) throws {
        let revoked = VerificationEnvelope(
            version: Self.envelopeVersion,
            credentialID: reference.id,
            connectionID: reference.connectionID,
            provider: reference.provider,
            allowedHost: reference.allowedHost,
            allowedPort: reference.allowedPort,
            state: .revoked,
            credentialPayloadHash: nil
        )
        let payload = try Self.encode(revoked)
        try secrets.save(payload, account: account)
        guard try secrets.read(account: account) == payload else {
            throw ModelCredentialRepositoryError.writeVerificationFailed
        }
    }

    private static func credentialEnvelope(
        secret: String,
        connection: ModelConnection
    ) -> CredentialEnvelope {
        CredentialEnvelope(
            version: envelopeVersion,
            credentialID: connection.credential.id,
            connectionID: connection.credential.connectionID,
            provider: connection.credential.provider,
            allowedHost: connection.credential.allowedHost,
            allowedPort: connection.credential.allowedPort,
            secret: secret
        )
    }

    private static func verificationEnvelope(
        payload: String,
        connection: ModelConnection
    ) -> VerificationEnvelope {
        VerificationEnvelope(
            version: envelopeVersion,
            credentialID: connection.credential.id,
            connectionID: connection.credential.connectionID,
            provider: connection.credential.provider,
            allowedHost: connection.credential.allowedHost,
            allowedPort: connection.credential.allowedPort,
            state: .active,
            credentialPayloadHash: payloadHash(payload)
        )
    }

    private static func encode<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard let encoded = String(data: data, encoding: .utf8) else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        return encoded
    }

    private static func decode<Value: Decodable>(
        _ type: Value.Type,
        from stored: String
    ) throws -> Value {
        guard let data = stored.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(type, from: data) else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        if let credential = envelope as? CredentialEnvelope {
            guard credential.version == envelopeVersion else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            do {
                try validateNewSecret(credential.secret)
            } catch {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
        } else if let verification = envelope as? VerificationEnvelope {
            guard verification.version == envelopeVersion else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            switch verification.state {
            case .active:
                guard verification.credentialPayloadHash?.count == 64 else {
                    throw ModelCredentialRepositoryError.invalidStoredCredential
                }
            case .revoked:
                guard verification.credentialPayloadHash == nil else {
                    throw ModelCredentialRepositoryError.invalidStoredCredential
                }
            }
        }
        return envelope
    }

    private static func validateBinding(
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

    private static func validateBinding(
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

    private static func payloadHash(_ payload: String) -> String {
        SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func validateNewSecret(_ secret: String) throws {
        guard !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelCredentialRepositoryError.emptySecret
        }
        guard secret.utf8.count <= maximumSecretUTF8Bytes else {
            throw ModelCredentialRepositoryError.secretTooLarge
        }
        guard !containsUnsafeControl(secret) else {
            throw ModelCredentialRepositoryError.invalidSecret
        }
    }

    private static func containsUnsafeControl(_ secret: String) -> Bool {
        secret.unicodeScalars.contains { scalar in
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

}
