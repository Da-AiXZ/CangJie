import CangJieCore
import Foundation

enum ModelConnectionSetupError: Error, Equatable {
    case candidateBindingMismatch
    case credentialVerificationFailed
    case credentialCompensationFailed
    case credentialReplayConflict
    case pendingSetupReconciliationFailed
}

/// Persists a fully user-selected connection. Provider testing and model
/// discovery happen before this boundary; Provider request creation happens
/// later and still requires a fresh credential resolution.
struct ModelConnectionSetupService {
    private let database: AppDatabase
    private let credentials: any ModelCredentialRepository

    init(
        database: AppDatabase,
        credentials: any ModelCredentialRepository = KeychainModelCredentialRepository()
    ) {
        self.database = database
        self.credentials = credentials
    }

    func persist(
        _ candidate: ModelConnectionSetupCandidate,
        expectedCredentialBinding: ModelDiscoveryCredentialBinding,
        makeCurrent: Bool,
        now: Date = Date()
    ) throws -> StoredModelConnection {
        let connection = candidate.connection
        let secret = candidate.secret
        guard candidate.credentialBinding == expectedCredentialBinding,
              candidate.credentialBinding.connectionID == connection.id,
              candidate.credentialBinding.provider == connection.provider,
              candidate.credentialBinding.baseURL == connection.baseURL,
              candidate.credentialBinding.credentialID == connection.credential.id,
              candidate.credentialBinding.versionID == connection.credential.versionID else {
            throw ModelConnectionSetupError.candidateBindingMismatch
        }
        return try ModelCredentialOperationCoordinator.withExclusiveAccess {
            let storedConnections = try database.listModelConnections()
            if let existing = storedConnections.first(where: {
                $0.connection.id == connection.id
            }) {
                guard existing.connection == connection else {
                    throw AppDatabaseError.idempotencyConflict
                }
                guard try resolvedCredentialMatches(
                    connection: connection,
                    secret: secret,
                    credentialVersionProof: candidate.credentialBinding.versionProof,
                    expectedSetupAuthorizationHash: nil
                ) else {
                    throw ModelConnectionSetupError.credentialReplayConflict
                }
                // Immutable save replay is historical reconciliation. It must
                // neither rewrite the credential nor reapply makeCurrent.
                return existing
            }
            guard !storedConnections.contains(where: {
                $0.connection.credential.id == connection.credential.id
            }) else {
                throw AppDatabaseError.idempotencyConflict
            }

            let previousCredential = try credentials.resolve(for: connection)
            let stage = try database.stageModelConnectionSetup(
                connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: makeCurrent,
                now: now
            )
            do {
                try credentials.save(
                    secret,
                    versionProof: candidate.credentialBinding.versionProof,
                    setupAuthorizationHash: stage.pending.setupAuthorizationHash,
                    for: connection
                )
                guard try resolvedCredentialMatches(
                    connection: connection,
                    secret: secret,
                    credentialVersionProof: candidate.credentialBinding.versionProof,
                    expectedSetupAuthorizationHash: stage.pending.setupAuthorizationHash
                ) else {
                    throw ModelConnectionSetupError.credentialVerificationFailed
                }
                return try database.commitModelConnectionSetup(
                    connection,
                    credentialBinding: candidate.credentialBinding,
                    expectedMakeCurrent: makeCurrent,
                    now: now
                )
            } catch let operationError {
                do {
                    switch stage {
                    case let .inserted(pending):
                        try restoreCredential(
                            previousCredential,
                            for: connection
                        )
                        try database.discardModelConnectionSetup(pending)
                    case .replayed:
                        // A credential covered by a pre-existing journal is an
                        // orphan only when it is the candidate credential from
                        // that unfinished attempt. A different active secret or
                        // activation proof can be the baseline restored before
                        // an earlier journal cleanup failure, so preserve it
                        // while keeping the journal for another retry.
                        let previousCredentialIsCandidate = previousCredential?.secret == secret
                            && previousCredential?.credentialVersionProof
                                == candidate.credentialBinding.versionProof
                            && previousCredential?.setupAuthorizationHash
                                == stage.pending.setupAuthorizationHash
                        let rollbackCredential = previousCredentialIsCandidate
                            ? nil
                            : previousCredential
                        try restoreCredential(
                            rollbackCredential,
                            for: connection
                        )
                    }
                } catch {
                    throw ModelConnectionSetupError.credentialCompensationFailed
                }
                throw operationError
            }
        }
    }

    func reconcilePendingSetups() throws {
        try ModelCredentialOperationCoordinator.withExclusiveAccess {
            let storedConnections = try database.listModelConnections()
            for pending in try database.pendingModelConnectionSetups() {
                let verifiedConnection = try credentials.verifiedConnection(
                    for: pending.connection
                )
                if let stored = storedConnections.first(where: {
                    $0.connection.id == pending.connection.id
                }) {
                    guard stored.connection == pending.connection,
                          let verifiedConnection,
                          pending.matches(verifiedConnection) else {
                        throw ModelConnectionSetupError.pendingSetupReconciliationFailed
                    }
                    try database.discardModelConnectionSetup(pending)
                    continue
                }

                if let verifiedConnection {
                    guard pending.matches(verifiedConnection) else {
                        // A different activation proof can be a baseline restored
                        // before journal cleanup failed. Preserve both stores and
                        // require explicit recovery instead of deleting or
                        // authorizing the ambiguous credential.
                        throw ModelConnectionSetupError.pendingSetupReconciliationFailed
                    }
                    _ = try database.commitModelConnectionSetup(
                        pending,
                        now: pending.createdAt
                    )
                    continue
                }

                // The journal remains the durable retry point until inactive
                // orphan cleanup can be proven.
                try credentials.delete(for: pending.connection)
                guard try credentials.resolve(for: pending.connection) == nil else {
                    throw ModelConnectionSetupError.pendingSetupReconciliationFailed
                }
                try database.discardModelConnectionSetup(pending)
            }
        }
    }

    private func resolvedCredentialMatches(
        connection: ModelConnection,
        secret: String,
        credentialVersionProof: String,
        expectedSetupAuthorizationHash: String?
    ) throws -> Bool {
        do {
            guard let verifiedConnection = try credentials.verifiedConnection(
                for: connection,
                matchingSecret: secret
            ) else {
                return false
            }
            let verification = verifiedConnection.credentialVerification
            return verification.credentialVersionProof == credentialVersionProof
                && (expectedSetupAuthorizationHash.map {
                    verification.setupAuthorizationHash == $0
                } ?? true)
        } catch ModelConnectionError.credentialBindingMismatch {
            return false
        }
    }

    private func restoreCredential(
        _ previousCredential: KeychainBoundModelCredential?,
        for connection: ModelConnection
    ) throws {
        if let previousCredential {
            try credentials.save(
                previousCredential.secret,
                versionProof: previousCredential.credentialVersionProof,
                setupAuthorizationHash: previousCredential.setupAuthorizationHash,
                for: connection
            )
            guard try credentials.resolve(for: connection) == previousCredential else {
                throw ModelConnectionSetupError.credentialCompensationFailed
            }
        } else {
            try credentials.delete(for: connection)
            guard try credentials.resolve(for: connection) == nil else {
                throw ModelConnectionSetupError.credentialCompensationFailed
            }
        }
    }
}
