import CangJieCore
import Dispatch
import Foundation
import XCTest
@testable import CangJie

final class ModelConnectionSetupServiceTests: XCTestCase {
    private final class LockedErrorCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var storedError: Error?

        func store(_ error: Error) {
            lock.lock()
            storedError = error
            lock.unlock()
        }

        func load() -> Error? {
            lock.lock()
            defer { lock.unlock() }
            return storedError
        }
    }

    private final class RecordingCredentialRepository: ModelCredentialRepository {
        var credentials: [UUID: KeychainBoundModelCredential] = [:]
        var failSave = false
        var failNextSaveAfterMutation = false
        var failDelete = false
        var suppressResolve = false
        var blockVerificationResolve = false
        var events: [String] = []
        let verificationResolveStarted = DispatchSemaphore(value: 0)
        let verificationResolveMayFinish = DispatchSemaphore(value: 0)
        private var resolveCount = 0

        func save(_ secret: String, for connection: ModelConnection) throws {
            events.append("credential.save")
            if failSave { throw Failure.save }
            if let existing = credentials[connection.credential.id],
               existing.reference != connection.credential {
                throw ModelCredentialRepositoryError.credentialBindingMismatch
            }
            credentials[connection.credential.id] = KeychainBoundModelCredential(
                reference: connection.credential,
                secret: secret
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

    func testVerifiedCredentialIsSavedBeforeMetadataAndCurrentSelection() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let connection = try makeConnection()

            let stored = try service.persist(
                connection: connection,
                secret: "fixture-key-value",
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_000)
            )

            XCTAssertEqual(stored.connection, connection)
            XCTAssertEqual(try database.currentModelConnection(), stored)
            XCTAssertEqual(
                try credentials.resolve(for: connection)?.secret,
                "fixture-key-value"
            )
            XCTAssertEqual(
                Array(credentials.events.prefix(3)),
                ["credential.resolve", "credential.save", "credential.resolve"]
            )
            XCTAssertNil(try database.latestToolReceipt())
        }
    }

    func testCredentialSaveFailureLeavesNoSQLiteMetadata() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            credentials.failSave = true
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )

            XCTAssertThrowsError(
                try service.persist(
                    connection: makeConnection(),
                    secret: "fixture-key-value",
                    makeCurrent: true
                )
            )
            XCTAssertTrue(try database.listModelConnections().isEmpty)
            XCTAssertNil(try database.currentModelConnection())
        }
    }

    func testCredentialSaveFailureAfterMutationRestoresPreviousCredential() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let connection = try makeConnection()
            credentials.credentials[connection.credential.id] = KeychainBoundModelCredential(
                reference: connection.credential,
                secret: "previous-key"
            )
            credentials.failNextSaveAfterMutation = true
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )

            XCTAssertThrowsError(
                try service.persist(
                    connection: connection,
                    secret: "replacement-key",
                    makeCurrent: false
                )
            ) { error in
                XCTAssertEqual(
                    error as? RecordingCredentialRepository.Failure,
                    .save
                )
            }
            XCTAssertEqual(
                credentials.credentials[connection.credential.id]?.secret,
                "previous-key"
            )
            XCTAssertTrue(try database.listModelConnections().isEmpty)
        }
    }

    func testMissingReadBackCompensatesCredentialAndLeavesNoMetadata() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            credentials.suppressResolve = true
            let connection = try makeConnection()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )

            XCTAssertThrowsError(
                try service.persist(
                    connection: connection,
                    secret: "fixture-key-value",
                    makeCurrent: false
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionSetupError,
                    .credentialVerificationFailed
                )
            }
            XCTAssertNil(credentials.credentials[connection.credential.id])
            XCTAssertTrue(try database.listModelConnections().isEmpty)
        }
    }

    func testCredentialIDConflictLeavesPreviousCredentialUntouched() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let credentialID = UUID()
            let storedConnection = try makeConnection(
                id: UUID(),
                credentialID: credentialID
            )
            _ = try database.storeModelConnection(
                storedConnection,
                makeCurrent: false,
                now: Date(timeIntervalSince1970: 3_010)
            )
            let conflicting = try makeConnection(
                id: UUID(),
                credentialID: credentialID
            )
            credentials.credentials[credentialID] = KeychainBoundModelCredential(
                reference: conflicting.credential,
                secret: "previous-orphan-key"
            )
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )

            XCTAssertThrowsError(
                try service.persist(
                    connection: conflicting,
                    secret: "replacement-key",
                    makeCurrent: false,
                    now: Date(timeIntervalSince1970: 3_011)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
            XCTAssertEqual(
                credentials.credentials[credentialID]?.secret,
                "previous-orphan-key"
            )
            XCTAssertEqual(
                try database.listModelConnections().map(\.connection),
                [storedConnection]
            )
            XCTAssertTrue(credentials.events.isEmpty)
        }
    }

    func testCredentialIDConflictDoesNotCreateANewCredential() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let credentialID = UUID()
            let storedConnection = try makeConnection(
                id: UUID(),
                credentialID: credentialID
            )
            _ = try database.storeModelConnection(
                storedConnection,
                makeCurrent: false,
                now: Date(timeIntervalSince1970: 3_020)
            )
            let conflicting = try makeConnection(
                id: UUID(),
                credentialID: credentialID
            )
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )

            XCTAssertThrowsError(
                try service.persist(
                    connection: conflicting,
                    secret: "new-key",
                    makeCurrent: false,
                    now: Date(timeIntervalSince1970: 3_021)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
            XCTAssertNil(credentials.credentials[credentialID])
            XCTAssertEqual(
                try database.listModelConnections().map(\.connection),
                [storedConnection]
            )
            XCTAssertTrue(credentials.events.isEmpty)
        }
    }

    func testDatabaseFailureRestoresThePreviousCredential() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let connection = try makeConnection()
            credentials.credentials[connection.credential.id] = KeychainBoundModelCredential(
                reference: connection.credential,
                secret: "previous-key"
            )
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )

            XCTAssertThrowsError(
                try service.persist(
                    connection: connection,
                    secret: "replacement-key",
                    makeCurrent: false,
                    now: Date(timeIntervalSinceReferenceDate: .infinity)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidModelConnection)
            }
            XCTAssertEqual(
                credentials.credentials[connection.credential.id]?.secret,
                "previous-key"
            )
            XCTAssertTrue(try database.listModelConnections().isEmpty)
        }
    }

    func testDatabaseFailureDeletesANewCredentialWithoutMetadata() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let connection = try makeConnection()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )

            XCTAssertThrowsError(
                try service.persist(
                    connection: connection,
                    secret: "new-key",
                    makeCurrent: false,
                    now: Date(timeIntervalSinceReferenceDate: .infinity)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidModelConnection)
            }
            XCTAssertNil(credentials.credentials[connection.credential.id])
            XCTAssertTrue(try database.listModelConnections().isEmpty)
        }
    }

    func testLateReplayCannotOverrideANewerExplicitCurrentSelection() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let first = try makeConnection()
            let second = try makeConnection()
            _ = try service.persist(
                connection: first,
                secret: "first-key",
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_030)
            )
            let selected = try service.persist(
                connection: second,
                secret: "second-key",
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_031)
            )
            let eventsBeforeReplay = credentials.events.count

            _ = try service.persist(
                connection: first,
                secret: "first-key",
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_032)
            )

            XCTAssertEqual(try database.currentModelConnection(), selected)
            XCTAssertEqual(
                Array(credentials.events.dropFirst(eventsBeforeReplay)),
                ["credential.resolve"]
            )
        }
    }

    func testLateReplayCannotRollbackANewerCredential() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let connection = try makeConnection()
            let stored = try service.persist(
                connection: connection,
                secret: "original-key",
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_040)
            )
            try credentials.save("newer-key", for: connection)

            XCTAssertThrowsError(
                try service.persist(
                    connection: connection,
                    secret: "original-key",
                    makeCurrent: true,
                    now: Date(timeIntervalSince1970: 3_041)
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionSetupError,
                    .credentialReplayConflict
                )
            }
            XCTAssertEqual(
                try credentials.resolve(for: connection)?.secret,
                "newer-key"
            )
            XCTAssertEqual(try database.currentModelConnection(), stored)
        }
    }

    func testSetupHoldsTheSharedCredentialCoordinatorAcrossVerification() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            credentials.blockVerificationResolve = true
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let connection = try makeConnection()
            let setupFinished = expectation(description: "setup finishes")
            let competitorFinished = expectation(description: "competitor finishes")
            let competitorAttempted = DispatchSemaphore(value: 0)
            let competitorEntered = DispatchSemaphore(value: 0)
            let setupError = LockedErrorCapture()

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    _ = try service.persist(
                        connection: connection,
                        secret: "fixture-key-value",
                        makeCurrent: false
                    )
                } catch {
                    setupError.store(error)
                }
                setupFinished.fulfill()
            }

            XCTAssertEqual(
                credentials.verificationResolveStarted.wait(timeout: .now() + 2),
                .success
            )
            DispatchQueue.global(qos: .userInitiated).async {
                competitorAttempted.signal()
                _ = ModelCredentialOperationCoordinator.withExclusiveAccess {
                    competitorEntered.signal()
                }
                competitorFinished.fulfill()
            }
            XCTAssertEqual(
                competitorAttempted.wait(timeout: .now() + 2),
                .success
            )
            XCTAssertEqual(
                competitorEntered.wait(timeout: .now() + 0.1),
                .timedOut
            )

            credentials.verificationResolveMayFinish.signal()
            wait(for: [setupFinished, competitorFinished], timeout: 2)
            XCTAssertEqual(
                competitorEntered.wait(timeout: .now() + 2),
                .success
            )
            XCTAssertNil(setupError.load())
        }
    }

    func testCompensationFailureIsReportedExplicitly() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            credentials.suppressResolve = true
            credentials.failDelete = true
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )

            XCTAssertThrowsError(
                try service.persist(
                    connection: makeConnection(),
                    secret: "fixture-key-value",
                    makeCurrent: false
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionSetupError,
                    .credentialCompensationFailed
                )
            }
            XCTAssertTrue(try database.listModelConnections().isEmpty)
        }
    }

    private func makeConnection(
        id: UUID = UUID(),
        credentialID: UUID = UUID()
    ) throws -> ModelConnection {
        try ModelConnection.make(
            id: id,
            name: "Setup test",
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: credentialID,
            selectedModel: "test-model"
        )
    }

    private func withTemporaryDatabase(_ body: (AppDatabase) throws -> Void) throws {
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
}
