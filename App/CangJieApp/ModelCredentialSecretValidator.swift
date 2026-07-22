import Foundation

enum ModelCredentialSecretValidator {
    static let maximumUTF8Bytes = 4_096

    static func validate(_ secret: String) throws {
        guard !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelCredentialRepositoryError.emptySecret
        }
        guard secret.utf8.count <= maximumUTF8Bytes else {
            throw ModelCredentialRepositoryError.secretTooLarge
        }
        guard !containsUnsafeControl(secret) else {
            throw ModelCredentialRepositoryError.invalidSecret
        }
    }

    private static func containsUnsafeControl(_ secret: String) -> Bool {
        secret.unicodeScalars.contains { scalar in
            if CharacterSet.controlCharacters.contains(scalar) {
                return true
            }
            switch scalar.value {
            case 0x061C, 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x2069:
                return true
            default:
                return false
            }
        }
    }
}
