import XCTest
@testable import CangJie

#if DEBUG
@MainActor
final class CangJieUITestFixtureBootstrapTests: XCTestCase {
    private let identityLoader = StaticBundleBuildIdentityLoader(
        infoDictionary: BuildIdentityStamp.generated.infoDictionary
    )

    func testReturnsNilWhenNoFixtureWasRequested() {
        XCTAssertNil(
            CangJieUITestFixtureBootstrap.makeViewModelIfRequested(
                environment: [:],
                bundleIdentityLoader: identityLoader
            )
        )
    }

    func testFixtureRequestWithoutDatabaseScopeFailsClosed() throws {
        let viewModel = try XCTUnwrap(
            CangJieUITestFixtureBootstrap.makeViewModelIfRequested(
                environment: ["CANGJIE_UI_TEST_FIXTURE": "persisted-novel-shelf"],
                bundleIdentityLoader: identityLoader
            )
        )

        XCTAssertFalse(viewModel.isComposerAvailable)
        XCTAssertEqual(
            viewModel.diagnosticErrorMessage,
            "SQLite initialization failed (DB-INIT)"
        )
    }

    func testFixtureRequestWithInvalidDatabaseScopeFailsClosed() throws {
        let viewModel = try XCTUnwrap(
            CangJieUITestFixtureBootstrap.makeViewModelIfRequested(
                environment: [
                    "CANGJIE_UI_TEST_FIXTURE": "persisted-novel-shelf",
                    "CANGJIE_UI_TEST_DATABASE_SCOPE": "not-a-uuid"
                ],
                bundleIdentityLoader: identityLoader
            )
        )

        XCTAssertFalse(viewModel.isComposerAvailable)
        XCTAssertEqual(
            viewModel.diagnosticErrorMessage,
            "SQLite initialization failed (DB-INIT)"
        )
    }
}
#endif
