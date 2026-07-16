import XCTest
@testable import CangJieCore

final class TaskStateMachineTests: XCTestCase {
    func testRunningCanPauseAtSafeCheckpoint() throws {
        XCTAssertEqual(try TaskStateMachine().transition(from: .running, to: .paused), .paused)
    }

    func testCompletedTaskCannotRunAgain() {
        XCTAssertThrowsError(try TaskStateMachine().transition(from: .completed, to: .running)) { error in
            XCTAssertEqual(error as? TaskTransitionError, .invalidTransition(from: .completed, to: .running))
        }
    }

    func testFailedTaskCanBeRequeued() throws {
        XCTAssertEqual(try TaskStateMachine().transition(from: .failed, to: .queued), .queued)
    }
}
