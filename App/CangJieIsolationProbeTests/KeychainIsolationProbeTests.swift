import Foundation
import Security
import XCTest
@testable import CangJieKeychainIsolationProbe

final class KeychainIsolationProbeTests: XCTestCase {
    func testAllThreeChecksPassOnlyForExactExpectedStatuses() {
        let client = ScriptedSecurityItemClient(
            addStatuses: [errSecSuccess],
            copyResponses: [
                .init(status: errSecSuccess, value: Data([0xCA, 0xFE]) as CFData),
                .init(status: errSecItemNotFound),
                .init(status: errSecItemNotFound),
                .init(status: errSecMissingEntitlement)
            ],
            deleteStatuses: [errSecItemNotFound, errSecSuccess]
        )
        let probe = KeychainIsolationProbe(
            securityClient: client,
            randomBytesGenerator: FixedRandomBytesGenerator(bytes: Data([0xCA, 0xFE]))
        )

        let report = probe.run()

        XCTAssertEqual(report.ownGroupControl.disposition, .pass)
        XCTAssertEqual(report.defaultGroupLookup.disposition, .pass)
        XCTAssertEqual(report.forbiddenGroupLookup.disposition, .pass)
        XCTAssertEqual(report.overallDisposition, .pass)
    }

    func testExplicitMainGroupSuccessIsCriticalFailure() {
        let report = makeReport(explicitMainGroupStatus: errSecSuccess)

        XCTAssertEqual(report.forbiddenGroupLookup.disposition, .criticalFail)
        XCTAssertEqual(report.overallDisposition, .criticalFail)
    }

    func testExplicitMainGroupItemNotFoundIsInconclusiveAndFailsClosed() {
        let report = makeReport(explicitMainGroupStatus: errSecItemNotFound)

        XCTAssertEqual(report.forbiddenGroupLookup.disposition, .inconclusive)
        XCTAssertEqual(report.overallDisposition, .inconclusive)
    }

    func testExplicitMainGroupUnexpectedStatusIsInconclusiveAndFailsClosed() {
        let report = makeReport(explicitMainGroupStatus: errSecInteractionNotAllowed)

        XCTAssertEqual(report.forbiddenGroupLookup.disposition, .inconclusive)
        XCTAssertEqual(report.overallDisposition, .inconclusive)
    }

    func testDefaultGroupSuccessIsCriticalFailure() {
        let report = makeReport(defaultGroupStatus: errSecSuccess)

        XCTAssertEqual(report.defaultGroupLookup.disposition, .criticalFail)
        XCTAssertEqual(report.overallDisposition, .criticalFail)
    }

    func testDefaultGroupUnexpectedStatusIsInconclusiveAndFailsClosed() {
        let report = makeReport(defaultGroupStatus: errSecInteractionNotAllowed)

        XCTAssertEqual(report.defaultGroupLookup.disposition, .inconclusive)
        XCTAssertEqual(report.overallDisposition, .inconclusive)
    }

    func testOwnGroupControlFailureMakesResultInconclusive() {
        let client = ScriptedSecurityItemClient(
            addStatuses: [errSecMissingEntitlement],
            copyResponses: [
                .init(status: errSecItemNotFound),
                .init(status: errSecMissingEntitlement)
            ],
            deleteStatuses: [errSecItemNotFound]
        )
        let probe = KeychainIsolationProbe(
            securityClient: client,
            randomBytesGenerator: FixedRandomBytesGenerator(bytes: Data([0x01]))
        )

        let report = probe.run()

        XCTAssertEqual(report.ownGroupControl.disposition, .inconclusive)
        XCTAssertEqual(report.overallDisposition, .inconclusive)
    }

    func testProbeCreatesReadsAndDeletesOnlyInsideItsOwnAccessGroup() throws {
        let client = passingClient()
        let probe = KeychainIsolationProbe(
            securityClient: client,
            randomBytesGenerator: FixedRandomBytesGenerator(bytes: Data([0xCA, 0xFE]))
        )

        _ = probe.run()

        XCTAssertEqual(client.addQueries.count, 1)
        XCTAssertEqual(client.deleteQueries.count, 2, "The probe must clean stale control data and delete the newly created control item")
        for query in client.addQueries + client.deleteQueries {
            XCTAssertEqual(
                query[kSecAttrAccessGroup as String] as? String,
                KeychainIsolationContract.probeAccessGroup
            )
            XCTAssertEqual(
                query[kSecAttrService as String] as? String,
                KeychainIsolationContract.probeControlService
            )
        }

        let ownRead = try XCTUnwrap(client.copyInvocations.first)
        XCTAssertTrue(ownRead.requestedResult)
        XCTAssertEqual(
            ownRead.query[kSecAttrAccessGroup as String] as? String,
            KeychainIsolationContract.probeAccessGroup
        )
        XCTAssertEqual(ownRead.query[kSecReturnData as String] as? Bool, true)
    }

