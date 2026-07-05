import XCTest
@testable import PulseNetworking

final class SSEParserTests: XCTestCase {
    private func linesStream(_ lines: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
    }

    private func collect(_ stream: AsyncThrowingStream<SSEEvent, Error>) async throws -> [SSEEvent] {
        var events: [SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    func testSingleLineDataEvent() async throws {
        let lines = linesStream(["data: {\"a\":1}", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "{\"a\":1}")
    }

    func testMultiLineDataEventJoinsWithNewline() async throws {
        let lines = linesStream(["data: line1", "data: line2", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "line1\nline2")
    }

    func testEventFieldIsParsed() async throws {
        let lines = linesStream(["event: tool_use", "data: {}", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].event, "tool_use")
    }

    func testCommentLinesAreIgnored() async throws {
        let lines = linesStream([": this is a comment", "data: {}", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "{}")
    }

    func testBlankLineIsDispatchBoundary() async throws {
        let lines = linesStream(["data: first", "", "data: second", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].data, "first")
        XCTAssertEqual(events[1].data, "second")
    }

    func testIdFieldPersistsAcrossEvents() async throws {
        let lines = linesStream(["id: abc", "data: first", "", "data: second", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].id, "abc")
        XCTAssertEqual(events[1].id, "abc")
    }

    func testRetryFieldParsedAsInt() async throws {
        let lines = linesStream(["retry: 3000", "data: {}", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].retry, 3000)
    }

    func testUnknownFieldIsIgnored() async throws {
        let lines = linesStream(["foo: bar", "data: {}", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "{}")
    }

    func testEmptyDataLineProducesEmptyStringInData() async throws {
        let lines = linesStream(["data:", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "")
    }

    func testEventWithNoDataFieldIsNotDispatched() async throws {
        let lines = linesStream(["event: ping", "id: 1", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertTrue(events.isEmpty)
    }

    func testEOFWithoutTrailingBlankLineStillFlushesPendingEvent() async throws {
        let lines = linesStream(["data: {}"])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "{}")
    }

    func testMalformedFieldLineWithoutColonUsesEmptyValue() async throws {
        let lines = linesStream(["data", ""])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "")
    }

    func testMissingBlankLineBetweenJSONEventsStillSplitsCorrectly() async throws {
        let lines = linesStream([
            "data: {\"type\":\"tool_use\",\"tool\":\"get_relevant_books\"}",
            "data: {\"message\":{\"id\":\"\",\"content\":\"Ott\"}}",
            "data: {\"message\":{\"id\":\"\",\"content\":\"Ottima\"}}",
            ""
        ])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].data, "{\"type\":\"tool_use\",\"tool\":\"get_relevant_books\"}")
        XCTAssertEqual(events[1].data, "{\"message\":{\"id\":\"\",\"content\":\"Ott\"}}")
        XCTAssertEqual(events[2].data, "{\"message\":{\"id\":\"\",\"content\":\"Ottima\"}}")
    }

    func testMissingBlankLineBetweenJSONArrayEventsStillSplitsCorrectly() async throws {
        let lines = linesStream([
            "data: [1,2,3]",
            "data: [4,5,6]",
            ""
        ])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].data, "[1,2,3]")
        XCTAssertEqual(events[1].data, "[4,5,6]")
    }

    func testGenuineMultiLineJSONContinuationStillJoins() async throws {
        let lines = linesStream([
            "data: {\"a\":1,",
            "data: \"b\":2}",
            ""
        ])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "{\"a\":1,\n\"b\":2}")
    }

    func testNonJSONMultiLineDataStillJoinsRegardlessOfPrefix() async throws {
        let lines = linesStream([
            "data: plain text line one",
            "data: {not really json but looks like it}",
            ""
        ])
        let events = try await collect(SSEParser.parse(lines))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "plain text line one\n{not really json but looks like it}")
    }
}
