import CangJieCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import CangJie

final class ModelDiscoveryNetworkTransportTests: XCTestCase {
    func testTotalDeadlineCanExpireBeforeARequestAndCancelsAHungTransport() async throws {
        let noSendTransport = RecordingTransport(
            responses: [QueuedResponse(200, #"{"data":[]}"#)]
        )
        let expiredClient = ModelDiscoveryNetworkClient(
            transport: noSendTransport,
            resolver: SequenceResolver([]),
            clock: SequenceClock([0, 121]),
            maximumDiscoveryDuration: 120,
            maximumRequestDuration: 30
        )
        do {
            _ = try await expiredClient.discover(
                try ModelDiscoveryNetworkFixture.makeAttempt(
                    provider: .openAI,
                    baseURL: URL(string: "https://api.openai.com/v1")!
                )
            )
            XCTFail("Expected the total deadline to stop the first request")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryNetworkError,
                .discoveryDeadlineExceeded
            )
        }
        let expiredRequests = await noSendTransport.requests()
        XCTAssertTrue(expiredRequests.isEmpty)

        let hangingTransport = CancellationRecordingTransport()
        let hungClient = ModelDiscoveryNetworkClient(
            transport: hangingTransport,
            resolver: SequenceResolver([]),
            clock: TransportStartClock(transport: hangingTransport),
            maximumDiscoveryDuration: 120,
            maximumRequestDuration: 30
        )
        do {
            _ = try await hungClient.discover(
                try ModelDiscoveryNetworkFixture.makeAttempt(
                    provider: .openAI,
                    baseURL: URL(string: "https://api.openai.com/v1")!
                )
            )
            XCTFail("Expected the deadline task to cancel a hung transport")
        } catch {
            XCTAssertEqual(
                error as? ModelDiscoveryNetworkError,
                .discoveryDeadlineExceeded
            )
        }
        let cancellationState = await hangingTransport.state()
        XCTAssertTrue(cancellationState.didStart)
        XCTAssertTrue(cancellationState.didCancel)
    }

    func testBoundedAccumulatorRejectsDeclaredAndStreamingOverflow() throws {
        var declared = ModelDiscoveryResponseAccumulator(maximumBytes: 4)
        XCTAssertThrowsError(try declared.prepare(expectedContentLength: 5)) { error in
            XCTAssertEqual(error as? ModelDiscoveryNetworkError, .responseTooLarge)
        }

        var streamed = ModelDiscoveryResponseAccumulator(maximumBytes: 4)
        try streamed.append(Data([1, 2, 3]))
        XCTAssertThrowsError(try streamed.append(Data([4, 5]))) { error in
            XCTAssertEqual(error as? ModelDiscoveryNetworkError, .responseTooLarge)
        }
    }

    func testRedirectDelegateRejectsInsteadOfFollowing() throws {
        let delegate = ModelDiscoveryRedirectDelegate()
        let originalURL = URL(string: "https://api.openai.com/v1/models")!
        let redirectedURL = URL(string: "https://attacker.example/models")!
        let task = URLSession.shared.dataTask(with: originalURL)
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: originalURL,
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": redirectedURL.absoluteString]
            )
        )
        let expectation = expectation(description: "redirect completion")

        delegate.urlSession(
            URLSession.shared,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: redirectedURL)
        ) { request in
            XCTAssertNil(request)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(delegate.rejectedRedirect)
        task.cancel()
    }

    func testURLSessionTransportUsesTheActualHTTPResponseURLAsItsReceipt() throws {
        let responseURL = URL(string: "https://api.openai.com/v1/models")!
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )

        XCTAssertEqual(
            URLSessionModelDiscoveryTransport.responseURL(from: response),
            responseURL
        )
    }

    func testDefaultURLSessionTransportDeclaresCustomPinningUnavailable() {
        XCTAssertEqual(
            URLSessionModelDiscoveryTransport().customDestinationCapability,
            .unavailable
        )
    }
}
