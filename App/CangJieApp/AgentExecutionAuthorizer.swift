import Foundation

enum GovernedAgentOperation: String, Sendable {
    case agentTurn
    case runtimeReconciliation
    case openingPlanApproval
    case chapterParagraphLock
    case chapterReject
    case chapterDiagnosis
    case chapterRewrite
    case chapterAccept
}

enum AgentExecutionAuthorizationError: LocalizedError, Equatable {
    case buildNotActive

    var errorDescription: String? {
        "The running executable is not the verified installed build (BUILD-ACTIVATION)."
    }
}

protocol AgentExecutionAuthorizing: AnyObject {
    func authorize(_ operation: GovernedAgentOperation) throws
}

final class BuildActivationAgentAuthorizer: AgentExecutionAuthorizing {
    private let lock = NSLock()
    private var allowed: Bool

    init(allowed: Bool) {
        self.allowed = allowed
    }

    func update(allowed: Bool) {
        lock.lock()
        self.allowed = allowed
        lock.unlock()
    }

    func authorize(_ operation: GovernedAgentOperation) throws {
        lock.lock()
        let isAllowed = allowed
        lock.unlock()
        guard isAllowed else { throw AgentExecutionAuthorizationError.buildNotActive }
    }
}

final class AllowingAgentExecutionAuthorizer: AgentExecutionAuthorizing {
    func authorize(_ operation: GovernedAgentOperation) throws {}
}
