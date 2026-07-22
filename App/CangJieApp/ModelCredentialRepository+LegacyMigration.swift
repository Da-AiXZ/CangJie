import CangJieCore
import Foundation

extension KeychainModelCredentialRepository {
    struct LegacyCredentialEnvelope: Codable, Equatable {
        let version: Int
        let credentialID: UUID
        let connectionID: UUID
        let provider: ModelProvider
        let allowedHost: String
        let allowedPort: Int?
        let secret: String
    }

    struct LegacyVerificationEnvelope: Codable, Equatable {
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

    static func legacyCredentialAccount(for credentialID: UUID) -> String {
        legacyAccountPrefix + credentialID.uuidString.lowercased() + ":payload"
    }

    static func legacyVerificationAccount(for credentialID: UUID) -> String {
        legacyAccountPrefix + credentialID.uuidString.lowercased() + ":verified"
    }

    func migrateLegacyCredentialIfPresent(
        for connection: ModelConnection
    ) throws -> Bool {
        guard let legacyCredential = try activeLegacyCredential(
            for: connection.credential
        ) else {
            return false
        }
        let versionProof = Self.makeOpaqueCredentialVersionProof()
        let credentialPayload = try Self.encode(
            Self.credentialEnvelope(
                secret: legacyCredential.secret,
                versionProof: versionProof,
                setupAuthorizationHash: nil,
                connection: connection
            )
        )
        let pending = Self.migrationPendingVerification(
            payload: credentialPayload,
            versionProof: versionProof,
            connection: connection
        )
        try writeV2Verification(
            pending,
            for: connection.credential.id
        )
        try writeV2CredentialPayload(
            credentialPayload,
            for: connection.credential.id
        )
        try revokeLegacyVerificationIfPresent(for: connection.credential)
        try activateMigratedCredential(
            payload: credentialPayload,
            versionProof: versionProof,
            connection: connection
        )
        try deleteLegacyCredentialItemsAfterRevocation(
            for: connection.credential
        )
        return true
    }

    func resumeLegacyMigration(
        for connection: ModelConnection,
        pendingVerification: VerificationEnvelope
    ) throws {
        guard pendingVerification.state == .migrationPending,
              pendingVerification.setupAuthorizationHash == nil,
              let pendingPayloadHash = pendingVerification.credentialPayloadHash else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        try Self.validateBinding(
            pendingVerification,
            against: connection.credential
        )
        let credentialAccount = Self.credentialAccount(
            for: connection.credential.id
        )
        let credentialPayload: String
        if let storedPayload = try secrets.read(account: credentialAccount) {
            credentialPayload = storedPayload
        } else {
            guard let legacyCredential = try activeLegacyCredential(
                for: connection.credential
            ) else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            credentialPayload = try Self.encode(
                Self.credentialEnvelope(
                    secret: legacyCredential.secret,
                    versionProof: pendingVerification.credentialVersionProof,
                    setupAuthorizationHash: nil,
                    connection: connection
                )
            )
            guard Self.payloadHash(credentialPayload) == pendingPayloadHash else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            try writeV2CredentialPayload(
                credentialPayload,
                for: connection.credential.id
            )
        }
        let credential = try Self.decode(
            CredentialEnvelope.self,
            from: credentialPayload
        )
        try Self.validateBinding(credential, against: connection.credential)
        guard credential.credentialVersionProof
                == pendingVerification.credentialVersionProof,
              credential.setupAuthorizationHash == nil,
              Self.payloadHash(credentialPayload) == pendingPayloadHash else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }

        try revokeLegacyVerificationIfPresent(for: connection.credential)
        try activateMigratedCredential(
            payload: credentialPayload,
            versionProof: pendingVerification.credentialVersionProof,
            connection: connection
        )
        try deleteLegacyCredentialItemsAfterRevocation(
            for: connection.credential
        )
    }

    func deleteLegacyCredentialItems(
        for reference: ModelCredentialReference
    ) throws {
        try revokeLegacyVerificationIfPresent(for: reference)
        try deleteLegacyCredentialItemsAfterRevocation(for: reference)
    }

    func revokeLegacyVerificationIfPresent(
        for reference: ModelCredentialReference
    ) throws {
        guard reference.versionID == reference.id else { return }
        let verificationAccount = Self.legacyVerificationAccount(
            for: reference.id
        )
        guard let stored = try secrets.read(account: verificationAccount) else {
            return
        }
        let verification = try Self.decodeLegacy(
            LegacyVerificationEnvelope.self,
            from: stored
        )
        guard verification.version == Self.legacyEnvelopeVersion else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        try Self.validateLegacyBinding(verification, against: reference)
        switch verification.state {
        case .active:
            _ = try validatedLegacyCredential(
                for: reference,
                verification: verification
            )
            let revoked = LegacyVerificationEnvelope(
                version: Self.legacyEnvelopeVersion,
                credentialID: verification.credentialID,
                connectionID: verification.connectionID,
                provider: verification.provider,
                allowedHost: verification.allowedHost,
                allowedPort: verification.allowedPort,
                state: .revoked,
                credentialPayloadHash: nil
            )
            let revokedPayload = try Self.encode(revoked)
            try secrets.save(revokedPayload, account: verificationAccount)
            guard try secrets.read(account: verificationAccount)
                    == revokedPayload else {
                throw ModelCredentialRepositoryError.legacyCredentialCleanupFailed
            }
        case .revoked:
            guard verification.credentialPayloadHash == nil else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
        }
    }

