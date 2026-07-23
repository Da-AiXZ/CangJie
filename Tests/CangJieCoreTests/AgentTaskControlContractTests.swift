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
