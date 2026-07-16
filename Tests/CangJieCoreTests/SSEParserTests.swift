import XCTest
@testable import CangJieCore

final class SSEParserTests: XCTestCase {
    func testParsesMultilineDataAndMetadata() throws {
        let events = try SSEParser().parse(
            lines: ["event: delta", "id: 7", "retry: 1500", "data: \u{4F60}", "data: \u{597D}", ""]
        )
        XCTAssertEqual(
            events,
            [
                ServerSentEvent(
                    event: "delta",
                    data: "\u{4F60}\n\u{597D}",
                    id: "7",
                    retryMilliseconds: 1500
                )
            ]
        )
    }

    func testIgnoresKeepAliveCommentsAndUnknownFields() throws {
        let events = try SSEParser().parse(lines: [": keep-alive", "unknown: ignored", "data: ok", ""])
        XCTAssertEqual(events.map(\.data), ["ok"])
    }

    func testDiscardsUnterminatedEventAtEOF() throws {
        XCTAssertEqual(try SSEParser().parse(lines: ["data: [DONE]"]), [])
    }

    func testLastEventIDPersistsAcrossEvents() throws {
        let events = try SSEParser().parse(lines: ["id: 9", "", "data: first", "", "data: second", ""])
        XCTAssertEqual(events.map(\.id), ["9", "9"])
    }

    func testInvalidRetryDoesNotErasePreviousValidRetry() throws {
        let events = try SSEParser().parse(
            lines: ["retry: 1000", "data: first", "", "retry: -1", "data: second", ""]
        )
        XCTAssertEqual(events.map(\.retryMilliseconds), [1000, 1000])
    }

    func testByteParserDecodesUTF8OnlyAfterACompleteLine() throws {
        let encodedLine = Array("data: \u{4F60}\u{597D}".utf8)
        let firstMultibyteIndex = Array("data: ".utf8).count
        var parser = SSEByteParser()

        for byte in encodedLine[..<(firstMultibyteIndex + 1)] {
            XCTAssertNil(try parser.consume(byte: byte))
        }
        for byte in encodedLine[(firstMultibyteIndex + 1)...] {
            XCTAssertNil(try parser.consume(byte: byte))
        }

        XCTAssertNil(try parser.consume(byte: 0x0A))
        XCTAssertEqual(
            try parser.consume(byte: 0x0A),
            ServerSentEvent(event: nil, data: "\u{4F60}\u{597D}", id: nil, retryMilliseconds: nil)
        )
    }

    func testByteParserAcceptsLFAndCRLFAtTheRawByteLimit() throws {
        let lineBytes = Array("data: ok".utf8)
        let limits = SSEParserLimits(maximumLineBytes: lineBytes.count)

        for terminator in [[UInt8(0x0A)], [UInt8(0x0D), UInt8(0x0A)]] {
            var parser = SSEByteParser(limits: limits)
            var event: ServerSentEvent?
            for byte in lineBytes + terminator + terminator {
                if let parsed = try parser.consume(byte: byte) {
                    event = parsed
                }
            }
            XCTAssertEqual(event?.data, "ok")
        }
    }

    func testByteParserRejectsAnOversizedLineBeforeNewline() throws {
        let limits = SSEParserLimits(maximumLineBytes: 7)
        var parser = SSEByteParser(limits: limits)
        let bytes = Array("data: \u{00E9}".utf8)

        XCTAssertEqual(bytes.count, 8)
        XCTAssertThrowsError(
            try bytes.forEach { byte in
                _ = try parser.consume(byte: byte)
            }
        ) { error in
            XCTAssertEqual(error as? SSEParserError, .lineTooLong(limit: 7))
        }
    }

    func testByteParserEmitsAnEventAfterAStandaloneCR() throws {
        var parser = SSEByteParser()
        var emitted: [ServerSentEvent] = []

        for byte in Array("data: ok\r\r".utf8) {
            if let event = try parser.consume(byte: byte) {
                emitted.append(event)
            }
        }

        XCTAssertEqual(emitted, [ServerSentEvent(event: nil, data: "ok", id: nil, retryMilliseconds: nil)])
    }
    func testByteParserDoesNotFlushUnterminatedEventAtEOF() throws {
        var parser = SSEByteParser()
        var emittedEvents: [ServerSentEvent] = []

        for byte in Array("data: complete\ndata: partial".utf8) {
            if let event = try parser.consume(byte: byte) {
                emittedEvents.append(event)
            }
        }

        XCTAssertEqual(emittedEvents, [])
    }

    func testContentTypeAcceptsExactEventStreamMediaTypeWithParameters() {
        let accepted: [String?] = [
            "text/event-stream",
            "TEXT/EVENT-STREAM",
            " text/event-stream ; charset=utf-8",
            "text/event-stream;charset=\"utf-8\""
        ]

        for value in accepted {
            XCTAssertTrue(SSEContentType.isEventStream(value), "Expected to accept \(value ?? "nil")")
        }
    }
    func testContentTypeRejectsMalformedParameterLists() {
        let rejected = [
            "text/event-stream;",
            "text/event-stream; charset=utf-8, text/plain"
        ]

        for value in rejected {
            XCTAssertFalse(SSEContentType.isEventStream(value), "Expected to reject \(value)")
        }
    }
    func testContentTypeRejectsMissingOrPrefixSpoofedMediaTypes() {
        let rejected: [String?] = [
            nil,
            "",
            "text/event-streaming",
            "text/event-stream+json",
            "application/text/event-stream",
            "text/event-stream, text/plain"
        ]

        for value in rejected {
            XCTAssertFalse(SSEContentType.isEventStream(value), "Expected to reject \(value ?? "nil")")
        }
    }
}