import Foundation

public struct ServerSentEvent: Equatable, Sendable {
    public let event: String?
    public let data: String
    public let id: String?
    public let retryMilliseconds: Int?

    public init(event: String?, data: String, id: String?, retryMilliseconds: Int?) {
        self.event = event
        self.data = data
        self.id = id
        self.retryMilliseconds = retryMilliseconds
    }
}

public enum SSEParserError: Error, Equatable, Sendable {
    case lineTooLong(limit: Int)
    case eventTooLarge(limit: Int)
    case tooManyDataLines(limit: Int)
}

public struct SSEParserLimits: Equatable, Sendable {
    public let maximumLineBytes: Int
    public let maximumEventCharacters: Int
    public let maximumDataLines: Int

    public init(
        maximumLineBytes: Int = 64 * 1_024,
        maximumEventCharacters: Int = 1_024 * 1_024,
        maximumDataLines: Int = 4_096
    ) {
        self.maximumLineBytes = maximumLineBytes
        self.maximumEventCharacters = maximumEventCharacters
        self.maximumDataLines = maximumDataLines
    }

    @available(*, deprecated, message: "Use maximumLineBytes so the limit is enforced before UTF-8 decoding.")
    public init(
        maximumLineCharacters: Int,
        maximumEventCharacters: Int = 1_024 * 1_024,
        maximumDataLines: Int = 4_096
    ) {
        self.init(
            maximumLineBytes: maximumLineCharacters,
            maximumEventCharacters: maximumEventCharacters,
            maximumDataLines: maximumDataLines
        )
    }

    @available(*, deprecated, message: "Use maximumLineBytes.")
    public var maximumLineCharacters: Int { maximumLineBytes }
}

public struct SSEParserState: Equatable, Sendable {
    private let eventName: String?
    private let dataLines: [String]
    private let dataCharacterCount: Int
    private let eventID: String?
    private let retryMilliseconds: Int?
    private let limits: SSEParserLimits

    public init(limits: SSEParserLimits = .init()) {
        self.init(
            eventName: nil,
            dataLines: [],
            dataCharacterCount: 0,
            eventID: nil,
            retryMilliseconds: nil,
            limits: limits
        )
    }

    private init(
        eventName: String?,
        dataLines: [String],
        dataCharacterCount: Int,
        eventID: String?,
        retryMilliseconds: Int?,
        limits: SSEParserLimits
    ) {
        self.eventName = eventName
        self.dataLines = dataLines
        self.dataCharacterCount = dataCharacterCount
        self.eventID = eventID
        self.retryMilliseconds = retryMilliseconds
        self.limits = limits
    }

    public func consuming(line: String) throws -> (state: SSEParserState, event: ServerSentEvent?) {
        guard line.utf8.count <= limits.maximumLineBytes else {
            throw SSEParserError.lineTooLong(limit: limits.maximumLineBytes)
        }
        return try consumingValidatedLine(line)
    }

    fileprivate func consumingValidatedLine(
        _ line: String
    ) throws -> (state: SSEParserState, event: ServerSentEvent?) {
        if line.isEmpty {
            let next = SSEParserState(
                eventName: nil,
                dataLines: [],
                dataCharacterCount: 0,
                eventID: eventID,
                retryMilliseconds: retryMilliseconds,
                limits: limits
            )
            guard !dataLines.isEmpty else { return (next, nil) }
            return (
                next,
                ServerSentEvent(
                    event: eventName,
                    data: dataLines.joined(separator: "\n"),
                    id: eventID,
                    retryMilliseconds: retryMilliseconds
                )
            )
        }
        if line.hasPrefix(":") { return (self, nil) }

        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let field = String(parts[0])
        var value = parts.count == 2 ? String(parts[1]) : ""
        if value.hasPrefix(" ") { value.removeFirst() }

        switch field {
        case "event":
            return (updated(eventName: value), nil)
        case "data":
            guard dataLines.count < limits.maximumDataLines else {
                throw SSEParserError.tooManyDataLines(limit: limits.maximumDataLines)
            }
            let addedCharacterCount = (dataLines.isEmpty ? 0 : 1) + value.count
            guard dataCharacterCount <= limits.maximumEventCharacters,
                  addedCharacterCount <= limits.maximumEventCharacters - dataCharacterCount else {
                throw SSEParserError.eventTooLarge(limit: limits.maximumEventCharacters)
            }
            return (
                updated(
                    dataLines: dataLines + [value],
                    dataCharacterCount: dataCharacterCount + addedCharacterCount
                ),
                nil
            )
        case "id":
            guard !value.contains("\0") else { return (self, nil) }
            return (updated(eventID: value), nil)
        case "retry":
            guard let retry = Int(value), retry >= 0 else { return (self, nil) }
            return (updated(retryMilliseconds: retry), nil)
        default:
            return (self, nil)
        }
    }

