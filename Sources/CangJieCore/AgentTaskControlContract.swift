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

public enum AgentTaskControlError: Error, Equatable, Sendable {
    case invalidTransition(from: AgentTaskStatus, to: AgentTaskStatus)
    case invalidOutcome(status: AgentTaskStatus, outcome: AgentTaskOutcome?)
    case adoptedOutputCannotBeDiscarded
}

public struct AgentTaskControlState: Codable, Equatable, Sendable {
    public let status: AgentTaskStatus
    public let outcome: AgentTaskOutcome?

    public init(
        status: AgentTaskStatus,
        outcome: AgentTaskOutcome? = nil
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
        self.status = status
        self.outcome = outcome
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            status: try container.decode(AgentTaskStatus.self, forKey: .status),
            outcome: try container.decodeIfPresent(
                AgentTaskOutcome.self,
                forKey: .outcome
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(outcome, forKey: .outcome)
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case outcome
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
        .waitingUser: [.running, .paused, .stopRequested, .discarded],
        .completed: [],
        .failed: [.queued, .discarded],
        .discarded: []
    ]

    public init() {}

    public func transition(
        _ current: AgentTaskControlState,
        to nextStatus: AgentTaskStatus,
        outcome: AgentTaskOutcome? = nil,
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
        return try AgentTaskControlState(status: nextStatus, outcome: outcome)
    }
}
