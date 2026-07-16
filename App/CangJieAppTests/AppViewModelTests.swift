import XCTest
@testable import CangJie

final class AppViewModelTests: XCTestCase {
    private enum StubDatabaseError: Error {
        case openFailed
    }

    private struct StubSecretRepository: SecretRepository {
        func save(_ secret: String, account: String) throws {}
        func contains(account: String) throws -> Bool { false }
        func delete(account: String) throws {}
    }

    @MainActor
    func testProvidedDatabaseSkipsDefaultFactoryAndRemainsUsable() throws {
        let (database, directory) = try makeDatabase()
        defer { try? FileManager.default.removeItem(at: directory) }
        try database.saveDraft("existing draft", now: Date(timeIntervalSince1970: 1_000))
        var factoryCalls = 0

        let viewModel = AppViewModel(
            database: database,
            databaseFactory: {
                factoryCalls += 1
                XCTFail("Default database factory must not run when a database is provided")
                return database
            },
            keychain: StubSecretRepository()
        )

        XCTAssertEqual(factoryCalls, 0)
        XCTAssertEqual(viewModel.draft, "existing draft")
        XCTAssertTrue(viewModel.status.hasPrefix("SQLite 已就绪"))

        viewModel.draft = "updated draft"
        viewModel.saveDraft()

        XCTAssertEqual(try database.loadDraft()?.content, "updated draft")
    }

    @MainActor
    func testMissingDatabaseInvokesDefaultFactoryExactlyOnce() throws {
        let (database, directory) = try makeDatabase()
        defer { try? FileManager.default.removeItem(at: directory) }
        var factoryCalls = 0

        let viewModel = AppViewModel(
            databaseFactory: {
                factoryCalls += 1
                return database
            },
            keychain: StubSecretRepository()
        )

        XCTAssertEqual(factoryCalls, 1)
        XCTAssertEqual(viewModel.draft, "")
        XCTAssertTrue(viewModel.status.hasPrefix("SQLite 已就绪"))
    }

    @MainActor
    func testDefaultDatabaseFailureFailsClosedWithoutRetry() {
        var factoryCalls = 0
        let viewModel = AppViewModel(
            databaseFactory: {
                factoryCalls += 1
                throw StubDatabaseError.openFailed
            },
            keychain: StubSecretRepository()
        )

        XCTAssertEqual(factoryCalls, 1)
        XCTAssertTrue(viewModel.status.contains("DB-INIT"))
        XCTAssertEqual(viewModel.draft, "")

        viewModel.saveDraft()
        viewModel.createCheckpoint(reason: "test")

        XCTAssertEqual(factoryCalls, 1)
        XCTAssertTrue(viewModel.status.contains("DB-INIT"))
    }


    @MainActor
    func testAgentCreationMessageExecutesProjectToolAndClearsComposer() throws {
        let (database, directory) = try makeDatabase()
        defer { try? FileManager.default.removeItem(at: directory) }
        let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())

        viewModel.draft = "create a cultivation novel"
        viewModel.sendAgentMessage()

        XCTAssertEqual(viewModel.draft, "")
        XCTAssertEqual(viewModel.projects.count, 1)
        XCTAssertEqual(viewModel.projects.first?.premise, "create a cultivation novel")
        XCTAssertEqual(viewModel.status, "Verified: project.create")
        XCTAssertTrue(viewModel.conversationMessages.last?.contains("Project created") == true)
    }

    private func makeDatabase() throws -> (AppDatabase, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try AppDatabase(path: directory.appendingPathComponent("test.sqlite").path)
        return (database, directory)
    }
}
