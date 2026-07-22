import CangJieCore
import Dispatch
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class RecordingCredentialRepository: ModelCredentialRepository {
    var credentials: [UUID: KeychainBoundModelCredential] = [:]
    var failSave = false
    var failNextSaveAfterMutation = false
    var failDelete = false
    var suppressResolve = false
    var blockVerificationResolve = false
    var credentialPayloadHash = String(repeating: "a", count: 64)
    var events: [String] = []
    let verificationResolveStarted = DispatchSemaphore(value: 0)
    let verificationResolveMayFinish = DispatchSemaphore(value: 0)
    private var resolveCount = 0

    func save(
        _ secret: String,
        versionProof: String,
        setupAuthorizationHash: String?,
        for connection: ModelConnection
    ) throws {
        events.append("credential.save")
        if failSave { throw Failure.save }
        if let existing = credentials[connection.credential.id],
           existing.reference != connection.credential {
            throw ModelCredentialRepositoryError.credentialBindingMismatch
        }
        credentials[connection.credential.id] = KeychainBoundModelCredential(
            reference: connection.credential,
            secret: secret,
            credentialVersionProof: versionProof,
            credentialPayloadHash: credentialPayloadHash,
            setupAuthorizationHash: setupAuthorizationHash
        )
        if failNextSaveAfterMutation {
            failNextSaveAfterMutation = false
            throw Failure.save
        }
    }

    func resolve(for connection: ModelConnection) throws -> KeychainBoundModelCredential? {
        events.append("credential.resolve")
        resolveCount += 1
        if blockVerificationResolve, resolveCount == 2 {
            verificationResolveStarted.signal()
            verificationResolveMayFinish.wait()
        }
        guard !suppressResolve else { return nil }
        guard let credential = credentials[connection.credential.id] else { return nil }
        guard credential.reference == connection.credential else {
            throw ModelCredentialRepositoryError.credentialBindingMismatch
        }
        return credential
    }

    func delete(for connection: ModelConnection) throws {
        events.append("credential.delete")
        if failDelete { throw Failure.delete }
        if let existing = credentials[connection.credential.id],
           existing.reference != connection.credential {
            throw ModelCredentialRepositoryError.credentialBindingMismatch
        }
        credentials[connection.credential.id] = nil
    }

    enum Failure: Error, Equatable {
        case save
        case delete
    }
}

protocol ModelConnectionSetupServiceTestSupport: AnyObject {}

extension ModelConnectionSetupServiceTestSupport where Self: XCTestCase {
    func makeConnection(
        id: UUID = UUID(),
        credentialID: UUID = UUID()
    ) throws -> ModelConnection {
        try ModelConnectionTestFixture.makeConnection(
            id: id,
            name: "Setup test",
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: credentialID,
            selectedModel: "test-model"
        )
    }

    func makeCandidate(
        for connection: ModelConnection? = nil,
        secret: String
    ) throws -> ModelConnectionSetupCandidate {
        let resolvedConnection: ModelConnection
        if let connection {
            resolvedConnection = connection
        } else {
            resolvedConnection = try makeConnection()
        }
        let candidate = try ModelConnectionTestFixture.makeSetupCandidate(
            id: resolvedConnection.id,
            name: resolvedConnection.name,
            provider: resolvedConnection.provider,
            baseURL: resolvedConnection.baseURL,
            credentialID: resolvedConnection.credential.id,
            credentialVersionID: resolvedConnection.credential.versionID,
            selectedModel: resolvedConnection.selectedModel,
            secret: secret
        )
        XCTAssertEqual(candidate.connection, resolvedConnection)
        return candidate
    }

    func withTemporaryDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(
            AppDatabase(path: directory.appendingPathComponent("test.sqlite").path)
        )
    }

    func installModelConnectionCommitFailure(
        in database: AppDatabase
    ) throws {
        try database.queue.write { db in
            try db.execute(sql: """
                CREATE TRIGGER fail_model_connection_setup_commit
                BEFORE INSERT ON modelConnection
                BEGIN
                    SELECT RAISE(ABORT, 'injected model connection setup commit failure');
                END
                """)
        }
    }

    func installModelConnectionJournalDeleteFailure(
        in database: AppDatabase
    ) throws {
        try database.queue.write { db in
            try db.execute(sql: """
                CREATE TRIGGER fail_model_connection_setup_journal_delete
                BEFORE DELETE ON modelConnectionSetupJournal
                BEGIN
                    SELECT RAISE(ABORT, 'injected setup journal delete failure');
                END
                """)
        }
    }
}

extension ModelConnectionSetupService {
    func persist(
        _ candidate: ModelConnectionSetupCandidate,
        makeCurrent: Bool,
        now: Date = Date()
    ) throws -> StoredModelConnection {
        try persist(
            candidate,
            expectedCredentialBinding: candidate.credentialBinding,
            makeCurrent: makeCurrent,
            now: now
        )
    }
}
