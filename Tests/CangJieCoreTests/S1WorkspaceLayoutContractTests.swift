import XCTest
@testable import CangJieCore

final class S1WorkspaceLayoutContractTests: XCTestCase {
    func testOrientationChoosesColumnsForLandscapeAndSingleFocusForPortrait() {
        XCTAssertEqual(
            S1WorkspaceLayoutContract.mode(width: 1194, height: 834),
            .landscapeColumns
        )
        XCTAssertEqual(
            S1WorkspaceLayoutContract.mode(width: 834, height: 1194),
            .portraitSingleFocus
        )
        XCTAssertEqual(
            S1WorkspaceLayoutContract.mode(width: 900, height: 900),
            .portraitSingleFocus
        )
        XCTAssertEqual(
            S1WorkspaceLayoutContract.mode(width: 1024, height: 900),
            .landscapeColumns
        )
        XCTAssertEqual(
            S1WorkspaceLayoutContract.mode(width: 820, height: 600),
            .portraitSingleFocus
        )
    }

    func testInvalidGeometryFailsClosedToSingleFocus() {
        XCTAssertEqual(
            S1WorkspaceLayoutContract.mode(width: 0, height: 1194),
            .portraitSingleFocus
        )
        XCTAssertEqual(
            S1WorkspaceLayoutContract.mode(width: .nan, height: 1194),
            .portraitSingleFocus
        )
        XCTAssertEqual(
            S1WorkspaceLayoutContract.mode(width: 834, height: -.infinity),
            .portraitSingleFocus
        )
    }

    func testReadableWorkspaceWidthProjectionKeepsReaderAndCompanionNearSixtySixThirtyFour() throws {
        for availableWidth in [1024.0, 1194.0, 1366.0] {
            let projection = try XCTUnwrap(
                S1WorkspaceLayoutContract.readableWorkspaceWidths(
                    availableWidth: availableWidth,
                    dividerWidth: 1
                )
            )
            let contentWidth = projection.readerWidth + projection.companionWidth

            XCTAssertEqual(contentWidth, availableWidth - 1, accuracy: 0.000_001)
            XCTAssertEqual(projection.readerWidth / contentWidth, 0.66, accuracy: 0.000_001)
            XCTAssertEqual(projection.companionWidth / contentWidth, 0.34, accuracy: 0.000_001)
        }
    }

    func testReadableWorkspaceWidthProjectionFailsClosedForInvalidInputs() {
        let invalidInputs: [(availableWidth: Double, dividerWidth: Double)] = [
            (0, 1),
            (-1, 1),
            (.nan, 1),
            (.infinity, 1),
            (1024, 0),
            (1024, -1),
            (1024, .nan),
            (1024, .infinity),
            (1, 1),
            (1, 2)
        ]

        for input in invalidInputs {
            XCTAssertNil(
                S1WorkspaceLayoutContract.readableWorkspaceWidths(
                    availableWidth: input.availableWidth,
                    dividerWidth: input.dividerWidth
                )
            )
        }
    }

    func testLayoutProjectionKeepsIndependentPagesInTheLeftRegionForLandscape() {
        XCTAssertEqual(
            S1WorkspaceLayoutContract.projection(for: .landscapeColumns),
            S1WorkspaceLayoutProjection(
                showsPersistentActivityBar: true,
                showsPersistentConversationRail: true,
                usesSinglePrimaryFocus: false,
                opensIndependentPagesAsOverlay: false
            )
        )
    }

    func testLayoutProjectionKeepsIndependentPagesAsOverlayForPortrait() {
        XCTAssertEqual(
            S1WorkspaceLayoutContract.projection(for: .portraitSingleFocus),
            S1WorkspaceLayoutProjection(
                showsPersistentActivityBar: false,
                showsPersistentConversationRail: false,
                usesSinglePrimaryFocus: true,
                opensIndependentPagesAsOverlay: true
            )
        )
    }

    func testFocusesHideReaderUntilReadableContentExistsAndNormalizeStaleReaderSelection() {
        XCTAssertEqual(
            S1WorkspaceLayoutContract.availableFocuses(hasReadableContent: false),
            [.conversation, .results]
        )
        XCTAssertEqual(
            S1WorkspaceLayoutContract.availableFocuses(hasReadableContent: true),
            [.reader, .conversation, .results]
        )
        XCTAssertEqual(
            S1WorkspaceLayoutContract.normalizedFocus(.reader, hasReadableContent: false),
            .conversation
        )
        XCTAssertEqual(
            S1WorkspaceLayoutContract.normalizedFocus(.results, hasReadableContent: false),
            .results
        )
    }
}
