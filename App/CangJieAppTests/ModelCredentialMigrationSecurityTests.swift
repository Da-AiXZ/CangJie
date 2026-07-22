import CangJieCore
import CryptoKit
import Foundation
import XCTest
@testable import CangJie

final class ModelCredentialMigrationSecurityTests: XCTestCase {
    private final class MemorySecretRepository: SecretRepository {
        private struct InjectedFailure: Error {}

        var values: [String: String] = [:]
        var saveCount = 0
        var ignoredDeleteAccounts: Set<String> = []
        var failBeforeSaveCounts: Set<Int> = []
        var failAfterSaveCounts: Set<Int> = []

        func save(_ secret: String, account: String) throws {
            saveCount += 1
            if failBeforeSaveCounts.contains(saveCount) {
                throw InjectedFailure()
            }
            values[account] = secret
            if failAfterSaveCounts.contains(saveCount) {
                throw InjectedFailure()
            }
        }

        func read(account: String) throws -> String? {
            values[account]
        }

        func contains(account: String) throws -> Bool {
            values[account] != nil
        }

        func delete(account: String) throws {
            guard !ignoredDeleteAccounts.contains(account) else { return }
            values[account] = nil
        }
    }

    private struct LegacyCredentialReaderEnvelope: Decodable {
        let version: Int
        let credentialID: UUID
        let connectionID: UUID
        let provider: ModelProvider
        let allowedHost: String
        let allowedPort: Int?
        let secret: String
    }

    private struct LegacyVerificationReaderEnvelope: Decodable {
        enum State: String, Decodable {
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

    func testLegacyV1CredentialMigratesIntoTheDatabaseAssignedLegacyVersion() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let credentialID = UUID()
        let connection = try makeLegacyConnection(credentialID: credentialID)
        let secret = "legacy-key-value"
        let (legacyCredentialAccount, legacyVerificationAccount) = try installLegacyV1(
            secret: secret,
            for: connection,
            in: secrets
        )

        let resolved = try XCTUnwrap(repository.resolve(for: connection))

        XCTAssertEqual(resolved.reference.versionID, credentialID)
        XCTAssertEqual(resolved.secret, secret)
        XCTAssertEqual(resolved.credentialVersionProof.utf8.count, 64)
        XCTAssertNil(resolved.setupAuthorizationHash)
        XCTAssertNil(try secrets.read(account: legacyCredentialAccount))
        XCTAssertNil(try secrets.read(account: legacyVerificationAccount))
        XCTAssertNotNil(
            try secrets.read(
                account: KeychainModelCredentialRepository.credentialAccount(
                    for: credentialID
                )
            )
        )
        XCTAssertEqual(
            try v2VerificationState(for: connection, secrets: secrets),
            "active"
        )
    }

    func testLegacyMigrationRetriesOnlyFromExplicitPendingState() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeLegacyConnection()
        let secret = "legacy-pre-activation-retry-key"
        let (legacyCredentialAccount, legacyVerificationAccount) = try installLegacyV1(
            secret: secret,
            for: connection,
            in: secrets
        )
        secrets.failBeforeSaveCounts.insert(3)

        XCTAssertThrowsError(try repository.resolve(for: connection))
        XCTAssertEqual(
            try v2VerificationState(for: connection, secrets: secrets),
            "migrationPending"
        )
        let migrationVersionProof = try XCTUnwrap(
            v2VerificationObject(for: connection, secrets: secrets)[
                "credentialVersionProof"
            ] as? String
        )
        XCTAssertEqual(
            try resolveWithLegacyV1Reader(for: connection, secrets: secrets),
            secret
        )

        secrets.failBeforeSaveCounts.removeAll()
        let resolved = try XCTUnwrap(repository.resolve(for: connection))
        XCTAssertEqual(resolved.secret, secret)
        XCTAssertEqual(resolved.credentialVersionProof, migrationVersionProof)
        XCTAssertNil(try resolveWithLegacyV1Reader(for: connection, secrets: secrets))
        XCTAssertNil(try secrets.read(account: legacyCredentialAccount))
        XCTAssertNil(try secrets.read(account: legacyVerificationAccount))
    }

