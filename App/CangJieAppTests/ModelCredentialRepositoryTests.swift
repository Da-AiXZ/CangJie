import CangJieCore
import Foundation
import XCTest
@testable import CangJie

final class ModelCredentialRepositoryTests: XCTestCase {
    private final class MemorySecretRepository: SecretRepository {
        private struct InjectedFailure: Error {}

        var values: [String: String] = [:]
        var saveCount = 0
        var discardWrites = false
        var ignoreDeletes = false
        var ignoredDeleteAccounts: Set<String> = []
        var failBeforeSaveCounts: Set<Int> = []
        var failAfterSaveCounts: Set<Int> = []
        var transformNextSaveAccount: String?
        var transformNextSave: ((String) throws -> String)?

        func save(_ secret: String, account: String) throws {
            saveCount += 1
            if failBeforeSaveCounts.contains(saveCount) {
                throw InjectedFailure()
            }
            guard !discardWrites else { return }
            if let transformNextSave,
               transformNextSaveAccount == nil || transformNextSaveAccount == account {
                self.transformNextSave = nil
                transformNextSaveAccount = nil
                values[account] = try transformNextSave(secret)
            } else {
                values[account] = secret
            }
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
            guard !ignoreDeletes, !ignoredDeleteAccounts.contains(account) else { return }
            values[account] = nil
        }
    }

    func testSaveAndResolveRoundTripPreservesExactBindingAndSecret() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()
        let secret = "fixture-key-value"
        let setupAuthorizationHash = String(repeating: "c", count: 64)

        try saveCredential(
            secret,
            setupAuthorizationHash: setupAuthorizationHash,
            in: repository,
            for: connection
        )

