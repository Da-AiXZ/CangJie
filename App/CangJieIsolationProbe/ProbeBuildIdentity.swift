import Foundation

struct ProbeBuildIdentityStamp: Equatable {
    let version: String
    let build: String
    let commit: String
    let fingerprint: String
    let candidateSetID: String

    init(
        version: String,
        build: String,
        commit: String,
        fingerprint: String,
        candidateSetID: String
    ) {
        self.version = Self.normalize(version)
        self.build = Self.normalize(build)
        self.commit = Self.normalize(commit).lowercased()
        self.fingerprint = Self.normalize(fingerprint).lowercased()
        self.candidateSetID = Self.normalize(candidateSetID).lowercased()
    }

    init(infoDictionary: [String: Any]?) {
        self.init(
            version: Self.value("CFBundleShortVersionString", in: infoDictionary),
            build: Self.value("CFBundleVersion", in: infoDictionary),
            commit: Self.value("CangJieGitCommit", in: infoDictionary),
            fingerprint: Self.value("CangJieExecutableFingerprint", in: infoDictionary),
            candidateSetID: Self.value("CangJieCandidateSetID", in: infoDictionary)
        )
    }

    static let generated = ProbeBuildIdentityStamp(
        version: GeneratedBuildIdentity.version,
        build: GeneratedBuildIdentity.build,
        commit: GeneratedBuildIdentity.commit,
        fingerprint: GeneratedBuildIdentity.fingerprint,
        candidateSetID: GeneratedBuildIdentity.candidateSetID
    )

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

    private static func value(_ key: String, in dictionary: [String: Any]?) -> String {
        guard let value = dictionary?[key] else { return "unavailable" }
        return normalize(String(describing: value))
    }

    private static func normalize(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unavailable" : trimmed
    }
}

struct ProbeBuildIdentity: Equatable {
    let compiled: ProbeBuildIdentityStamp
    let installed: ProbeBuildIdentityStamp

    var isActive: Bool {
        compiled.isAvailable && installed.isAvailable && compiled == installed
    }

    var executableText: String {
        "Executable Version \(compiled.version) | Build \(compiled.build) | Commit \(String(compiled.commit.prefix(12)))"
    }

    var installedText: String {
        "Installed Version \(installed.version) | Build \(installed.build) | Commit \(String(installed.commit.prefix(12)))"
    }

    var candidateSetText: String {
        compiled.candidateSetID == "local" ? "local" : String(compiled.candidateSetID.prefix(16))
    }

    static func current() -> ProbeBuildIdentity {
        ProbeBuildIdentity(
            compiled: .generated,
            installed: ProbeBuildIdentityStamp(infoDictionary: installedInfoDictionary())
        )
    }

    private static func installedInfoDictionary() -> [String: Any]? {
        let url = Bundle.main.bundleURL.appendingPathComponent("Info.plist", isDirectory: false)
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              data.count <= 1_048_576,
              let value = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = value as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}