    func testMainCanaryLookupsNeverRequestOrReceiveCanaryData() {
        let client = passingClient()
        let probe = KeychainIsolationProbe(
            securityClient: client,
            randomBytesGenerator: FixedRandomBytesGenerator(bytes: Data([0xCA, 0xFE]))
        )

        _ = probe.run()

        let canaryLookups = client.copyInvocations.filter {
            ($0.query[kSecAttrService as String] as? String) == KeychainIsolationContract.canaryService
        }
        XCTAssertEqual(canaryLookups.count, 2)

        let defaultLookup = canaryLookups[0]
        XCTAssertNil(defaultLookup.query[kSecAttrAccessGroup as String])
        XCTAssertNil(defaultLookup.query[kSecReturnData as String])
        XCTAssertFalse(defaultLookup.requestedResult)

        let forbiddenLookup = canaryLookups[1]
        XCTAssertEqual(
            forbiddenLookup.query[kSecAttrAccessGroup as String] as? String,
            KeychainIsolationContract.mainAccessGroup
        )
        XCTAssertNil(forbiddenLookup.query[kSecReturnData as String])
        XCTAssertFalse(forbiddenLookup.requestedResult)
    }

    func testContractUsesDedicatedCanaryNamespaceAndNeverSharesMainAccessGroup() {
        XCTAssertEqual(KeychainIsolationContract.canaryService, "com.juyang.CangJie.isolation-canary.v1")
        XCTAssertEqual(KeychainIsolationContract.canaryAccount, "current-canary")
        XCTAssertEqual(KeychainIsolationContract.mainAccessGroup, "com.juyang.CangJie")
        XCTAssertEqual(KeychainIsolationContract.probeAccessGroup, "com.juyang.CangJie.KeychainIsolationProbe")
        XCTAssertNotEqual(KeychainIsolationContract.probeAccessGroup, KeychainIsolationContract.mainAccessGroup)
        XCTAssertNotEqual(KeychainIsolationContract.probeControlService, KeychainIsolationContract.canaryService)
    }

    func testProbeBuildIdentityRequiresExactCandidateSetMatch() {
        let compiled = ProbeBuildIdentityStamp(
            version: "1.0",
            build: "28",
            commit: "0123456789ab",
            fingerprint: "abc123",
            candidateSetID: "candidate-a"
        )
        let matching = ProbeBuildIdentity(compiled: compiled, installed: compiled)
        XCTAssertTrue(matching.isActive)
        XCTAssertEqual(matching.candidateSetText, "candidate-a")

        let differentCandidate = ProbeBuildIdentityStamp(
            version: "1.0",
            build: "28",
            commit: "0123456789ab",
            fingerprint: "abc123",
            candidateSetID: "candidate-b"
        )
        XCTAssertFalse(ProbeBuildIdentity(compiled: compiled, installed: differentCandidate).isActive)
    }

    @MainActor
    func testProbeViewModelRefusesVerificationWhenExecutableIsNotActive() {
        let compiled = ProbeBuildIdentityStamp(
            version: "1.0",
            build: "28",
            commit: "0123456789ab",
            fingerprint: "abc123",
            candidateSetID: "candidate-a"
        )
        let installed = ProbeBuildIdentityStamp(
            version: "1.0",
            build: "29",
            commit: "fedcba987654",
            fingerprint: "def456",
            candidateSetID: "candidate-b"
        )
        let identity = ProbeBuildIdentity(compiled: compiled, installed: installed)
        let model = IsolationProbeViewModel(buildIdentityLoader: { identity })

        model.runVerification()

        XCTAssertEqual(model.state, .idle)
        XCTAssertFalse(model.buildIdentity.isActive)
    }

