import CangJieCore
import Foundation

enum ModelConnectionSetupError: Error, Equatable {
    case credentialVerificationFailed
    case credentialCompensationFailed
    case credentialReplayConflict
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
        connection: ModelConnection,
        secret: String,
        makeCurrent: Bool,
        now: Date = Date()
    ) throws -> StoredModelConnection {
        try ModelCredentialOperationCoordinator.withExclusiveAccess {
            let storedConnections = try database.listModelConnections()
            if let existing = storedConnections.first(where: {
                $0.connection.id == connection.id
            }) {
                guard existing.connection == connection else {
                    throw AppDatabaseError.idempotencyConflict
                }
                let expected = KeychainBoundModelCredential(
                    reference: connection.credential,
                    secret: secret
                )
                guard try credentials.resolve(for: connection) == expected else {
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
            do {
                try credentials.save(secret, for: connection)
                let expected = KeychainBoundModelCredential(
                    reference: connection.credential,
                    secret: secret
                )
                guard try credentials.resolve(for: connection) == expected else {
                    throw ModelConnectionSetupError.credentialVerificationFailed
                }
                return try database.storeModelConnection(
                    connection,
                    makeCurrent: makeCurrent,
                    now: now
                )
            } catch let operationError {
                do {
                    try restoreCredential(
                        previousCredential,
                        for: connection
                    )
                } catch {
                    throw ModelConnectionSetupError.credentialCompensationFailed
                }
                throw operationError
            }
        }
    }

    private func restoreCredential(
        _ previousCredential: KeychainBoundModelCredential?,
        for connection: ModelConnection
    ) throws {
        if let previousCredential {
            try credentials.save(previousCredential.secret, for: connection)
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
