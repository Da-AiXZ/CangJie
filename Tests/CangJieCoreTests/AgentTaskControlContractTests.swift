import Foundation
import XCTest
@testable import CangJieCore

final class AgentTaskControlContractTests: XCTestCase {
    func testPauseRequestMustSettleBeforeResume() throws {
        let machine = AgentTaskControlMachine()
        let running = try AgentTaskControlState(status: .running)

        let requested = try machine.transition(
            running,
            to: .pauseRequested
        )
        XCTAssertThrowsError(try machine.transition(requested, to: .running))

        let paused = try machine.transition(requested, to: .paused)
        XCTAssertEqual(
            try machine.transition(paused, to: .running),
            running
        )
    }

    func testSendingPauseCanEnterReconciliationBeforeSafePause() throws {
        let machine = AgentTaskControlMachine()
        let requested = try machine.transition(
            try AgentTaskControlState(status: .running),
            to: .pauseRequested
        )

        let reconciling = try machine.transition(requested, to: .reconciling)
        XCTAssertThrowsError(try machine.transition(reconciling, to: .running))
        XCTAssertEqual(
            try machine.transition(reconciling, to: .paused).status,
            .paused
        )
    }

    func testStopAndKeepRequiresASettledKeptOutcome() throws {
        let machine = AgentTaskControlMachine()
        let requested = try machine.transition(
            try AgentTaskControlState(status: .paused),
            to: .stopRequested
        )

        XCTAssertThrowsError(try machine.transition(requested, to: .completed))
        XCTAssertEqual(
            try machine.transition(
                requested,
                to: .completed,
                outcome: .kept
            ),
            try AgentTaskControlState(status: .completed, outcome: .kept)
        )
    }

    func testDiscardFailsClosedAfterOutputAdoption() throws {
        let machine = AgentTaskControlMachine()
        let paused = try AgentTaskControlState(status: .paused)

        XCTAssertThrowsError(
            try machine.transition(
                paused,
                to: .discarded,
                outcome: .discarded,
                hasAdoptedOutput: true
            )
        ) { error in
            XCTAssertEqual(
                error as? AgentTaskControlError,
                .adoptedOutputCannotBeDiscarded
            )
        }
    }

    func testKeptTaskIsFinalAndCannotBeDiscardedLater() throws {
        let machine = AgentTaskControlMachine()
        let kept = try AgentTaskControlState(status: .completed, outcome: .kept)

        XCTAssertThrowsError(
            try machine.transition(
                kept,
                to: .discarded,
                outcome: .discarded,
                hasAdoptedOutput: false
            )
        )
    }

    func testNaturalCompletionCannotBeDiscardedOrResumed() throws {
        let machine = AgentTaskControlMachine()
        let completed = try AgentTaskControlState(
            status: .completed,
            outcome: .natural
        )

        XCTAssertThrowsError(
            try machine.transition(
                completed,
                to: .discarded,
                outcome: .discarded
            )
        )
        XCTAssertThrowsError(try machine.transition(completed, to: .running))
    }

    func testDefinitelyFailedTaskRequiresExplicitRequeueBeforeRunning() throws {
        let machine = AgentTaskControlMachine()
        let failed = try AgentTaskControlState(status: .failed)

        XCTAssertThrowsError(try machine.transition(failed, to: .running))
        XCTAssertEqual(
            try machine.transition(failed, to: .queued).status,
            .queued
        )
    }

    func testWaitingForNetworkRequiresExplicitConfirmationBeforeRunning() throws {
        let machine = AgentTaskControlMachine()
        let waiting = try machine.transition(
            try AgentTaskControlState(status: .running),
            to: .waitingUser,
            waitingReason: .networkConfirmation
        )

        XCTAssertEqual(waiting.status, .waitingUser)
        XCTAssertEqual(waiting.waitingReason, .networkConfirmation)

        let resumed = try machine.transition(waiting, to: .running)
        XCTAssertEqual(resumed.status, .running)
        XCTAssertNil(resumed.waitingReason)
    }

    func testWaitingReasonDistinguishesNetworkFromInvalidConnection() throws {
        let machine = AgentTaskControlMachine()
        let running = try AgentTaskControlState(status: .running)

        XCTAssertNotEqual(
            try machine.transition(
                running,
                to: .waitingUser,
                waitingReason: .networkConfirmation
            ),
            try machine.transition(
                running,
                to: .waitingUser,
                waitingReason: .connectionInvalid
            )
        )
    }

    func testWaitingReasonFailsClosedWhenMissingOrAttachedToAnotherStatus() {
        XCTAssertThrowsError(
            try AgentTaskControlState(status: .waitingUser)
        ) { error in
            XCTAssertEqual(
                error as? AgentTaskControlError,
                .invalidWaitingReason(status: .waitingUser, reason: nil)
            )
        }
        XCTAssertThrowsError(
            try AgentTaskControlState(
                status: .running,
                waitingReason: .networkConfirmation
            )
        ) { error in
            XCTAssertEqual(
                error as? AgentTaskControlError,
                .invalidWaitingReason(
                    status: .running,
                    reason: .networkConfirmation
                )
            )
        }
    }

    func testRecoveryProjectionHasExactlyFiveTruthfulStates() throws {
        let cases: [(AgentTaskControlState, AgentTaskRecoveryState)] = [
            (
                try AgentTaskControlState(
                    status: .completed,
                    outcome: .natural
                ),
                .completed
            ),
            (try AgentTaskControlState(status: .paused), .paused),
            (try AgentTaskControlState(status: .failed), .failed),
            (try AgentTaskControlState(status: .reconciling), .outcomeUnknown),
            (
                try AgentTaskControlState(
                    status: .waitingUser,
                    waitingReason: .connectionInvalid
                ),
                .connectionInvalid
            )
        ]

        for (state, expected) in cases {
            XCTAssertEqual(state.recoveryState, expected)
        }
        XCTAssertNil(
            try AgentTaskControlState(
                status: .waitingUser,
                waitingReason: .networkConfirmation
            ).recoveryState
        )
        XCTAssertEqual(Set(cases.map(\.1)), Set(AgentTaskRecoveryState.allCases))
    }

    func testInvalidStatusOutcomePairFailsAtDecodeBoundary() {
        let data = Data(#"{"status":"running","outcome":"kept"}"#.utf8)

        XCTAssertThrowsError(
            try JSONDecoder().decode(AgentTaskControlState.self, from: data)
        ) { error in
            XCTAssertEqual(
                error as? AgentTaskControlError,
                .invalidOutcome(status: .running, outcome: .kept)
            )
        }
    }
}