    @MainActor
    func testSceneActivationRevalidatesIdentityAndBlocksVerificationAfterMismatch() {
        let compiled = ProbeBuildIdentityStamp(
            version: "1.0",
            build: "28",
            commit: "0123456789ab",
            fingerprint: "abc123",
            candidateSetID: "candidate-a"
        )
        let matchingIdentity = ProbeBuildIdentity(compiled: compiled, installed: compiled)
        let mismatchedInstalled = ProbeBuildIdentityStamp(
            version: "1.0",
            build: "29",
            commit: "fedcba987654",
            fingerprint: "def456",
            candidateSetID: "candidate-b"
        )
        let mismatchedIdentity = ProbeBuildIdentity(
            compiled: compiled,
            installed: mismatchedInstalled
        )
        var loadedIdentity = matchingIdentity
        let client = ScriptedSecurityItemClient(
            addStatuses: [],
            copyResponses: [],
            deleteStatuses: []
        )
        let probe = KeychainIsolationProbe(
            securityClient: client,
            randomBytesGenerator: FixedRandomBytesGenerator(bytes: Data([0xCA, 0xFE]))
        )
        let model = IsolationProbeViewModel(
            probe: probe,
            buildIdentityLoader: { loadedIdentity }
        )

        XCTAssertTrue(model.buildIdentity.isActive)
        XCTAssertEqual(model.state, .idle)

        loadedIdentity = mismatchedIdentity
        model.handleScenePhase(.active)

        XCTAssertFalse(model.buildIdentity.isActive)
        XCTAssertEqual(model.state, .idle)

        model.runVerification()

        XCTAssertFalse(model.buildIdentity.isActive)
        XCTAssertEqual(model.state, .idle)
        XCTAssertTrue(client.addQueries.isEmpty)
        XCTAssertTrue(client.copyInvocations.isEmpty)
        XCTAssertTrue(client.deleteQueries.isEmpty)
    }

    private func makeReport(
        defaultGroupStatus: OSStatus = errSecItemNotFound,
        explicitMainGroupStatus: OSStatus = errSecMissingEntitlement
    ) -> KeychainIsolationReport {
        let client = ScriptedSecurityItemClient(
            addStatuses: [errSecSuccess],
            copyResponses: [
                .init(status: errSecSuccess, value: Data([0xCA, 0xFE]) as CFData),
                .init(status: errSecItemNotFound),
                .init(status: defaultGroupStatus),
                .init(status: explicitMainGroupStatus)
            ],
            deleteStatuses: [errSecItemNotFound, errSecSuccess]
        )
        return KeychainIsolationProbe(
            securityClient: client,
            randomBytesGenerator: FixedRandomBytesGenerator(bytes: Data([0xCA, 0xFE]))
        ).run()
    }

    private func passingClient() -> ScriptedSecurityItemClient {
        ScriptedSecurityItemClient(
            addStatuses: [errSecSuccess],
            copyResponses: [
                .init(status: errSecSuccess, value: Data([0xCA, 0xFE]) as CFData),
                .init(status: errSecItemNotFound),
                .init(status: errSecItemNotFound),
                .init(status: errSecMissingEntitlement)
            ],
            deleteStatuses: [errSecItemNotFound, errSecSuccess]
        )
    }
}

private struct FixedRandomBytesGenerator: IsolationProbeRandomBytesGenerating {
    let bytes: Data

    func randomBytes(count: Int) throws -> Data {
        bytes
    }
}

private final class ScriptedSecurityItemClient: IsolationProbeSecurityItemClient {
    struct CopyResponse {
        let status: OSStatus
        let value: CFTypeRef?

        init(status: OSStatus, value: CFTypeRef? = nil) {
            self.status = status
            self.value = value
        }
    }

    struct CopyInvocation {
        let query: [String: Any]
        let requestedResult: Bool
    }

    private var addStatuses: [OSStatus]
    private var copyResponses: [CopyResponse]
    private var deleteStatuses: [OSStatus]

    private(set) var addQueries: [[String: Any]] = []
    private(set) var copyInvocations: [CopyInvocation] = []
    private(set) var deleteQueries: [[String: Any]] = []

    init(
        addStatuses: [OSStatus],
        copyResponses: [CopyResponse],
        deleteStatuses: [OSStatus]
    ) {
        self.addStatuses = addStatuses
        self.copyResponses = copyResponses
        self.deleteStatuses = deleteStatuses
    }

    func add(_ query: [String: Any]) -> OSStatus {
        addQueries.append(query)
        return addStatuses.removeFirst()
    }

    func copyMatching(
        _ query: [String: Any],
        result: UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus {
        copyInvocations.append(.init(query: query, requestedResult: result != nil))
        let response = copyResponses.removeFirst()
        result?.pointee = response.value
        return response.status
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        deleteQueries.append(query)
        return deleteStatuses.removeFirst()
    }

}
