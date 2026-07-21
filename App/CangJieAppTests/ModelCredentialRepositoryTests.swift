import CangJieCore
import Foundation
import XCTest
@testable import CangJie

final class ModelCredentialRepositoryTests: XCTestCase {
    private final class MemorySecretRepository: SecretRepository {
        var values: [String: String] = [:]
        var saveCount = 0
        var discardWrites = false
        var ignoreDeletes = false
        var ignoredDeleteAccounts: Set<String> = []
        var transformNextSaveAccount: String?
        var transformNextSave: ((String) throws -> String)?

        func save(_ secret: String, account: String) throws {
            saveCount += 1
            guard !discardWrites else { return }
            if let transformNextSave,
               transformNextSaveAccount == nil || transformNextSaveAccount == account {
                self.transformNextSave = nil
                transformNextSaveAccount = nil
                values[account] = try transformNextSave(secret)
            } else {
                values[account] = secret
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

        try repository.save(secret, for: connection)

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
        XCTAssertEqual(
            try repository.resolve(for: connection),
            KeychainBoundModelCredential(
                reference: connection.credential,
                secret: secret
            )
        )

        try repository.save("replacement-fixture-key", for: connection)
        XCTAssertEqual(
            try repository.resolve(for: connection)?.secret,
            "replacement-fixture-key"
        )
    }

    func testInvalidSecretFailsBeforeAnyKeychainMutation() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()

        XCTAssertThrowsError(try repository.save("   ", for: connection)) { error in
            XCTAssertEqual(error as? ModelCredentialRepositoryError, .emptySecret)
        }
        XCTAssertThrowsError(
            try repository.save(
                String(
                    repeating: "k",
                    count: KeychainModelCredentialRepository.maximumSecretUTF8Bytes + 1
                ),
                for: connection
            )
        ) { error in
            XCTAssertEqual(error as? ModelCredentialRepositoryError, .secretTooLarge)
        }
        XCTAssertThrowsError(
            try repository.save("line-one\nline-two", for: connection)
        ) { error in
            XCTAssertEqual(error as? ModelCredentialRepositoryError, .invalidSecret)
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
        try repository.save("original-key", for: original)
        let account = KeychainModelCredentialRepository.credentialAccount(
            for: credentialID
        )
        let before = try XCTUnwrap(secrets.read(account: account))

        XCTAssertThrowsError(
            try repository.save("replacement-key", for: retargeted)
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
        try repository.save("fixture-key-value", for: connection)
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

    func testDeleteRequiresExactBindingAndVerifiesRemoval() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let credentialID = UUID()
        let original = try makeConnection(id: UUID(), credentialID: credentialID)
        let other = try makeConnection(id: UUID(), credentialID: credentialID)
        try repository.save("fixture-key-value", for: original)

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
            try repository.save("fixture-key-value", for: connection)
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
            try repository.save("fixture-key-value", for: connection)
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

    func testDeleteFailureAfterRevocationNeverLeavesTheCredentialActive() throws {
        let secrets = MemorySecretRepository()
        let repository = KeychainModelCredentialRepository(secrets: secrets)
        let connection = try makeConnection()
        try repository.save("fixture-key-value", for: connection)
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
        try repository.save("fixture-key-value", for: connection)
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
        try repository.save("fixture-key-value", for: connection)
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

        try repository.save(secret, for: connection)
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
        provider: ModelProvider = .openAI,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!
    ) throws -> ModelConnection {
        try ModelConnection.make(
            id: id,
            name: "Test connection",
            provider: provider,
            baseURL: baseURL,
            credentialID: credentialID,
            selectedModel: "test-model"
        )
    }
}
