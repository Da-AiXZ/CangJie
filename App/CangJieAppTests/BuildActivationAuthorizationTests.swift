import GRDB
import XCTest
@testable import CangJie

final class BuildActivationAuthorizationTests: XCTestCase {
    private final class MutableBundleBuildIdentityLoader: BundleBuildIdentityLoading {
        var infoDictionary: [String: Any]?

        init(infoDictionary: [String: Any]?) {
            self.infoDictionary = infoDictionary
        }

        func loadInfoDictionary() -> [String: Any]? { infoDictionary }
    }

    private final class BlockingBundleBuildIdentityLoader: BundleBuildIdentityLoading {
        let started = DispatchSemaphore(value: 0)
        let proceed = DispatchSemaphore(value: 0)
        let infoDictionary: [String: Any]?

        init(infoDictionary: [String: Any]?) {
            self.infoDictionary = infoDictionary
        }

        func loadInfoDictionary() -> [String: Any]? {
            started.signal()
            proceed.wait()
            return infoDictionary
        }
    }

    private final class RecordingAuthorizer: AgentExecutionAuthorizing {
        private(set) var operations: [GovernedAgentOperation] = []
        var deniedOperation: GovernedAgentOperation?

        func authorize(_ operation: GovernedAgentOperation) throws {
            operations.append(operation)
            if deniedOperation == operation {
                throw AgentExecutionAuthorizationError.buildNotActive
            }
        }
    }

    func testAuthorizerRechecksInstalledBundleOnEveryAuthorization() throws {
        let compiled = BuildIdentityStamp(
            version: "1.0",
            build: "28",
            commit: "0123456789ab",
            fingerprint: "abc123def4567890",
            candidateSetID: "candidate-a"
        )
        let installed = BuildIdentityStamp(
            version: "1.0",
            build: "29",
            commit: "fedcba987654",
            fingerprint: "fed456abc1237890",
            candidateSetID: "candidate-b"
        )
        let loader = MutableBundleBuildIdentityLoader(infoDictionary: compiled.infoDictionary)
        let authorizer = BuildActivationAgentAuthorizer(
            compiledBuildStamp: compiled,
            bundleIdentityLoader: loader,
            allowed: true
        )

        XCTAssertNoThrow(try authorizer.authorize(.agentTurn))

        loader.infoDictionary = installed.infoDictionary
        authorizer.update(allowed: true)

        XCTAssertThrowsError(try authorizer.authorize(.durableMutation)) { error in
            XCTAssertEqual(error as? AgentExecutionAuthorizationError, .buildNotActive)
        }
    }

