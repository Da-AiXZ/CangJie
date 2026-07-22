import Foundation
import XCTest
@testable import CangJieCore

final class ProjectToolContractTests: XCTestCase {
    private let requestID = UUID(
        uuidString: "81000000-0000-0000-0000-000000000001"
    )!
    private let runID = UUID(
        uuidString: "82000000-0000-0000-0000-000000000002"
    )!
    private let conversationID = UUID(
        uuidString: "83000000-0000-0000-0000-000000000003"
    )!

    func testCreateInvocationIsStrictVersionedAndCanonicallyHashed() throws {
        let first = try makeInvocation(
            providerName: "project_create",
            argumentsJSON: #"{"title":"星河","premise":"凡人追查失踪真相"}"#
        )
        let reordered = try makeInvocation(
            providerName: "project_create",
            argumentsJSON: #"{ "premise" : "凡人追查失踪真相", "title" : "星河" }"#
        )

        XCTAssertEqual(first, reordered)
        XCTAssertEqual(first.toolID, "project.create")
        XCTAssertEqual(first.toolVersion, "1")
        XCTAssertEqual(first.providerCallID, "call-1")
        XCTAssertEqual(first.providerCallIndex, 0)
        XCTAssertEqual(
            first.idempotencyKey,
            "provider.tool.\(requestID.uuidString.lowercased()).0"
        )
        XCTAssertEqual(first.inputHash.utf8.count, 64)
        XCTAssertTrue(
            first.inputHash.unicodeScalars.allSatisfy {
                (0x30...0x39).contains($0.value)
                    || (0x61...0x66).contains($0.value)
            }
        )

        let changed = try makeInvocation(
            providerName: "project_create",
            argumentsJSON: #"{"title":"星河","premise":"另一条故事线"}"#
        )
        XCTAssertNotEqual(first.inputHash, changed.inputHash)
    }

    func testCreateArgumentsRejectMissingUnknownBlankAndUnsafeFields() {
        let invalidArguments = [
            #"{}"#,
            #"{"title":"星河"}"#,
            #"{"title":"星河","premise":"故事","extra":true}"#,
            #"{"title":" ","premise":"故事"}"#,
            #"{"title":"星河","premise":"\u202e故事"}"#
        ]
        for argumentsJSON in invalidArguments {
            XCTAssertThrowsError(
                try makeInvocation(
                    providerName: "project_create",
                    argumentsJSON: argumentsJSON
                )
            ) { error in
                XCTAssertEqual(
                    error as? ProjectToolContractError,
                    .invalidArguments
                )
            }
        }
    }

    func testStatusInvocationAcceptsOnlyAnEmptyObject() throws {
        let status = try makeInvocation(
            providerName: "project_status",
            argumentsJSON: "{}"
        )

        XCTAssertEqual(status.toolID, "project.status")
        XCTAssertEqual(status.toolVersion, "1")
        XCTAssertEqual(status.arguments, .status)
        XCTAssertThrowsError(
            try makeInvocation(
                providerName: "project_status",
                argumentsJSON: #"{"projectID":"forged"}"#
            )
        ) { error in
            XCTAssertEqual(
                error as? ProjectToolContractError,
                .invalidArguments
            )
        }
    }

    func testUnknownToolAndInvalidProviderCallIdentityFailClosed() {
        XCTAssertThrowsError(
            try makeInvocation(
                providerName: "project_delete",
                argumentsJSON: "{}"
            )
        ) { error in
            XCTAssertEqual(
                error as? ProjectToolContractError,
                .unsupportedTool
            )
        }
        XCTAssertThrowsError(
            try ProjectToolInvocation.parse(
                providerFunctionName: "project_status",
                argumentsJSON: "{}",
                providerCallID: "",
                providerCallIndex: 0,
                providerRequestID: requestID,
                runID: runID,
                conversationID: conversationID,
                projectID: nil
            )
        ) { error in
            XCTAssertEqual(
                error as? ProjectToolContractError,
                .invalidInvocationIdentity
            )
        }
    }

    func testHashBindsRequestRunConversationProjectAndProviderCall() throws {
        let baseline = try makeInvocation(
            providerName: "project_status",
            argumentsJSON: "{}"
        )
        let changedCall = try ProjectToolInvocation.parse(
            providerFunctionName: "project_status",
            argumentsJSON: "{}",
            providerCallID: "call-2",
            providerCallIndex: 0,
            providerRequestID: requestID,
            runID: runID,
            conversationID: conversationID,
            projectID: nil
        )
        let changedProject = try ProjectToolInvocation.parse(
            providerFunctionName: "project_status",
            argumentsJSON: "{}",
            providerCallID: "call-1",
            providerCallIndex: 0,
            providerRequestID: requestID,
            runID: runID,
            conversationID: conversationID,
            projectID: UUID()
        )

        XCTAssertNotEqual(baseline.inputHash, changedCall.inputHash)
        XCTAssertNotEqual(baseline.inputHash, changedProject.inputHash)
    }

    private func makeInvocation(
        providerName: String,
        argumentsJSON: String
    ) throws -> ProjectToolInvocation {
        try ProjectToolInvocation.parse(
            providerFunctionName: providerName,
            argumentsJSON: argumentsJSON,
            providerCallID: "call-1",
            providerCallIndex: 0,
            providerRequestID: requestID,
            runID: runID,
            conversationID: conversationID,
            projectID: nil
        )
    }
}
