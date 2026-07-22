import CangJieCore
import Foundation

struct ProviderRequestReconciler {
    private let database: AppDatabase
    private let now: () -> Date

    init(
        database: AppDatabase,
        now: @escaping () -> Date = Date.init
    ) {
        self.database = database
        self.now = now
    }

    func reconcile(
        _ request: ProviderRequestSnapshot
    ) throws -> ProviderRequestSnapshot {
        guard let current = try database.providerRequest(
            id: request.identity.requestID
        ), current == request else {
            throw AppDatabaseError.invalidProviderRequest
        }
        try validateDurableResponse(for: current)
        switch current.phase {
        case .sending, .streaming:
            let unknown = try ProviderRequestLifecycle.markOutcomeUnknown(
                current,
                reason: .lifecycleInterruption,
                now: now()
            )
            try database.updateProviderRequest(unknown)
            return unknown
        case .outcomeUnknown:
            return current
        case .prepared, .responseComplete, .continuationCommitted,
             .cancelled, .failed:
            throw AppDatabaseError.invalidProviderRequest
        }
    }

    private func validateDurableResponse(
        for request: ProviderRequestSnapshot
    ) throws {
        guard let json = try database.providerResponsePayload(
            assetID: request.responseAssetID
        ), let data = json.data(using: .utf8) else {
            throw AppDatabaseError.invalidProviderResponseAsset
        }
        let payload = try JSONDecoder().decode(
            ProviderResponsePayload.self,
            from: data
        )
        try payload.validate()
        if request.streamCursor == 0 {
            guard request.receivedUTF8Bytes == 0,
                  request.responseHash == nil,
                  json == ProviderResponsePayload.emptyJSON else {
                throw AppDatabaseError.invalidProviderResponseAsset
            }
            return
        }
        guard request.receivedUTF8Bytes == json.utf8.count,
              request.responseHash == AppDatabase.payloadHash(json) else {
            throw AppDatabaseError.invalidProviderResponseAsset
        }
    }
}