    func testLegacyMigrationIsRecoverableAfterEveryPersistedBoundary() throws {
        for failedSave in 1...4 {
            let secrets = MemorySecretRepository()
            let repository = KeychainModelCredentialRepository(secrets: secrets)
            let connection = try makeLegacyConnection()
            let secret = "legacy-boundary-\(failedSave)"
            _ = try installLegacyV1(
                secret: secret,
                for: connection,
                in: secrets
            )
            secrets.failAfterSaveCounts = [failedSave]

            XCTAssertThrowsError(
                try repository.resolve(for: connection),
                "Boundary \(failedSave) must surface the interrupted Keychain operation"
            )
            XCTAssertEqual(
                try v2VerificationState(for: connection, secrets: secrets),
                failedSave == 4 ? "active" : "migrationPending"
            )
            if failedSave >= 3 {
                XCTAssertNil(
                    try resolveWithLegacyV1Reader(
                        for: connection,
                        secrets: secrets
                    ),
                    "Once v1 is revoked, no later boundary may reactivate it"
                )
            }

            secrets.failAfterSaveCounts.removeAll()
            XCTAssertEqual(try repository.resolve(for: connection)?.secret, secret)
            XCTAssertNil(
                try resolveWithLegacyV1Reader(
                    for: connection,
                    secrets: secrets
                )
            )
        }
    }

    func testGenericRevokedSaveTombstoneNeverResumesLegacyMigration() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeLegacyConnection()
        _ = try installLegacyV1(
            secret: "legacy-key",
            for: connection,
            in: secrets
        )
        secrets.failBeforeSaveCounts = [3]

        XCTAssertThrowsError(
            try saveCredential("replacement-key", in: repository, for: connection)
        )
        XCTAssertEqual(
            try v2VerificationState(for: connection, secrets: secrets),
            "revoked"
        )
        XCTAssertEqual(
            try resolveWithLegacyV1Reader(for: connection, secrets: secrets),
            "legacy-key"
        )

        secrets.failBeforeSaveCounts.removeAll()
        XCTAssertNil(
            try repository.resolve(for: connection),
            "A save/deletion tombstone is not migration authorization"
        )
        XCTAssertEqual(
            try v2VerificationState(for: connection, secrets: secrets),
            "revoked"
        )