        let account = KeychainModelCredentialRepository.credentialAccount(
            for: connection.credential.id
        )
        XCTAssertNotEqual(try secrets.read(account: account), secret)
        XCTAssertNotNil(
            try secrets.read(
                account: KeychainModelCredentialRepository.verificationAccount(
                    for: connection.credential.id
                )
            )
        )
        let resolved = try XCTUnwrap(repository.resolve(for: connection))
        XCTAssertEqual(resolved.reference, connection.credential)
        XCTAssertEqual(resolved.secret, secret)
        XCTAssertEqual(
            resolved.credentialVersionProof,
            versionProof(for: connection)
        )
        XCTAssertEqual(resolved.credentialPayloadHash.utf8.count, 64)
        XCTAssertEqual(
            resolved.setupAuthorizationHash,
            setupAuthorizationHash
        )
        let credentialObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(try XCTUnwrap(secrets.read(account: account)).utf8)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            credentialObject["setupAuthorizationHash"] as? String,
            setupAuthorizationHash
        )
        let verificationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(
                    try XCTUnwrap(
                        secrets.read(
                            account: KeychainModelCredentialRepository.verificationAccount(
                                for: connection.credential.id
                            )
                        )
                    ).utf8
                )
            ) as? [String: Any]
        )
        XCTAssertEqual(
            verificationObject["setupAuthorizationHash"] as? String,
            setupAuthorizationHash
        )
        XCTAssertEqual(
            try repository.verifiedConnection(for: connection)?.connection,
            connection
        )

        XCTAssertThrowsError(
            try saveCredential(
                "replacement-fixture-key",
                in: repository,
                for: connection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .credentialVersionConflict
            )
        }
        XCTAssertEqual(try repository.resolve(for: connection)?.secret, secret)
    }

    func testNewCredentialVersionInvalidatesThePreviousConnectionSnapshot() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connectionID = UUID()
        let credentialID = UUID()
        let first = try makeConnection(
            id: connectionID,
            credentialID: credentialID,
            credentialVersionID: UUID()
        )
        let rotated = try makeConnection(
            id: connectionID,
            credentialID: credentialID,
            credentialVersionID: UUID()
        )

        try saveCredential("first-version-key", in: repository, for: first)
        try saveCredential("rotated-version-key", in: repository, for: rotated)

        XCTAssertThrowsError(try repository.resolve(for: first)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .credentialBindingMismatch
            )
        }
        XCTAssertEqual(
            try repository.resolve(for: rotated)?.secret,
            "rotated-version-key"
        )
    }

    func testInvalidSecretFailsBeforeAnyKeychainMutation() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()

        XCTAssertThrowsError(
            try saveCredential("   ", in: repository, for: connection)
        ) { error in
            XCTAssertEqual(error as? ModelCredentialRepositoryError, .emptySecret)
        }
        XCTAssertThrowsError(
            try saveCredential(
                String(
                    repeating: "k",
                    count: KeychainModelCredentialRepository.maximumSecretUTF8Bytes + 1
                ),
                in: repository,
                for: connection
            )
        ) { error in
            XCTAssertEqual(error as? ModelCredentialRepositoryError, .secretTooLarge)
        }
        XCTAssertThrowsError(
            try saveCredential(
                "line-one\nline-two",
                in: repository,
                for: connection
            )
        ) { error in
            XCTAssertEqual(error as? ModelCredentialRepositoryError, .invalidSecret)
        }
        XCTAssertEqual(secrets.saveCount, 0)
        XCTAssertTrue(secrets.values.isEmpty)
    }

    func testInvalidSetupAuthorizationHashFailsBeforeAnyKeychainMutation() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()

        XCTAssertThrowsError(
            try repository.save(
                "fixture-key-value",
                versionProof: versionProof(for: connection),
                setupAuthorizationHash: String(repeating: "A", count: 64),
                for: connection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .invalidStoredCredential
            )
        }
        XCTAssertEqual(secrets.saveCount, 0)
        XCTAssertTrue(secrets.values.isEmpty)
    }

    func testExistingCredentialCannotBeOverwrittenThroughAnotherBinding() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let credentialID = UUID()
        let original = try makeConnection(
            id: UUID(),
            credentialID: credentialID,
            provider: .custom,
            baseURL: URL(string: "https://models.example.com:8443/v1")!
        )
        let retargeted = try makeConnection(
            id: UUID(),
            credentialID: credentialID,
            provider: .custom,
            baseURL: URL(string: "https://other.example.com:9443/v1")!
        )
        try saveCredential("original-key", in: repository, for: original)
        let account = KeychainModelCredentialRepository.credentialAccount(
            for: credentialID
        )
        let before = try XCTUnwrap(secrets.read(account: account))

        XCTAssertThrowsError(
            try saveCredential(
                "replacement-key",
                in: repository,
                for: retargeted
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .credentialBindingMismatch
            )
        }
        XCTAssertEqual(try secrets.read(account: account), before)
        XCTAssertEqual(
            try repository.resolve(for: original)?.secret,
            "original-key"
        )
    }

    func testResolveRejectsTamperedBindingAndMalformedEnvelope() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()
        try saveCredential("fixture-key-value", in: repository, for: connection)
        let account = KeychainModelCredentialRepository.credentialAccount(
            for: connection.credential.id
        )
        let raw = try XCTUnwrap(secrets.read(account: account))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        )
        object["allowedHost"] = "attacker.example"
        secrets.values[account] = try XCTUnwrap(
            String(
                data: JSONSerialization.data(withJSONObject: object),
                encoding: .utf8
            )
        )

        XCTAssertThrowsError(try repository.resolve(for: connection)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .credentialBindingMismatch
            )
        }

        secrets.values[account] = "{}"
        XCTAssertThrowsError(try repository.resolve(for: connection)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .invalidStoredCredential
            )
        }
    }

    func testResolveRejectsSetupAuthorizationMismatchBetweenPayloadAndMarker() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()
        try saveCredential(
            "fixture-key-value",
            setupAuthorizationHash: String(repeating: "c", count: 64),
            in: repository,
            for: connection
        )
        let verificationAccount = KeychainModelCredentialRepository.verificationAccount(
            for: connection.credential.id
        )
        let raw = try XCTUnwrap(secrets.read(account: verificationAccount))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        )
        object["setupAuthorizationHash"] = String(repeating: "d", count: 64)
        secrets.values[verificationAccount] = try XCTUnwrap(
            String(
                data: JSONSerialization.data(
                    withJSONObject: object,
                    options: [.sortedKeys, .withoutEscapingSlashes]
                ),
                encoding: .utf8
            )
        )

        XCTAssertThrowsError(try repository.resolve(for: connection)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .invalidStoredCredential
            )
        }
    }

    func testDeleteRequiresExactBindingAndVerifiesRemoval() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let credentialID = UUID()
        let original = try makeConnection(id: UUID(), credentialID: credentialID)
        let other = try makeConnection(id: UUID(), credentialID: credentialID)
        try saveCredential("fixture-key-value", in: repository, for: original)

        XCTAssertThrowsError(try repository.delete(for: other)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .credentialBindingMismatch
            )
        }
        XCTAssertNotNil(try repository.resolve(for: original))

        try repository.delete(for: original)
        XCTAssertNil(try repository.resolve(for: original))
    }

    func testReadAfterWriteVerificationFailureFailsClosed() throws {
        let secrets = MemorySecretRepository()
        secrets.discardWrites = true
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()

        XCTAssertThrowsError(
            try saveCredential(
                "fixture-key-value",
                in: repository,
                for: connection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .writeVerificationFailed
            )
        }
        XCTAssertNil(try repository.resolve(for: connection))
    }

    func testAlteredCredentialWriteRemainsInactiveWithoutActiveVerificationMarker() throws {
        let secrets = MemorySecretRepository()
        let connection = try makeConnection()
        secrets.transformNextSaveAccount = KeychainModelCredentialRepository.credentialAccount(
            for: connection.credential.id
        )
        secrets.transformNextSave = { raw in
            var object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
            )
            object["secret"] = "altered-key"
            return try XCTUnwrap(
                String(
                    data: JSONSerialization.data(withJSONObject: object),
                    encoding: .utf8
                )
            )
        }
        let repository = KeychainModelCredentialRepository(secrets: secrets)

        XCTAssertThrowsError(
            try saveCredential(
                "fixture-key-value",
                in: repository,
                for: connection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .writeVerificationFailed
            )
        }
        XCTAssertNotNil(
            try secrets.read(
                account: KeychainModelCredentialRepository.verificationAccount(
                    for: connection.credential.id
                )
            )
        )
        XCTAssertNil(try repository.resolve(for: connection))
    }

    func testActivationFailureAndRevocationFailureAreReportedExplicitly() throws {
        let secrets = MemorySecretRepository()
        secrets.failAfterSaveCounts = [3]
        secrets.failBeforeSaveCounts = [4]
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()

        XCTAssertThrowsError(
            try saveCredential(
                "fixture-key-value",
                in: repository,
                for: connection
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .revocationCompensationFailed
            )
        }
        XCTAssertEqual(
            try repository.resolve(for: connection)?.secret,
            "fixture-key-value",
            "The explicit unsafe-compensation error must not be mistaken for a clean rollback"
        )
    }

    func testDeleteFailureAfterRevocationNeverLeavesTheCredentialActive() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()
        try saveCredential("fixture-key-value", in: repository, for: connection)
        secrets.ignoreDeletes = true

        XCTAssertThrowsError(try repository.delete(for: connection)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .deleteVerificationFailed
            )
        }
        XCTAssertNil(try repository.resolve(for: connection))

        secrets.ignoreDeletes = false
        try repository.delete(for: connection)
        XCTAssertNil(try repository.resolve(for: connection))
    }

    func testPayloadDeleteFailureLeavesOnlyAnInactiveOrphan() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()
        try saveCredential("fixture-key-value", in: repository, for: connection)
        let credentialAccount = KeychainModelCredentialRepository.credentialAccount(
            for: connection.credential.id
        )
        let verificationAccount = KeychainModelCredentialRepository.verificationAccount(
            for: connection.credential.id
        )
        secrets.ignoredDeleteAccounts.insert(credentialAccount)

        XCTAssertThrowsError(try repository.delete(for: connection)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .deleteVerificationFailed
            )
        }
        XCTAssertNotNil(try secrets.read(account: verificationAccount))
        XCTAssertNotNil(try secrets.read(account: credentialAccount))
        XCTAssertNil(try repository.resolve(for: connection))

        secrets.ignoredDeleteAccounts.remove(credentialAccount)
        try repository.delete(for: connection)
        XCTAssertNil(try secrets.read(account: credentialAccount))
    }

    func testVerificationMarkerCleanupFailureRemainsRevoked() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()
        try saveCredential("fixture-key-value", in: repository, for: connection)
        let credentialAccount = KeychainModelCredentialRepository.credentialAccount(
            for: connection.credential.id
        )
        let verificationAccount = KeychainModelCredentialRepository.verificationAccount(
            for: connection.credential.id
        )
        secrets.ignoredDeleteAccounts.insert(verificationAccount)

        XCTAssertThrowsError(try repository.delete(for: connection)) { error in
            XCTAssertEqual(
                error as? ModelCredentialRepositoryError,
                .deleteVerificationFailed
            )
        }
        XCTAssertNil(try secrets.read(account: credentialAccount))
        XCTAssertNotNil(try secrets.read(account: verificationAccount))
        XCTAssertNil(try repository.resolve(for: connection))

        secrets.ignoredDeleteAccounts.remove(verificationAccount)
        try repository.delete(for: connection)
        XCTAssertNil(try secrets.read(account: verificationAccount))
    }

    func testProductionKeychainRepositoryPersistsTheBoundEnvelope() throws {
        let repository = KeychainModelCredentialRepository()
        let connection = try makeConnection()
        let secret = "signed-simulator-fixture-key"
        defer { try? repository.delete(for: connection) }

        try saveCredential(secret, in: repository, for: connection)
        let rawKeychain = KeychainSecretRepository()
        XCTAssertNotEqual(
            try rawKeychain.read(
                account: KeychainModelCredentialRepository.credentialAccount(
                    for: connection.credential.id
                )
            ),
            secret
        )
        XCTAssertNotNil(
            try rawKeychain.read(
                account: KeychainModelCredentialRepository.verificationAccount(
                    for: connection.credential.id
                )
            )
        )
        XCTAssertEqual(try repository.resolve(for: connection)?.secret, secret)

        try repository.delete(for: connection)
        XCTAssertNil(try repository.resolve(for: connection))
    }

    private func makeConnection(
        id: UUID = UUID(),
        credentialID: UUID = UUID(),
        credentialVersionID: UUID = UUID(),
        provider: ModelProvider = .openAI,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!
    ) throws -> ModelConnection {
        try ModelConnectionTestFixture.makeConnection(
            id: id,
            name: "Test connection",
            provider: provider,
            baseURL: baseURL,
            credentialID: credentialID,
            credentialVersionID: credentialVersionID,
            selectedModel: "test-model"
        )
    }

    private func saveCredential(
        _ secret: String,
        setupAuthorizationHash: String? = nil,
        in repository: KeychainModelCredentialRepository,
        for connection: ModelConnection
    ) throws {
        try repository.save(
            secret,
            versionProof: versionProof(for: connection),
            setupAuthorizationHash: setupAuthorizationHash,
            for: connection
        )
    }

    private func versionProof(for connection: ModelConnection) -> String {
        let compact = connection.credential.versionID.uuidString
            .replacingOccurrences(of: "-", with: "").lowercased()
        return compact + compact
    }
}
