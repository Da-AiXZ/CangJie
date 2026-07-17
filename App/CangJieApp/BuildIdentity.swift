import Foundation

struct BuildIdentityStamp: Equatable, Sendable {
    let version: String
    let build: String
    let commit: String
    let fingerprint: String
    let candidateSetID: String

    var activationToken: String {
        [version, build, commit, fingerprint, candidateSetID].joined(separator: "|")
    }

    var isAvailable: Bool {
        let values = [version, build, commit, fingerprint, candidateSetID]
        guard values.allSatisfy({ !$0.isEmpty && $0 != "unavailable" && !$0.contains("$(") }) else {
            return false
        }
#if DEBUG || targetEnvironment(simulator)
        return true
#else
        return values.allSatisfy { $0 != "local" }
#endif
    }

    var infoDictionary: [String: Any] {
        [
            "CFBundleShortVersionString": version,
            "CFBundleVersion": build,
            "CangJieGitCommit": commit,
            "CangJieExecutableFingerprint": fingerprint,
            "CangJieCandidateSetID": candidateSetID
        ]
    }

    init(
        version: String,
        build: String,
        commit: String,
        fingerprint: String,
        candidateSetID: String = "local"
    ) {
        self.version = Self.normalized(version)
        self.build = Self.normalized(build)
        self.commit = Self.normalizedCommit(commit)
        self.fingerprint = Self.normalized(fingerprint).lowercased()
        self.candidateSetID = Self.normalized(candidateSetID).lowercased()
    }

    init(infoDictionary: [String: Any]?) {
        self.init(
            version: Self.value(for: "CFBundleShortVersionString", in: infoDictionary),
            build: Self.value(for: "CFBundleVersion", in: infoDictionary),
            commit: Self.value(for: "CangJieGitCommit", in: infoDictionary),
            fingerprint: Self.value(for: "CangJieExecutableFingerprint", in: infoDictionary),
            candidateSetID: Self.value(for: "CangJieCandidateSetID", in: infoDictionary)
        )
    }

    static let generated = BuildIdentityStamp(
        version: GeneratedBuildIdentity.version,
        build: GeneratedBuildIdentity.build,
        commit: GeneratedBuildIdentity.commit,
        fingerprint: GeneratedBuildIdentity.fingerprint,
        candidateSetID: GeneratedBuildIdentity.candidateSetID
    )

    private static func value(for key: String, in dictionary: [String: Any]?) -> String {
        guard let raw = dictionary?[key] else { return "unavailable" }
        return normalized(String(describing: raw))
    }

    private static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unavailable" : trimmed
    }

    private static func normalizedCommit(_ value: String) -> String {
        let normalized = normalized(value).lowercased()
        guard normalized != "unavailable", normalized != "local" else { return normalized }
        return String(normalized.prefix(12))
    }
}

enum BuildActivationStatus: String, Equatable, Sendable {
    case active
    case mismatch
    case unavailable
}

struct BuildIdentity: Equatable, Sendable {
    let compiled: BuildIdentityStamp
    let bundle: BuildIdentityStamp
    let activationStatus: BuildActivationStatus

    var version: String { compiled.version }
    var build: String { compiled.build }
    var commit: String { compiled.commit }
    var isAgentExecutionAllowed: Bool { activationStatus == .active }
    var candidateSetID: String { compiled.candidateSetID }
    var candidateSetDisplayText: String {
        candidateSetID == "local" ? "local" : String(candidateSetID.prefix(16))
    }

    var displayText: String {
        "Executable Version \(version) | Build \(build) | Commit \(commit) | \(statusLabel)"
    }

    var bundleDisplayText: String {
        "Installed Version \(bundle.version) | Build \(bundle.build) | Commit \(bundle.commit)"
    }

    var diagnosticText: String {
        switch activationStatus {
        case .active:
            return "The running executable and installed bundle match. This build is active."
        case .mismatch:
            return "The running executable does not match the installed bundle. Force-quit CangJie and reopen it. If the mismatch remains, respring userspace before doing Agent work."
        case .unavailable:
            return "Executable identity is unavailable. Agent mutations are blocked until a verifiable build is active."
        }
    }

    init(infoDictionary: [String: Any]?, compiled: BuildIdentityStamp = .generated) {
        self.init(bundle: BuildIdentityStamp(infoDictionary: infoDictionary), compiled: compiled)
    }

    init(bundle: BuildIdentityStamp, compiled: BuildIdentityStamp = .generated) {
        self.compiled = compiled
        self.bundle = bundle
        if !compiled.isAvailable || !bundle.isAvailable {
            activationStatus = .unavailable
        } else if compiled == bundle {
            activationStatus = .active
        } else {
            activationStatus = .mismatch
        }
    }

    private var statusLabel: String {
        switch activationStatus {
        case .active: return "Active"
        case .mismatch: return "Restart required"
        case .unavailable: return "Unverified"
        }
    }
}

protocol BundleBuildIdentityLoading {
    func loadInfoDictionary() -> [String: Any]?
}

struct MainBundleBuildIdentityLoader: BundleBuildIdentityLoading {
    func loadInfoDictionary() -> [String: Any]? {
        let plistURL = Bundle.main.bundleURL.appendingPathComponent("Info.plist", isDirectory: false)
        guard let data = try? Data(contentsOf: plistURL, options: [.mappedIfSafe]),
              data.count <= 1_048_576,
              let value = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = value as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}

struct StaticBundleBuildIdentityLoader: BundleBuildIdentityLoading {
    let infoDictionary: [String: Any]?
    func loadInfoDictionary() -> [String: Any]? { infoDictionary }
}

protocol BuildActivationStore: AnyObject {
    func loadActivatedToken() -> String?
    func saveActivatedToken(_ token: String)
}

final class UserDefaultsBuildActivationStore: BuildActivationStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "cangjie.activatedExecutableIdentity.v1") {
        self.defaults = defaults
        self.key = key
    }

    func loadActivatedToken() -> String? {
        defaults.string(forKey: key)
    }

    func saveActivatedToken(_ token: String) {
        defaults.set(token, forKey: key)
    }
}
