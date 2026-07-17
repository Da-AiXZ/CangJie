import Foundation

enum GovernedAgentOperation: String, Hashable, Sendable {
    case runtimeInitialization
    case runtimeReconciliation
    case agentTurn
    case openingPlanApproval
    case chapterGenerate
    case chapterParagraphLock
    case chapterReject
    case chapterDiagnosis
    case chapterRewrite
    case chapterAccept
    case durableMutation
    case diagnosticsCanaryPrepare
    case diagnosticsCanaryVerify
    case diagnosticsCanaryDelete
    case diagnosticsKeychainMutation
}

enum AgentExecutionAuthorizationError: LocalizedError, Equatable {
    case buildNotActive

    var errorDescription: String? {
        "The running executable is not the verified installed build (BUILD-ACTIVATION)."
    }
}

protocol AgentExecutionAuthorizing: AnyObject {
    func authorize(_ operation: GovernedAgentOperation) throws
    func performAuthorized<T>(
        _ operation: GovernedAgentOperation,
        _ body: () throws -> T
    ) throws -> T
}

extension AgentExecutionAuthorizing {
    func performAuthorized<T>(
        _ operation: GovernedAgentOperation,
        _ body: () throws -> T
    ) throws -> T {
        try authorize(operation)
        return try body()
    }
}

final class BuildActivationAgentAuthorizer: AgentExecutionAuthorizing {
    private let lock = NSRecursiveLock()
    private let compiledBuildStamp: BuildIdentityStamp
    private let bundleIdentityLoader: any BundleBuildIdentityLoading
    private var lifecycleAllowed: Bool
    private var authorizationEpoch: UInt64 = 0

    init(
        compiledBuildStamp: BuildIdentityStamp,
        bundleIdentityLoader: any BundleBuildIdentityLoading,
        allowed: Bool
    ) {
        self.compiledBuildStamp = compiledBuildStamp
        self.bundleIdentityLoader = bundleIdentityLoader
        lifecycleAllowed = allowed
    }

    func update(allowed: Bool) {
        lock.lock()
        lifecycleAllowed = allowed
        authorizationEpoch &+= 1
        lock.unlock()
    }

    func authorize(_ operation: GovernedAgentOperation) throws {
        try performAuthorized(operation) {}
    }

    func performAuthorized<T>(
        _ operation: GovernedAgentOperation,
        _ body: () throws -> T
    ) throws -> T {
        lock.lock()
        let observedEpoch = authorizationEpoch
        let wasLifecycleAllowed = lifecycleAllowed
        lock.unlock()
        guard wasLifecycleAllowed else {
            throw AgentExecutionAuthorizationError.buildNotActive
        }

        let currentIdentity = BuildIdentity(
            infoDictionary: bundleIdentityLoader.loadInfoDictionary(),
            compiled: compiledBuildStamp
        )

        lock.lock()
        defer { lock.unlock() }
        guard lifecycleAllowed, authorizationEpoch == observedEpoch else {
            throw AgentExecutionAuthorizationError.buildNotActive
        }
        guard currentIdentity.isAgentExecutionAllowed else {
            lifecycleAllowed = false
            authorizationEpoch &+= 1
            throw AgentExecutionAuthorizationError.buildNotActive
        }
        return try body()
    }
}

final class AllowingAgentExecutionAuthorizer: AgentExecutionAuthorizing {
    func authorize(_ operation: GovernedAgentOperation) throws {}
}