    private func updated(
        eventName: String? = nil,
        dataLines: [String]? = nil,
        dataCharacterCount: Int? = nil,
        eventID: String? = nil,
        retryMilliseconds: Int? = nil
    ) -> SSEParserState {
        SSEParserState(
            eventName: eventName ?? self.eventName,
            dataLines: dataLines ?? self.dataLines,
            dataCharacterCount: dataCharacterCount ?? self.dataCharacterCount,
            eventID: eventID ?? self.eventID,
            retryMilliseconds: retryMilliseconds ?? self.retryMilliseconds,
            limits: limits
        )
    }
}

public struct SSEByteParser: Sendable {
    private let limits: SSEParserLimits
    private var parserState: SSEParserState
    private var lineBytes: [UInt8]
    private var skipsNextLineFeed: Bool

    public init(limits: SSEParserLimits = .init()) {
        self.limits = limits
        self.parserState = SSEParserState(limits: limits)
        self.lineBytes = []
        self.lineBytes.reserveCapacity(min(max(limits.maximumLineBytes, 0), 4 * 1_024))
        self.skipsNextLineFeed = false
    }

    public mutating func consume(byte: UInt8) throws -> ServerSentEvent? {
        if skipsNextLineFeed {
            skipsNextLineFeed = false
            if byte == 0x0A {
                return nil
            }
        }

        if byte == 0x0D {
            skipsNextLineFeed = true
            return try consumeCompletedLine()
        }
        if byte == 0x0A {
            return try consumeCompletedLine()
        }

        try appendLineByte(byte)
        return nil
    }

    private mutating func appendLineByte(_ byte: UInt8) throws {
        guard lineBytes.count < limits.maximumLineBytes else {
            throw SSEParserError.lineTooLong(limit: limits.maximumLineBytes)
        }
        lineBytes.append(byte)
    }

    private mutating func consumeCompletedLine() throws -> ServerSentEvent? {
        let line = String(decoding: lineBytes, as: UTF8.self)
        lineBytes.removeAll(keepingCapacity: true)
        let output = try parserState.consumingValidatedLine(line)
        parserState = output.state
        return output.event
    }
}
public enum SSEContentType {
    public static func isEventStream(_ value: String?) -> Bool {
        guard let value,
              !value.isEmpty,
              !value.contains("\r"),
              !value.contains("\n") else {
            return false
        }

        let sections = value.split(separator: ";", omittingEmptySubsequences: false)
        let mainMediaType = sections[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard mainMediaType.lowercased() == "text/event-stream" else {
            return false
        }

        for parameter in sections.dropFirst() {
            let trimmedParameter = parameter.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedParameter.isEmpty,
                  trimmedParameter.contains("="),
                  !trimmedParameter.contains(",") else {
                return false
            }
        }
        return true
    }
}
public struct SSEParser: Sendable {
    private let limits: SSEParserLimits

    public init(limits: SSEParserLimits = .init()) {
        self.limits = limits
    }

    public func parse(lines: [String]) throws -> [ServerSentEvent] {
        var state = SSEParserState(limits: limits)
        var events: [ServerSentEvent] = []
        for line in lines {
            let output = try state.consuming(line: line)
            state = output.state
            if let event = output.event { events.append(event) }
        }
        return events
    }

    public func parse(bytes: [UInt8]) throws -> [ServerSentEvent] {
        var parser = SSEByteParser(limits: limits)
        var events: [ServerSentEvent] = []
        for byte in bytes {
            if let event = try parser.consume(byte: byte) {
                events.append(event)
            }
        }
        return events
    }
}