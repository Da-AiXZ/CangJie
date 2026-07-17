import Foundation
import Security

protocol IsolationProbeSecurityItemClient {
    func add(_ query: [String: Any]) -> OSStatus
    func copyMatching(
        _ query: [String: Any],
        result: UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

struct SystemIsolationProbeSecurityItemClient: IsolationProbeSecurityItemClient {
    func add(_ query: [String: Any]) -> OSStatus {
        SecItemAdd(query as CFDictionary, nil)
    }

    func copyMatching(
        _ query: [String: Any],
        result: UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus {
        SecItemCopyMatching(query as CFDictionary, result)
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}

protocol IsolationProbeRandomBytesGenerating {
    func randomBytes(count: Int) throws -> Data
}

enum IsolationProbeRandomError: Error {
    case generationFailed(OSStatus)
}

struct SystemIsolationProbeRandomBytesGenerator: IsolationProbeRandomBytesGenerating {
    func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw IsolationProbeRandomError.generationFailed(status)
        }
        return Data(bytes)
    }
}

struct KeychainIsolationProbe {
    private let securityClient: any IsolationProbeSecurityItemClient
    private let randomBytesGenerator: any IsolationProbeRandomBytesGenerating

    init(
        securityClient: any IsolationProbeSecurityItemClient = SystemIsolationProbeSecurityItemClient(),
        randomBytesGenerator: any IsolationProbeRandomBytesGenerating = SystemIsolationProbeRandomBytesGenerator()
    ) {
        self.securityClient = securityClient
        self.randomBytesGenerator = randomBytesGenerator
    }

    func run() -> KeychainIsolationReport {
        KeychainIsolationReport(
            ownGroupControl: runOwnGroupControl(),
            defaultGroupLookup: runDefaultGroupLookup(),
            forbiddenGroupLookup: runForbiddenGroupLookup()
        )
    }

    private func runOwnGroupControl() -> KeychainIsolationCheck {
        let baseQuery = ownGroupBaseQuery()
        let cleanupStatus = securityClient.delete(baseQuery)
        guard cleanupStatus == errSecSuccess || cleanupStatus == errSecItemNotFound else {
            return inconclusive(
                status: cleanupStatus,
                detail: "Own-group cleanup failed before the control run."
            )
        }

        let controlValue: Data
        do {
            controlValue = try randomBytesGenerator.randomBytes(count: 32)
        } catch let IsolationProbeRandomError.generationFailed(status) {
            return inconclusive(
                status: status,
                detail: "Secure random generation failed before the own-group control."
            )
        } catch {
            return inconclusive(
                status: errSecInternalError,
                detail: "Secure random generation failed before the own-group control."
            )
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = controlValue
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = securityClient.add(addQuery)
        guard addStatus == errSecSuccess else {
            return inconclusive(
                status: addStatus,
                detail: "Own-group create failed; isolation cannot be proven."
            )
        }

        var readQuery = baseQuery
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        readQuery[kSecReturnData as String] = true
        var result: CFTypeRef?
        let readStatus = securityClient.copyMatching(readQuery, result: &result)
        let storedValue = result as? Data

        let deleteStatus = securityClient.delete(baseQuery)
        guard deleteStatus == errSecSuccess else {
            return inconclusive(
                status: deleteStatus,
                detail: "Own-group delete failed after the control read."
            )
        }

        var verifyDeleteQuery = baseQuery
        verifyDeleteQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        let verifyDeleteStatus = securityClient.copyMatching(verifyDeleteQuery, result: nil)

        guard readStatus == errSecSuccess, storedValue == controlValue else {
            return inconclusive(
                status: readStatus,
                detail: "Own-group read did not return the disposable control value."
            )
        }
        guard verifyDeleteStatus == errSecItemNotFound else {
            return inconclusive(
                status: verifyDeleteStatus,
                detail: "Own-group deletion could not be verified."
            )
        }

        return KeychainIsolationCheck(
            disposition: .pass,
            status: errSecSuccess,
            detail: "Own-group create, read, and delete control passed."
        )
    }

    private func runDefaultGroupLookup() -> KeychainIsolationCheck {
        let status = securityClient.copyMatching(canaryLookupQuery(accessGroup: nil), result: nil)
        switch status {
        case errSecItemNotFound:
            return KeychainIsolationCheck(
                disposition: .pass,
                status: status,
                detail: "Default-group lookup could not see the CangJie canary."
            )
        case errSecSuccess:
            return KeychainIsolationCheck(
                disposition: .criticalFail,
                status: status,
                detail: "Critical: the Probe default group matched the CangJie canary identity."
            )
        default:
            return inconclusive(
                status: status,
                detail: "Default-group lookup returned an unexpected status."
            )
        }
    }

    private func runForbiddenGroupLookup() -> KeychainIsolationCheck {
        let query = canaryLookupQuery(accessGroup: KeychainIsolationContract.mainAccessGroup)
        let status = securityClient.copyMatching(query, result: nil)
        switch status {
        case errSecMissingEntitlement:
            return KeychainIsolationCheck(
                disposition: .pass,
                status: status,
                detail: "Explicit CangJie access-group request was denied for missing entitlement."
            )
        case errSecSuccess:
            return KeychainIsolationCheck(
                disposition: .criticalFail,
                status: status,
                detail: "Critical: the Probe was allowed to query the CangJie access group."
            )
        case errSecItemNotFound:
            return inconclusive(
                status: status,
                detail: "Item-not-found does not prove that the forbidden entitlement was denied."
            )
        default:
            return inconclusive(
                status: status,
                detail: "The forbidden-group request did not return missing-entitlement."
            )
        }
    }

    private func ownGroupBaseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainIsolationContract.probeControlService,
            kSecAttrAccount as String: KeychainIsolationContract.probeControlAccount,
            kSecAttrAccessGroup as String: KeychainIsolationContract.probeAccessGroup
        ]
    }

    private func canaryLookupQuery(accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainIsolationContract.canaryService,
            kSecAttrAccount as String: KeychainIsolationContract.canaryAccount,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        // Intentionally omit kSecReturnData and pass no result pointer. The Probe
        // classifies only OSStatus and must never retrieve the main App canary.
        return query
    }

    private func inconclusive(status: OSStatus, detail: String) -> KeychainIsolationCheck {
        KeychainIsolationCheck(
            disposition: .inconclusive,
            status: status,
            detail: detail
        )
    }
}
