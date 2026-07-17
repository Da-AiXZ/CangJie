import CryptoKit
import Foundation
import Security

protocol IsolationCanaryRepository {
    func prepare() throws -> String
    func currentDigest() throws -> String?
    func delete() throws
}

struct KeychainIsolationCanaryRepository: IsolationCanaryRepository {
    private static let maximumCanaryBytes = 64

    func prepare() throws -> String {
        if let existing = try readData() {
            return Self.digest(existing)
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(randomStatus)
        }
        let data = Data(bytes)
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        return Self.digest(data)
    }

    func currentDigest() throws -> String? {
        try readData().map(Self.digest)
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func readData() throws -> Data? {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = result as? Data, !data.isEmpty, data.count <= Self.maximumCanaryBytes else {
            throw KeychainError.invalidStoredValue
        }
        return data
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainIsolationContract.canaryService,
            kSecAttrAccount as String: KeychainIsolationContract.canaryAccount,
            kSecAttrAccessGroup as String: KeychainIsolationContract.mainAccessGroup
        ]
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).prefix(6).map { String(format: "%02x", $0) }.joined()
    }
}