        try saveCredential("replacement-key", in: repository, for: connection)
        XCTAssertEqual(
            try repository.resolve(for: connection)?.secret,
            "replacement-key"
        )
        XCTAssertNil(try resolveWithLegacyV1Reader(for: connection, secrets: secrets))
    }

    func testLegacySaveCompensationFailureCannotLeaveV1AndV2Active() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeLegacyConnection()
        _ = try installLegacyV1(
            secret: "legacy-key",
            for: connection,
            in: secrets
        )
        secrets.failAfterSaveCounts = [3]
        secrets.failBeforeSaveCounts = [4]

        XCTAssertThrowsError(
            try saveCredential("replacement-key", in: repository, for: connection)
        ) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .revocationCompensationFailed
            )
        }
        XCTAssertNil(
            try resolveWithLegacyV1Reader(for: connection, secrets: secrets),
            "The v1 marker must be revoked before any v2 activation attempt"
        )
        XCTAssertNil(try repository.resolve(for: connection))
    }

    func testLegacyMigrationRetriesCleanupWithoutLosingActiveV2Evidence() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeLegacyConnection()
        let secret = "legacy-retry-key"
        let (legacyCredentialAccount, legacyVerificationAccount) = try installLegacyV1(
            secret: secret,
            for: connection,
            in: secrets
        )
        secrets.ignoredDeleteAccounts.insert(legacyCredentialAccount)

        XCTAssertThrowsError(try repository.resolve(for: connection)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .legacyCredentialCleanupFailed
            )
        }
        XCTAssertNotNil(try secrets.read(account: legacyCredentialAccount))
        XCTAssertNil(
            try resolveWithLegacyV1Reader(for: connection, secrets: secrets)
        )

        secrets.ignoredDeleteAccounts.remove(legacyCredentialAccount)
        XCTAssertEqual(try repository.resolve(for: connection)?.secret, secret)
        XCTAssertNil(try resolveWithLegacyV1Reader(for: connection, secrets: secrets))
        XCTAssertNil(try secrets.read(account: legacyCredentialAccount))
        XCTAssertNil(try secrets.read(account: legacyVerificationAccount))
    }

    func testLegacyCleanupFailureDuringDeleteCannotReactivateDeletedCredential() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeLegacyConnection()
        try saveCredential("current-key", in: repository, for: connection)
        let (legacyCredentialAccount, legacyVerificationAccount) = try installLegacyV1(
            secret: "legacy-key",
            for: connection,
            in: secrets
        )
        secrets.ignoredDeleteAccounts.insert(legacyCredentialAccount)

        XCTAssertThrowsError(try repository.delete(for: connection)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .legacyCredentialCleanupFailed
            )
        }
        XCTAssertNil(try repository.resolve(for: connection))
        XCTAssertNil(
            try secrets.read(
                account: KeychainModelCredentialRepository.credentialAccount(
                    for: connection.credential.id
                )
            )
        )
        XCTAssertNotNil(try secrets.read(account: legacyCredentialAccount))
        XCTAssertNil(try resolveWithLegacyV1Reader(for: connection, secrets: secrets))

        secrets.ignoredDeleteAccounts.remove(legacyCredentialAccount)
        try repository.delete(for: connection)
        XCTAssertNil(try repository.resolve(for: connection))
        XCTAssertNil(try resolveWithLegacyV1Reader(for: connection, secrets: secrets))
        XCTAssertNil(try secrets.read(account: legacyCredentialAccount))
        XCTAssertNil(try secrets.read(account: legacyVerificationAccount))
    }

    private func makeLegacyConnection(
        credentialID: UUID = UUID()
    ) throws -> ModelConnection {
        try ModelConnectionTestFixture.makeConnection(
            id: UUID(),
            name: "Legacy test connection",
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: credentialID,
            credentialVersionID: credentialID,
            selectedModel: "test-model"
        )
    }

    private func saveCredential(
        _ secret: String,
        in repository: KeychainModelCredentialRepository,
        for connection: ModelConnection
    ) throws {
        try repository.save(
            secret,
            versionProof: versionProof(for: connection),
            for: connection
        )
    }

    private func v2VerificationState(
        for connection: ModelConnection,
        secrets: MemorySecretRepository
    ) throws -> String? {
        try v2VerificationObject(for: connection, secrets: secrets)["state"] as? String
    }

    private func v2VerificationObject(
        for connection: ModelConnection,
        secrets: MemorySecretRepository
    ) throws -> [String: Any] {
        let payload = try XCTUnwrap(
            secrets.read(
                account: KeychainModelCredentialRepository.verificationAccount(
                    for: connection.credential.id
                )
            )
        )
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any]
        )
    }

    private func versionProof(for connection: ModelConnection) -> String {
        let compact = connection.credential.versionID.uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
        return compact + compact
    }

    private func installLegacyV1(
        secret: String,
        for connection: ModelConnection,
        in secrets: MemorySecretRepository
    ) throws -> (String, String) {
        var credentialObject: [String: Any] = [
            "version": 1,
            "credentialID": connection.credential.id.uuidString,
            "connectionID": connection.id.uuidString,
            "provider": connection.provider.rawValue,
            "allowedHost": connection.credential.allowedHost,
            "secret": secret
        ]
        if let port = connection.credential.allowedPort {
            credentialObject["allowedPort"] = port
        }
        let credentialPayload = try encodedJSONObject(credentialObject)
        var verificationObject = credentialObject
        verificationObject["secret"] = nil
        verificationObject["state"] = "active"
        verificationObject["credentialPayloadHash"] = payloadHash(credentialPayload)
        let verificationPayload = try encodedJSONObject(verificationObject)
        let credentialAccount = KeychainModelCredentialRepository
            .legacyCredentialAccount(for: connection.credential.id)
        let verificationAccount = KeychainModelCredentialRepository
            .legacyVerificationAccount(for: connection.credential.id)
        secrets.values[credentialAccount] = credentialPayload
        secrets.values[verificationAccount] = verificationPayload
        return (credentialAccount, verificationAccount)
    }

    private func encodedJSONObject(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func resolveWithLegacyV1Reader(
        for connection: ModelConnection,
        secrets: MemorySecretRepository
    ) throws -> String? {
        let credentialAccount = KeychainModelCredentialRepository
            .legacyCredentialAccount(for: connection.credential.id)
        let verificationAccount = KeychainModelCredentialRepository
            .legacyVerificationAccount(for: connection.credential.id)
        guard let credentialPayload = try secrets.read(account: credentialAccount),
              let verificationPayload = try secrets.read(account: verificationAccount),
              let credentialData = credentialPayload.data(using: .utf8),
              let verificationData = verificationPayload.data(using: .utf8),
              let credential = try? JSONDecoder().decode(
                LegacyCredentialReaderEnvelope.self,
                from: credentialData
              ),
              let verification = try? JSONDecoder().decode(
                LegacyVerificationReaderEnvelope.self,
                from: verificationData
              ),
              credential.version == 1,
              verification.version == 1,
              verification.state == .active,
              credential.credentialID == connection.credential.id,
              credential.connectionID == connection.id,
              credential.provider == connection.provider,
              credential.allowedHost == connection.credential.allowedHost,
              credential.allowedPort == connection.credential.allowedPort,
              verification.credentialID == credential.credentialID,
              verification.connectionID == credential.connectionID,
              verification.provider == credential.provider,
              verification.allowedHost == credential.allowedHost,
              verification.allowedPort == credential.allowedPort,
              verification.credentialPayloadHash == payloadHash(credentialPayload) else {
            return nil
        }
        return credential.secret
    }

    private func payloadHash(_ payload: String) -> String {
        SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
