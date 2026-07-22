import CangJieCore
import Dispatch
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class ModelConnectionSetupServiceTests: XCTestCase, ModelConnectionSetupServiceTestSupport {
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

    func testVerifiedCredentialIsSavedBeforeMetadataAndCurrentSelection() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let connection = try makeConnection()
            let candidate = try makeCandidate(
                for: connection,
                secret: "fixture-key-value"
            )

            let stored = try service.persist(
                candidate,
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
                try credentials.resolve(for: connection)?
                    .setupAuthorizationHash?.utf8.count,
                64
            )
            XCTAssertEqual(
                Array(credentials.events.prefix(3)),
                ["credential.resolve", "credential.save", "credential.resolve"]
            )
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
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
                    makeCandidate(secret: "fixture-key-value"),
                    makeCurrent: true
                )
            )
            XCTAssertTrue(try database.listModelConnections().isEmpty)
            XCTAssertNil(try database.currentModelConnection())
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
        }
    }

    func testStaleCandidateVersionIsRejectedBeforeKeychainOrSQLiteMutation() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let connectionID = UUID()
            let credentialID = UUID()
            let staleCandidate = try ModelConnectionTestFixture.makeSetupCandidate(
                id: connectionID,
                credentialID: credentialID,
                credentialVersionID: UUID(),
                secret: "stale-secret"
            )
            let currentCandidate = try ModelConnectionTestFixture.makeSetupCandidate(
                id: connectionID,
                credentialID: credentialID,
                credentialVersionID: UUID(),
                secret: "current-secret"
            )

            XCTAssertThrowsError(
                try service.persist(
                    staleCandidate,
                    expectedCredentialBinding: currentCandidate.credentialBinding,
                    makeCurrent: true
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionSetupError,
                    .candidateBindingMismatch
                )
            }
            XCTAssertTrue(credentials.events.isEmpty)
            XCTAssertTrue(try database.listModelConnections().isEmpty)
            XCTAssertNil(try database.currentModelConnection())
        }
    }

    func testNonCanonicalCredentialPayloadHashCannotCommitMetadata() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            credentials.credentialPayloadHash = String(repeating: "z", count: 64)
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(secret: "fixture-key-value")

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
                    expectedCredentialBinding: candidate.credentialBinding,
                    makeCurrent: false
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionSetupError,
                    .credentialVerificationFailed
                )
            }
            XCTAssertNil(credentials.credentials[candidate.connection.credential.id])
            XCTAssertTrue(try database.listModelConnections().isEmpty)
        }
    }

    func testCredentialSaveFailureAfterMutationRestoresPreviousCredential() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let connection = try makeConnection()
            let previousProof = String(repeating: "b", count: 64)
            let previousAuthorizationHash = String(repeating: "e", count: 64)
            credentials.credentials[connection.credential.id] = KeychainBoundModelCredential(
                reference: connection.credential,
                secret: "previous-key",
                credentialVersionProof: previousProof,
                credentialPayloadHash: credentials.credentialPayloadHash,
                setupAuthorizationHash: previousAuthorizationHash
            )
            credentials.failNextSaveAfterMutation = true
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(
                for: connection,
                secret: "replacement-key"
            )

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
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
            XCTAssertEqual(
                credentials.credentials[connection.credential.id]?.credentialVersionProof,
                previousProof
            )
            XCTAssertEqual(
                credentials.credentials[connection.credential.id]?.setupAuthorizationHash,
                previousAuthorizationHash
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
            let candidate = try makeCandidate(
                for: connection,
                secret: "fixture-key-value"
            )

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
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
                secret: "previous-orphan-key",
                credentialVersionProof: String(repeating: "c", count: 64),
                credentialPayloadHash: String(repeating: "c", count: 64),
                setupAuthorizationHash: nil
            )
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(
                for: conflicting,
                secret: "replacement-key"
            )

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
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
            let candidate = try makeCandidate(
                for: conflicting,
                secret: "new-key"
            )

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
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
            try installModelConnectionCommitFailure(in: database)
            let credentials = RecordingCredentialRepository()
            let connection = try makeConnection()
            let previousProof = String(repeating: "d", count: 64)
            let previousAuthorizationHash = String(repeating: "f", count: 64)
            credentials.credentials[connection.credential.id] = KeychainBoundModelCredential(
                reference: connection.credential,
                secret: "previous-key",
                credentialVersionProof: previousProof,
                credentialPayloadHash: credentials.credentialPayloadHash,
                setupAuthorizationHash: previousAuthorizationHash
            )
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(
                for: connection,
                secret: "replacement-key"
            )

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
                    makeCurrent: false,
                    now: Date(timeIntervalSinceReferenceDate: 0.1)
                )
            ) { error in
                XCTAssertNotNil(error as? DatabaseError)
            }
            XCTAssertEqual(
                credentials.credentials[connection.credential.id]?.secret,
                "previous-key"
            )
            XCTAssertEqual(
                credentials.credentials[connection.credential.id]?.credentialVersionProof,
                previousProof
            )
            XCTAssertEqual(
                credentials.credentials[connection.credential.id]?.setupAuthorizationHash,
                previousAuthorizationHash
            )
            XCTAssertEqual(
                credentials.events,
                [
                    "credential.resolve", "credential.save", "credential.resolve",
                    "credential.save", "credential.resolve"
                ]
            )
            XCTAssertTrue(try database.listModelConnections().isEmpty)
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
        }
    }

    func testDatabaseFailureDeletesANewCredentialWithoutMetadata() throws {
        try withTemporaryDatabase { database in
            try installModelConnectionCommitFailure(in: database)
            let credentials = RecordingCredentialRepository()
            let connection = try makeConnection()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(
                for: connection,
                secret: "new-key"
            )

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
                    makeCurrent: false,
                    now: Date(timeIntervalSince1970: 3_022.125)
                )
            ) { error in
                XCTAssertNotNil(error as? DatabaseError)
            }
            XCTAssertNil(credentials.credentials[connection.credential.id])
            XCTAssertEqual(
                credentials.events,
                [
                    "credential.resolve", "credential.save", "credential.resolve",
                    "credential.delete", "credential.resolve"
                ]
            )
            XCTAssertTrue(try database.listModelConnections().isEmpty)
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
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
            let firstCandidate = try makeCandidate(
                for: first,
                secret: "first-key"
            )
            let secondCandidate = try makeCandidate(
                for: second,
                secret: "second-key"
            )
            _ = try service.persist(
                firstCandidate,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_030)
            )
            let selected = try service.persist(
                secondCandidate,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_031)
            )
            let eventsBeforeReplay = credentials.events.count

            _ = try service.persist(
                firstCandidate,
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
            let candidate = try makeCandidate(
                for: connection,
                secret: "original-key"
            )
            let stored = try service.persist(
                candidate,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_040)
            )
            try credentials.save(
                "newer-key",
                versionProof: candidate.credentialBinding.versionProof,
                for: connection
            )

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
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

    func testLateReplayRequiresTheOriginalCredentialActivationProof() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let connection = try makeConnection()
            let originalCandidate = try makeCandidate(
                for: connection,
                secret: "shared-key"
            )
            let replayFromAnotherAttempt = try makeCandidate(
                for: connection,
                secret: "shared-key"
            )
            XCTAssertNotEqual(
                originalCandidate.credentialBinding.versionProof,
                replayFromAnotherAttempt.credentialBinding.versionProof
            )
            let stored = try service.persist(
                originalCandidate,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_042)
            )

            XCTAssertThrowsError(
                try service.persist(
                    replayFromAnotherAttempt,
                    makeCurrent: true,
                    now: Date(timeIntervalSince1970: 3_043)
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionSetupError,
                    .credentialReplayConflict
                )
            }

            XCTAssertEqual(try database.currentModelConnection(), stored)
            XCTAssertEqual(
                try credentials.resolve(for: connection)?.credentialVersionProof,
                originalCandidate.credentialBinding.versionProof
            )
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
            let candidate = try makeCandidate(
                for: connection,
                secret: "fixture-key-value"
            )

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    _ = try service.persist(
                        candidate,
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
            let candidate = try makeCandidate(secret: "fixture-key-value")

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
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

}
