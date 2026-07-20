import Foundation
@testable import CangJie

struct StubSecretRepository: SecretRepository {
    func save(_ secret: String, account: String) throws {}
    func read(account: String) throws -> String? { nil }
    func contains(account: String) throws -> Bool { false }
    func delete(account: String) throws {}
}
