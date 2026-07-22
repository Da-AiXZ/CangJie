import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class ModelConnectionSetupJournalTests: XCTestCase, ModelConnectionSetupServiceTestSupport {
    func testSameCredentialVersionWithDifferentAttemptProofIsRejectedBeforeMutation() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let discoveryID = UUID()
            let connectionID = UUID()
            let credentialID = UUID()
            let versionID = UUID()
            let candidate = try ModelConnectionTestFixture.makeSetupCandidate(
                discoveryID: discoveryID,
                id: connectionID,
                credentialID: credentialID,
                credentialVersionID: versionID,
                secret: "same-key"
            )
            let otherAttempt = try ModelConnectionTestFixture.makeSetupCandidate(
                discoveryID: discoveryID,
                id: connectionID,
                credentialID: credentialID,
                credentialVersionID: versionID,
                secret: "same-key"
            )
            XCTAssertEqual(candidate.connection, otherAttempt.connection)
            XCTAssertEqual(candidate.secret, otherAttempt.secret)
            XCTAssertEqual(
                candidate.credentialBinding.credentialID,
                otherAttempt.credentialBinding.credentialID
            )
            XCTAssertEqual(
                candidate.credentialBinding.connectionID,
                otherAttempt.credentialBinding.connectionID
            )
            XCTAssertEqual(
                candidate.credentialBinding.provider,
                otherAttempt.credentialBinding.provider
            )
            XCTAssertEqual(
                candidate.credentialBinding.baseURL,
                otherAttempt.credentialBinding.baseURL
            )
            XCTAssertEqual(
                candidate.credentialBinding.versionID,
                otherAttempt.credentialBinding.versionID
            )
            XCTAssertNotEqual(
                candidate.credentialBinding.versionProof,
                otherAttempt.credentialBinding.versionProof
            )

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
                    expectedCredentialBinding: otherAttempt.credentialBinding,
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
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
        }
    }

    func testStartupReconciliationCompletesExactMetadataAfterCredentialActivationCrash() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(secret: "orphaned-key")
            let pending = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_005)
            ).pending
            try credentials.save(
                "orphaned-key",
                versionProof: candidate.credentialBinding.versionProof,
                setupAuthorizationHash: pending.setupAuthorizationHash,
                for: candidate.connection
            )

            try service.reconcilePendingSetups()

            XCTAssertEqual(
                try credentials.resolve(for: candidate.connection)?.secret,
                "orphaned-key"
            )
            XCTAssertEqual(
                try credentials.resolve(for: candidate.connection)?.credentialVersionProof,
                candidate.credentialBinding.versionProof
            )
            let recovered = try XCTUnwrap(database.listModelConnections().only)
            XCTAssertEqual(recovered.connection, candidate.connection)
            XCTAssertEqual(try database.currentModelConnection(), recovered)
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
            XCTAssertEqual(pending.connection, recovered.connection)
        }
    }

    func testStartupReconciliationRejectsRehashedModelAndBaseURLPathTamper() throws {
        for tamper in ["selectedModel", "baseURLPath"] {
            try withTemporaryDatabase { database in
                let credentials = RecordingCredentialRepository()
                let service = ModelConnectionSetupService(
                    database: database,
                    credentials: credentials
                )
                let connectionID = UUID()
                let credentialID = UUID()
                let versionID = UUID()
                let createdAt = Date(timeIntervalSince1970: 3_005.125)
                let candidate = try ModelConnectionTestFixture.makeSetupCandidate(
                    id: connectionID,
                    provider: .custom,
                    baseURL: URL(string: "https://models.example/v1")!,
                    credentialID: credentialID,
                    credentialVersionID: versionID,
                    selectedModel: "original-model",
                    secret: "tamper-key"
                )
                let pending = try database.stageModelConnectionSetup(
                    candidate.connection,
                    credentialBinding: candidate.credentialBinding,
                    makeCurrent: false,
                    now: createdAt
                ).pending
                try credentials.save(
                    candidate.secret,
                    versionProof: candidate.credentialBinding.versionProof,
                    setupAuthorizationHash: pending.setupAuthorizationHash,
                    for: candidate.connection
                )
                let tamperedConnection = try ModelConnectionTestFixture.makeConnection(
                    id: connectionID,
                    name: candidate.connection.name,
                    provider: .custom,
                    baseURL: tamper == "baseURLPath"
                        ? URL(string: "https://models.example/v2")!
                        : candidate.connection.baseURL,
                    credentialID: credentialID,
                    credentialVersionID: versionID,
                    selectedModel: tamper == "selectedModel"
                        ? "tampered-model"
                        : candidate.connection.selectedModel
                )
                let payloadJSON = try AppDatabase.encodeModelConnection(
                    tamperedConnection
                )
                let recomputedHash = setupAuthorizationHash(
                    connection: tamperedConnection,
                    credentialVersionProof: candidate.credentialBinding.versionProof,
                    makeCurrent: false,
                    payloadJSON: payloadJSON,
                    createdAt: createdAt
                )
                try database.queue.write { db in
                    try db.execute(
                        sql: """
                            UPDATE modelConnectionSetupJournal
                            SET payloadJSON = ?, payloadHash = ?
                            WHERE connectionID = ?
                            """,
                        arguments: [
                            payloadJSON,
                            recomputedHash,
                            connectionID.uuidString
                        ]
                    )
                }

                XCTAssertThrowsError(try service.reconcilePendingSetups()) { error in
                    XCTAssertEqual(
                        error as? ModelConnectionSetupError,
                        .pendingSetupReconciliationFailed
                    )
                }
                XCTAssertTrue(try database.listModelConnections().isEmpty)
                XCTAssertNil(try database.currentModelConnection())
                XCTAssertEqual(
                    try database.pendingModelConnectionSetups().only?.connection,
                    tamperedConnection
                )
                XCTAssertEqual(
                    try credentials.resolve(for: tamperedConnection)?.setupAuthorizationHash,
                    pending.setupAuthorizationHash
                )
                XCTAssertNotEqual(recomputedHash, pending.setupAuthorizationHash)
            }
        }
    }

    func testStartupReconciliationRejectsRehashedMakeCurrentAndCreatedAtTamper() throws {
        for tamper in ["makeCurrent", "createdAt"] {
            try withTemporaryDatabase { database in
                let credentials = RecordingCredentialRepository()
                let service = ModelConnectionSetupService(
                    database: database,
                    credentials: credentials
                )
                let candidate = try makeCandidate(secret: "authorization-key")
                let originalCreatedAt = Date(timeIntervalSince1970: 3_005.375)
                let pending = try database.stageModelConnectionSetup(
                    candidate.connection,
                    credentialBinding: candidate.credentialBinding,
                    makeCurrent: false,
                    now: originalCreatedAt
                ).pending
                try credentials.save(
                    candidate.secret,
                    versionProof: candidate.credentialBinding.versionProof,
                    setupAuthorizationHash: pending.setupAuthorizationHash,
                    for: candidate.connection
                )
                let tamperedMakeCurrent = tamper == "makeCurrent"
                let tamperedCreatedAt = tamper == "createdAt"
                    ? Date(timeIntervalSince1970: 3_006.375)
                    : originalCreatedAt
                let payloadJSON = try AppDatabase.encodeModelConnection(
                    candidate.connection
                )
                let recomputedHash = setupAuthorizationHash(
                    connection: candidate.connection,
                    credentialVersionProof: candidate.credentialBinding.versionProof,
                    makeCurrent: tamperedMakeCurrent,
                    payloadJSON: payloadJSON,
                    createdAt: tamperedCreatedAt
                )
                try database.queue.write { db in
                    try db.execute(
                        sql: """
                            UPDATE modelConnectionSetupJournal
                            SET makeCurrent = ?, createdAt = ?, payloadHash = ?
                            WHERE connectionID = ?
                            """,
                        arguments: [
                            tamperedMakeCurrent,
                            tamperedCreatedAt.timeIntervalSince1970,
                            recomputedHash,
                            candidate.connection.id.uuidString
                        ]
                    )
                }

                XCTAssertThrowsError(try service.reconcilePendingSetups()) { error in
                    XCTAssertEqual(
                        error as? ModelConnectionSetupError,
                        .pendingSetupReconciliationFailed
                    )
                }
                XCTAssertTrue(try database.listModelConnections().isEmpty)
                XCTAssertNil(try database.currentModelConnection())
                XCTAssertEqual(try database.pendingModelConnectionSetups().count, 1)
                XCTAssertNotEqual(recomputedHash, pending.setupAuthorizationHash)
            }
        }
    }

    func testStartupReconciliationOfActivatedCredentialIsReplaySafe() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let previouslySelected = try database.storeModelConnection(
                makeConnection(),
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_005.25)
            )
            let candidate = try makeCandidate(secret: "replay-safe-key")
            let pending = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: false,
                now: Date(timeIntervalSince1970: 3_005.5)
            ).pending
            try credentials.save(
                "replay-safe-key",
                versionProof: candidate.credentialBinding.versionProof,
                setupAuthorizationHash: pending.setupAuthorizationHash,
                for: candidate.connection
            )

            try service.reconcilePendingSetups()
            let recovered = try XCTUnwrap(
                database.listModelConnections().first(where: {
                    $0.connection.id == candidate.connection.id
                })
            )
            let eventsAfterRecovery = credentials.events

            try service.reconcilePendingSetups()

            XCTAssertEqual(
                try database.listModelConnections(),
                [recovered, previouslySelected]
            )
            XCTAssertEqual(try database.currentModelConnection(), previouslySelected)
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
            XCTAssertEqual(credentials.events, eventsAfterRecovery)
        }
    }

    func testStartupReconciliationPreservesAmbiguousActiveCredentialAndJournal() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(secret: "shared-key")
            let pending = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_005.75)
            ).pending
            let restoredBaselineProof = String(repeating: "b", count: 64)
            XCTAssertNotEqual(
                restoredBaselineProof,
                candidate.credentialBinding.versionProof
            )
            try credentials.save(
                "shared-key",
                versionProof: restoredBaselineProof,
                for: candidate.connection
            )

            XCTAssertThrowsError(try service.reconcilePendingSetups()) { error in
                XCTAssertEqual(
                    error as? ModelConnectionSetupError,
                    .pendingSetupReconciliationFailed
                )
            }

            XCTAssertEqual(
                try credentials.resolve(for: candidate.connection)?.secret,
                "shared-key"
            )
            XCTAssertEqual(
                try credentials.resolve(for: candidate.connection)?.credentialVersionProof,
                restoredBaselineProof
            )
            XCTAssertEqual(try database.pendingModelConnectionSetups(), [pending])
            XCTAssertTrue(try database.listModelConnections().isEmpty)
            XCTAssertNil(try database.currentModelConnection())
            XCTAssertFalse(credentials.events.contains("credential.delete"))
        }
    }

    func testStartupReconciliationClearsAJournalCreatedBeforeKeychainMutation() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(secret: "never-written-key")
            _ = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: false,
                now: Date(timeIntervalSince1970: 3_006)
            )

            try service.reconcilePendingSetups()

            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
            XCTAssertTrue(try database.listModelConnections().isEmpty)
            XCTAssertEqual(
                credentials.events,
                ["credential.resolve", "credential.delete", "credential.resolve"]
            )
        }
    }

    func testStartupReconciliationPreservesCommittedMetadataAndCredential() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(secret: "committed-key")
            let pending = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_007)
            ).pending
            try credentials.save(
                "committed-key",
                versionProof: candidate.credentialBinding.versionProof,
                setupAuthorizationHash: pending.setupAuthorizationHash,
                for: candidate.connection
            )
            let stored = try database.storeModelConnection(
                candidate.connection,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_008)
            )
            XCTAssertEqual(try database.pendingModelConnectionSetups(), [pending])

            try service.reconcilePendingSetups()

            XCTAssertEqual(try database.currentModelConnection(), stored)
            XCTAssertEqual(
                try credentials.resolve(for: candidate.connection)?.secret,
                "committed-key"
            )
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
        }
    }

    func testFailedOrphanCleanupLeavesTheJournalForRetry() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            credentials.failDelete = true
            credentials.suppressResolve = true
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(secret: "retry-key")
            let pending = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: false,
                now: Date(timeIntervalSince1970: 3_009)
            ).pending

            XCTAssertThrowsError(try service.reconcilePendingSetups()) { error in
                XCTAssertEqual(
                    error as? RecordingCredentialRepository.Failure,
                    .delete
                )
            }
            XCTAssertEqual(try database.pendingModelConnectionSetups(), [pending])
            XCTAssertNil(try credentials.resolve(for: candidate.connection))
            XCTAssertTrue(try database.listModelConnections().isEmpty)
        }
    }

    func testStagingDistinguishesInsertedFromReplayedPendingSetup() throws {
        try withTemporaryDatabase { database in
            let candidate = try makeCandidate(secret: "staged-key")

            let inserted = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: true,
                now: Date(timeIntervalSinceReferenceDate: 0.1)
            )
            guard case let .inserted(pending) = inserted else {
                return XCTFail("The first stage must report an inserted journal")
            }

            let replayed = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 3_010)
            )
            guard case let .replayed(replayedPending) = replayed else {
                return XCTFail("An exact durable retry must report a replayed journal")
            }
            XCTAssertEqual(replayedPending, pending)
        }
    }

    func testJournalRejectsDifferentAttemptProofForTheSameCredentialVersion() throws {
        try withTemporaryDatabase { database in
            let connectionID = UUID()
            let credentialID = UUID()
            let versionID = UUID()
            let staged = try ModelConnectionTestFixture.makeSetupCandidate(
                id: connectionID,
                credentialID: credentialID,
                credentialVersionID: versionID,
                secret: "same-key"
            )
            let otherAttempt = try ModelConnectionTestFixture.makeSetupCandidate(
                id: connectionID,
                credentialID: credentialID,
                credentialVersionID: versionID,
                secret: "same-key"
            )
            XCTAssertNotEqual(
                staged.credentialBinding.versionProof,
                otherAttempt.credentialBinding.versionProof
            )
            _ = try database.stageModelConnectionSetup(
                staged.connection,
                credentialBinding: staged.credentialBinding,
                makeCurrent: false,
                now: Date(timeIntervalSince1970: 3_011)
            )

            XCTAssertThrowsError(
                try database.stageModelConnectionSetup(
                    otherAttempt.connection,
                    credentialBinding: otherAttempt.credentialBinding,
                    makeCurrent: false,
                    now: Date(timeIntervalSince1970: 3_012)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
            XCTAssertEqual(try database.pendingModelConnectionSetups().count, 1)
        }
    }

    func testJournalRejectsBindingVersionThatDiffersFromConnectionPayload() throws {
        try withTemporaryDatabase { database in
            let connectionID = UUID()
            let credentialID = UUID()
            let connectionCandidate = try ModelConnectionTestFixture.makeSetupCandidate(
                id: connectionID,
                credentialID: credentialID,
                credentialVersionID: UUID(),
                secret: "same-key"
            )
            let mismatchedBindingCandidate = try ModelConnectionTestFixture.makeSetupCandidate(
                id: connectionID,
                credentialID: credentialID,
                credentialVersionID: UUID(),
                secret: "same-key"
            )

            XCTAssertThrowsError(
                try database.stageModelConnectionSetup(
                    connectionCandidate.connection,
                    credentialBinding: mismatchedBindingCandidate.credentialBinding,
                    makeCurrent: false,
                    now: Date(timeIntervalSince1970: 3_012.5)
                )
            ) { error in
                XCTAssertEqual(
                    error as? AppDatabaseError,
                    .invalidModelConnectionSetupJournal
                )
            }
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
        }
    }

    func testFractionalTimestampDiscardUsesStableJournalIdentity() throws {
        try withTemporaryDatabase { database in
            let candidate = try makeCandidate(secret: "fractional-key")
            let stage = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: false,
                now: Date(timeIntervalSinceReferenceDate: 0.1)
            )

            try database.discardModelConnectionSetup(stage.pending)
            XCTAssertTrue(try database.pendingModelConnectionSetups().isEmpty)
        }
    }

    func testConsecutiveCommitFailuresKeepReplayedJournalAndRemoveActiveOrphan() throws {
        try withTemporaryDatabase { database in
            try installModelConnectionCommitFailure(in: database)
            let credentials = RecordingCredentialRepository()
            credentials.failDelete = true
            let service = ModelConnectionSetupService(
                database: database,
                credentials: credentials
            )
            let candidate = try makeCandidate(secret: "retry-key")

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
                    makeCurrent: false,
                    now: Date(timeIntervalSinceReferenceDate: 0.1)
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionSetupError,
                    .credentialCompensationFailed
                )
            }
            let pendingAfterFirstFailure = try XCTUnwrap(
                database.pendingModelConnectionSetups().only
            )
            XCTAssertEqual(
                try credentials.resolve(for: candidate.connection)?.secret,
                "retry-key"
            )

            credentials.failDelete = false
            XCTAssertThrowsError(
                try service.persist(
                    candidate,
                    makeCurrent: false,
                    now: Date(timeIntervalSince1970: 3_013)
                )
            ) { error in
                XCTAssertNotNil(error as? DatabaseError)
            }

            XCTAssertNil(try credentials.resolve(for: candidate.connection))
            XCTAssertEqual(
                try database.pendingModelConnectionSetups(),
                [pendingAfterFirstFailure]
            )
            XCTAssertTrue(try database.listModelConnections().isEmpty)
        }
    }

    func testReplayPreservesBaselineRestoredBeforeJournalDeleteFailure() throws {
        try withTemporaryDatabase { database in
            try installModelConnectionJournalDeleteFailure(in: database)
            let credentials = RecordingCredentialRepository()
            let connection = try makeConnection()
            let previousProof = String(repeating: "c", count: 64)
            let previousAuthorizationHash = String(repeating: "d", count: 64)
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
                    now: Date(timeIntervalSince1970: 3_014)
                )
            ) { error in
                XCTAssertEqual(
                    error as? ModelConnectionSetupError,
                    .credentialCompensationFailed
                )
            }
            let pendingAfterFirstFailure = try XCTUnwrap(
                database.pendingModelConnectionSetups().only
            )
            XCTAssertEqual(
                try credentials.resolve(for: connection)?.secret,
                "previous-key"
            )
            XCTAssertEqual(
                try credentials.resolve(for: connection)?.credentialVersionProof,
                previousProof
            )
            XCTAssertEqual(
                try credentials.resolve(for: connection)?.setupAuthorizationHash,
                previousAuthorizationHash
            )

            XCTAssertThrowsError(
                try service.persist(
                    candidate,
                    makeCurrent: false,
                    now: Date(timeIntervalSince1970: 3_015)
                )
            ) { error in
                XCTAssertNotNil(error as? DatabaseError)
            }

            XCTAssertEqual(
                try credentials.resolve(for: connection)?.secret,
                "previous-key"
            )
            XCTAssertEqual(
                try credentials.resolve(for: connection)?.credentialVersionProof,
                previousProof
            )
            XCTAssertEqual(
                try credentials.resolve(for: connection)?.setupAuthorizationHash,
                previousAuthorizationHash
            )
            XCTAssertEqual(
                try database.pendingModelConnectionSetups(),
                [pendingAfterFirstFailure]
            )
            XCTAssertTrue(try database.listModelConnections().isEmpty)
        }
    }

    private func setupAuthorizationHash(
        connection: ModelConnection,
        credentialVersionProof: String,
        makeCurrent: Bool,
        payloadJSON: String,
        createdAt: Date
    ) -> String {
        AppDatabase.payloadHash(
            [
                "cangjie-model-connection-setup-journal-v1",
                connection.id.uuidString,
                connection.credential.id.uuidString,
                connection.credential.versionID.uuidString,
                credentialVersionProof,
                makeCurrent ? "1" : "0",
                "1",
                String(createdAt.timeIntervalSince1970.bitPattern, radix: 16),
                payloadJSON
            ].joined(separator: "\u{0}")
        )
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