    func testConcurrentRevocationInvalidatesInFlightAuthorization() throws {
        let stamp = BuildIdentityStamp(
            version: "1.0", build: "28", commit: "0123456789ab",
            fingerprint: "abc123def4567890", candidateSetID: "candidate-a"
        )
        let loader = BlockingBundleBuildIdentityLoader(infoDictionary: stamp.infoDictionary)
        let authorizer = BuildActivationAgentAuthorizer(
            compiledBuildStamp: stamp,
            bundleIdentityLoader: loader,
            allowed: true
        )
        let completed = expectation(description: "authorization completes")
        let resultLock = NSLock()
        var capturedError: Error?

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try authorizer.authorize(.durableMutation)
            } catch {
                resultLock.lock()
                capturedError = error
                resultLock.unlock()
            }
            completed.fulfill()
        }

        XCTAssertEqual(loader.started.wait(timeout: .now() + 2), .success)
        authorizer.update(allowed: false)
        loader.proceed.signal()
        wait(for: [completed], timeout: 2)

        resultLock.lock()
        let error = capturedError
        resultLock.unlock()
        XCTAssertEqual(error as? AgentExecutionAuthorizationError, .buildNotActive)
    }

    func testRevocationCannotInterleaveWithAuthorizedMutationBody() throws {
        let stamp = BuildIdentityStamp(
            version: "1.0", build: "28", commit: "0123456789ab",
            fingerprint: "abc123def4567890", candidateSetID: "candidate-a"
        )
        let loader = MutableBundleBuildIdentityLoader(infoDictionary: stamp.infoDictionary)
        let authorizer = BuildActivationAgentAuthorizer(
            compiledBuildStamp: stamp,
            bundleIdentityLoader: loader,
            allowed: true
        )
        let bodyStarted = DispatchSemaphore(value: 0)
        let bodyMayFinish = DispatchSemaphore(value: 0)
        let mutationFinished = expectation(description: "mutation finishes")
        let revocationFinished = expectation(description: "revocation finishes")
        let resultLock = NSLock()
        var mutationRan = false
        var capturedMutationError: Error?

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try authorizer.performAuthorized(.durableMutation) {
                    bodyStarted.signal()
                    bodyMayFinish.wait()
                    resultLock.lock()
                    mutationRan = true
                    resultLock.unlock()
                }
            } catch {
                resultLock.lock()
                capturedMutationError = error
                resultLock.unlock()
            }
            mutationFinished.fulfill()
        }

        XCTAssertEqual(bodyStarted.wait(timeout: .now() + 2), .success)
        DispatchQueue.global(qos: .userInitiated).async {
            authorizer.update(allowed: false)
            revocationFinished.fulfill()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [revocationFinished], timeout: 0.1), .timedOut)
        bodyMayFinish.signal()
        wait(for: [mutationFinished, revocationFinished], timeout: 2)

        resultLock.lock()
        let didRun = mutationRan
        let mutationError = capturedMutationError
        resultLock.unlock()
        XCTAssertTrue(didRun)
        XCTAssertNil(mutationError)
        XCTAssertThrowsError(try authorizer.authorize(.durableMutation))
    }

    func testDeniedRuntimeInitializationDoesNotCreateConversation() throws {
        try withDatabase { database in
            let authorizer = RecordingAuthorizer()
            authorizer.deniedOperation = .runtimeInitialization

            XCTAssertThrowsError(try AgentRuntime(database: database, authorizer: authorizer))
            let count = try database.queue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM agentConversation") ?? -1
            }

            XCTAssertEqual(count, 0)
            XCTAssertEqual(authorizer.operations, [.runtimeInitialization])
        }
    }

    func testChapterPipelineRequestsOperationSpecificAuthorization() throws {
        try withDatabase { database in
            let authorizer = RecordingAuthorizer()
            let runtime = try AgentRuntime(database: database, authorizer: authorizer)

            _ = try runtime.handleUserMessage("create a cultivation novel")
            for answer in ["Forbidden inheritance", "Save his sister", "Lose one memory"] {
                _ = try runtime.handleUserMessage(answer)
            }
            let pending = try runtime.restore()
            let approval = try XCTUnwrap(pending.openingPlanApproval)
            _ = try runtime.approveOpeningPlan(
                approvalRequestID: approval.id,
                displayedBindingHash: approval.bindingHash
            )
            _ = try runtime.handleUserMessage("generate chapter")
            _ = try runtime.handleUserMessage("reject: the protagonist reacts instead of choosing")
            for answer in [
                "The danger is explained before the choice.",
                "Keep the inheritance cost and the second paragraph.",
                "End with the protagonist entering the sect trial voluntarily."
            ] {
                _ = try runtime.handleUserMessage(answer)
            }
            _ = try runtime.handleUserMessage("confirm rewrite")
            _ = try runtime.handleUserMessage("accept and freeze")

            let operations = Set(authorizer.operations)
            XCTAssertTrue(operations.contains(.runtimeInitialization))
            XCTAssertTrue(operations.contains(.chapterGenerate))
            XCTAssertTrue(operations.contains(.chapterReject))
            XCTAssertTrue(operations.contains(.chapterDiagnosis))
            XCTAssertTrue(operations.contains(.chapterRewrite))
            XCTAssertTrue(operations.contains(.chapterAccept))
            XCTAssertTrue(operations.contains(.durableMutation))
        }
    }

    func testDeniedChapterGenerationDoesNotCreateChapterVersionOrReceipt() throws {
        try withDatabase { database in
            let authorizer = RecordingAuthorizer()
            let runtime = try AgentRuntime(database: database, authorizer: authorizer)
            _ = try runtime.handleUserMessage("create a cultivation novel")
            for answer in ["Forbidden inheritance", "Save his sister", "Lose one memory"] {
                _ = try runtime.handleUserMessage(answer)
            }
            let pending = try runtime.restore()
            let approval = try XCTUnwrap(pending.openingPlanApproval)
            _ = try runtime.approveOpeningPlan(
                approvalRequestID: approval.id,
                displayedBindingHash: approval.bindingHash
            )
            let projectID = try XCTUnwrap(try runtime.restore().session.focusedProjectID)
            let versionsBefore = try database.countChapterVersions(projectID: projectID, chapterNumber: 1)
            let receiptsBefore = try database.countToolReceipts(toolID: "chapter.generate")
            authorizer.deniedOperation = .chapterGenerate

            XCTAssertThrowsError(try runtime.handleUserMessage("generate chapter"))

            XCTAssertEqual(try database.countChapterVersions(projectID: projectID, chapterNumber: 1), versionsBefore)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.generate"), receiptsBefore)
            XCTAssertNil(try runtime.restore().chapter)
        }
    }

    func testDeniedChapterAcceptanceKeepsReviewStateAndCreatesNoReceipt() throws {
        try withDatabase { database in
            let authorizer = RecordingAuthorizer()
            let runtime = try AgentRuntime(database: database, authorizer: authorizer)
            _ = try runtime.handleUserMessage("create a cultivation novel")
            for answer in ["Forbidden inheritance", "Save his sister", "Lose one memory"] {
                _ = try runtime.handleUserMessage(answer)
            }
            let pending = try runtime.restore()
            let approval = try XCTUnwrap(pending.openingPlanApproval)
            _ = try runtime.approveOpeningPlan(
                approvalRequestID: approval.id,
                displayedBindingHash: approval.bindingHash
            )
            _ = try runtime.handleUserMessage("generate chapter")
            let before = try XCTUnwrap(try runtime.restore().chapter)
            let versionsBefore = try database.countChapterVersions(
                projectID: before.calibration.projectID,
                chapterNumber: 1
            )
            let receiptsBefore = try database.countToolReceipts(toolID: "chapter.accept")
            authorizer.deniedOperation = .chapterAccept

            XCTAssertThrowsError(try runtime.handleUserMessage("accept and freeze"))

            let after = try XCTUnwrap(try runtime.restore().chapter)
            XCTAssertEqual(after.stage, before.stage)
            XCTAssertEqual(after.activeVersion.id, before.activeVersion.id)
            XCTAssertEqual(
                try database.countChapterVersions(
                    projectID: before.calibration.projectID,
                    chapterNumber: 1
                ),
                versionsBefore
            )
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.accept"), receiptsBefore)
        }
    }

    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        try body(AppDatabase(path: directory.appendingPathComponent("test.sqlite").path))
    }
}
