public enum AgentTaskStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case pauseRequested
    case reconciling
    case paused
    case stopRequested
    case waitingUser
    case completed
    case failed
    case discarded
}

public enum AgentTaskOutcome: String, Codable, CaseIterable, Sendable {
    case natural
    case kept
    case discarded
}

public enum AgentTaskWaitingReason: String, Codable, CaseIterable, Sendable {
    case networkConfirmation
    case connectionInvalid
}

public enum AgentTaskRecoveryState: String, Codable, CaseIterable, Sendable {
    case completed
    case paused
    case failed
    case outcomeUnknown
    case connectionInvalid
}

public enum AgentTaskControlError: Error, Equatable, Sendable {
    case invalidTransition(from: AgentTaskStatus, to: AgentTaskStatus)
    case invalidOutcome(status: AgentTaskStatus, outcome: AgentTaskOutcome?)
    case invalidWaitingReason(
        status: AgentTaskStatus,
        reason: AgentTaskWaitingReason?
    )
    case adoptedOutputCannotBeDiscarded
}

public struct AgentTaskControlState: Codable, Equatable, Sendable {
    public let status: AgentTaskStatus
    public let outcome: AgentTaskOutcome?
    public let waitingReason: AgentTaskWaitingReason?

    public init(
        status: AgentTaskStatus,
        outcome: AgentTaskOutcome? = nil,
        waitingReason: AgentTaskWaitingReason? = nil
    ) throws {
        switch status {
        case .completed:
            guard outcome == .natural || outcome == .kept else {
                throw AgentTaskControlError.invalidOutcome(
                    status: status,
                    outcome: outcome
                )
            }
        case .discarded:
            guard outcome == .discarded else {
                throw AgentTaskControlError.invalidOutcome(
                    status: status,
                    outcome: outcome
                )
            }
        case .queued, .running, .pauseRequested, .reconciling, .paused,
             .stopRequested, .waitingUser, .failed:
            guard outcome == nil else {
                throw AgentTaskControlError.invalidOutcome(
                    status: status,
                    outcome: outcome
                )
            }
        }
        if status == .waitingUser {
            guard waitingReason != nil else {
                throw AgentTaskControlError.invalidWaitingReason(
                    status: status,
                    reason: waitingReason
                )
            }
        } else if waitingReason != nil {
            throw AgentTaskControlError.invalidWaitingReason(
                status: status,
                reason: waitingReason
            )
        }
        self.status = status
        self.outcome = outcome
        self.waitingReason = waitingReason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            status: try container.decode(AgentTaskStatus.self, forKey: .status),
            outcome: try container.decodeIfPresent(
                AgentTaskOutcome.self,
                forKey: .outcome
            ),
            waitingReason: try container.decodeIfPresent(
                AgentTaskWaitingReason.self,
                forKey: .waitingReason
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(outcome, forKey: .outcome)
        try container.encodeIfPresent(waitingReason, forKey: .waitingReason)
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case outcome
        case waitingReason
    }

    public var recoveryState: AgentTaskRecoveryState? {
        switch status {
        case .completed:
            return .completed
        case .paused:
            return .paused
        case .failed:
            return .failed
        case .reconciling:
            return .outcomeUnknown
        case .waitingUser where waitingReason == .connectionInvalid:
            return .connectionInvalid
        case .queued, .running, .pauseRequested, .waitingUser,
             .stopRequested, .discarded:
            return nil
        }
    }
}

public struct AgentTaskControlMachine: Sendable {
    private static let allowedTransitions: [AgentTaskStatus: Set<AgentTaskStatus>] = [
        .queued: [.running, .paused, .waitingUser, .discarded],
        .running: [
            .pauseRequested, .reconciling, .stopRequested, .waitingUser,
            .completed, .failed
        ],
        .pauseRequested: [
            .paused, .reconciling, .stopRequested, .completed, .failed
        ],
        .reconciling: [.paused, .stopRequested, .completed, .failed],
        .paused: [.running, .stopRequested, .discarded],
        .stopRequested: [.reconciling, .completed, .failed],
        .waitingUser: [
            .running, .paused, .stopRequested, .waitingUser, .discarded
        ],
        .completed: [],
        .failed: [.queued, .discarded],
        .discarded: []
    ]

    public init() {}

    public func transition(
        _ current: AgentTaskControlState,
        to nextStatus: AgentTaskStatus,
        outcome: AgentTaskOutcome? = nil,
        waitingReason: AgentTaskWaitingReason? = nil,
        hasAdoptedOutput: Bool = false
    ) throws -> AgentTaskControlState {
        guard Self.allowedTransitions[current.status, default: []]
            .contains(nextStatus) else {
            throw AgentTaskControlError.invalidTransition(
                from: current.status,
                to: nextStatus
            )
        }
        if nextStatus == .discarded {
            guard !hasAdoptedOutput else {
                throw AgentTaskControlError.adoptedOutputCannotBeDiscarded
            }
        }
        if nextStatus == .completed {
            if current.status == .stopRequested {
                guard outcome == .kept else {
                    throw AgentTaskControlError.invalidOutcome(
                        status: nextStatus,
                        outcome: outcome
                    )
                }
            } else {
                guard outcome == .natural else {
                    throw AgentTaskControlError.invalidOutcome(
                        status: nextStatus,
                        outcome: outcome
                    )
                }
            }
        }
        return try AgentTaskControlState(
            status: nextStatus,
            outcome: outcome,
            waitingReason: waitingReason
        )
    }
}
