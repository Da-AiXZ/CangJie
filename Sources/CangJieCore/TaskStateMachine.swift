import Foundation

public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case waitingNetwork
    case waitingUser
    case paused
    case failed
    case completed
    case cancelled
}

public enum TaskTransitionError: Error, Equatable, Sendable {
    case invalidTransition(from: TaskStatus, to: TaskStatus)
}

public struct TaskStateMachine: Sendable {
    private static let allowedTransitions: [TaskStatus: Set<TaskStatus>] = [
        .queued: [.running, .paused, .cancelled],
        .running: [.waitingNetwork, .waitingUser, .paused, .failed, .completed, .cancelled],
        .waitingNetwork: [.running, .paused, .failed, .cancelled],
        .waitingUser: [.running, .paused, .cancelled],
        .paused: [.running, .cancelled],
        .failed: [.queued, .cancelled],
        .completed: [],
        .cancelled: []
    ]

    public init() {}

    public func transition(from current: TaskStatus, to next: TaskStatus) throws -> TaskStatus {
        guard Self.allowedTransitions[current, default: []].contains(next) else {
            throw TaskTransitionError.invalidTransition(from: current, to: next)
        }
        return next
    }
}