    func deleteLegacyCredentialItemsAfterRevocation(
        for reference: ModelCredentialReference
    ) throws {
        guard reference.versionID == reference.id else { return }
        let credentialAccount = Self.legacyCredentialAccount(for: reference.id)
        let verificationAccount = Self.legacyVerificationAccount(
            for: reference.id
        )
        if let verificationPayload = try secrets.read(
            account: verificationAccount
        ) {
            let verification = try Self.decodeLegacy(
                LegacyVerificationEnvelope.self,
                from: verificationPayload
            )
            guard verification.version == Self.legacyEnvelopeVersion,
                  verification.state == .revoked,
                  verification.credentialPayloadHash == nil else {
                throw ModelCredentialRepositoryError.legacyCredentialCleanupFailed
            }
            try Self.validateLegacyBinding(verification, against: reference)
        }
        if let credentialPayload = try secrets.read(account: credentialAccount) {
            let credential = try Self.decodeLegacy(
                LegacyCredentialEnvelope.self,
                from: credentialPayload
            )
            guard credential.version == Self.legacyEnvelopeVersion else {
                throw ModelCredentialRepositoryError.invalidStoredCredential
            }
            try Self.validateLegacyBinding(credential, against: reference)
            try secrets.delete(account: credentialAccount)
            guard try secrets.read(account: credentialAccount) == nil else {
                throw ModelCredentialRepositoryError.legacyCredentialCleanupFailed
            }
        }
        if try secrets.read(account: verificationAccount) != nil {
            try secrets.delete(account: verificationAccount)
            guard try secrets.read(account: verificationAccount) == nil else {
                throw ModelCredentialRepositoryError.legacyCredentialCleanupFailed
            }
        }
    }

    private static var legacyEnvelopeVersion: Int { 1 }
    private static var legacyAccountPrefix: String { "model-credential-v1:" }

    private func activeLegacyCredential(
        for reference: ModelCredentialReference
    ) throws -> LegacyCredentialEnvelope? {
        guard reference.versionID == reference.id else { return nil }
        let credentialAccount = Self.legacyCredentialAccount(for: reference.id)
        let verificationAccount = Self.legacyVerificationAccount(
            for: reference.id
        )
        let credentialPayload = try secrets.read(account: credentialAccount)
        let verificationPayload = try secrets.read(account: verificationAccount)
        guard credentialPayload != nil || verificationPayload != nil else {
            return nil
        }
        guard let verificationPayload else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        let verification = try Self.decodeLegacy(
            LegacyVerificationEnvelope.self,
            from: verificationPayload
        )
        guard verification.version == Self.legacyEnvelopeVersion,
              verification.state == .active else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        try Self.validateLegacyBinding(verification, against: reference)
        guard credentialPayload != nil else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        return try validatedLegacyCredential(
            for: reference,
            verification: verification
        )
    }

    private func validatedLegacyCredential(
        for reference: ModelCredentialReference,
        verification: LegacyVerificationEnvelope
    ) throws -> LegacyCredentialEnvelope {
        let account = Self.legacyCredentialAccount(for: reference.id)
        guard let payload = try secrets.read(account: account) else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        let credential = try Self.decodeLegacy(
            LegacyCredentialEnvelope.self,
            from: payload
        )
        guard credential.version == Self.legacyEnvelopeVersion,
              verification.credentialPayloadHash == Self.payloadHash(payload) else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        try Self.validateLegacyBinding(credential, against: reference)
        do {
            try ModelCredentialSecretValidator.validate(credential.secret)
        } catch {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        return credential
    }

    private func activateMigratedCredential(
        payload: String,
        versionProof: String,
        connection: ModelConnection
    ) throws {
        try writeV2Verification(
            Self.verificationEnvelope(
                payload: payload,
                versionProof: versionProof,
                setupAuthorizationHash: nil,
                connection: connection
            ),
            for: connection.credential.id
        )
    }

    private func writeV2CredentialPayload(
        _ payload: String,
        for credentialID: UUID
    ) throws {
        let account = Self.credentialAccount(for: credentialID)
        try secrets.save(payload, account: account)
        guard try secrets.read(account: account) == payload else {
            throw ModelCredentialRepositoryError.writeVerificationFailed
        }
    }

    private func writeV2Verification(
        _ verification: VerificationEnvelope,
        for credentialID: UUID
    ) throws {
        let payload = try Self.encode(verification)
        let account = Self.verificationAccount(for: credentialID)
        try secrets.save(payload, account: account)
        guard try secrets.read(account: account) == payload else {
            throw ModelCredentialRepositoryError.writeVerificationFailed
        }
    }

    private static func migrationPendingVerification(
        payload: String,
        versionProof: String,
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
            state: .migrationPending,
            credentialPayloadHash: payloadHash(payload),
            setupAuthorizationHash: nil
        )
    }

    private static func decodeLegacy<Value: Decodable>(
        _ type: Value.Type,
        from stored: String
    ) throws -> Value {
        guard let data = stored.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(type, from: data) else {
            throw ModelCredentialRepositoryError.invalidStoredCredential
        }
        return envelope
    }

    private static func validateLegacyBinding(
        _ envelope: LegacyCredentialEnvelope,
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

    private static func validateLegacyBinding(
        _ envelope: LegacyVerificationEnvelope,
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

    private static func makeOpaqueCredentialVersionProof() -> String {
        [UUID(), UUID()]
            .map {
                $0.uuidString
                    .replacingOccurrences(of: "-", with: "")
                    .lowercased()
            }
            .joined()
    }
}
