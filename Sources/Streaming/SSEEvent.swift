import Foundation

/// A single parsed Server-Sent Event, prior to JSON decoding of its data field.
///
/// Mirrors the fields defined by the SSE spec. `data` already has any
/// multi-line `data:` fields joined with "\n".
struct SSEEvent: Sendable {
    var event: String?
    var data: String?
    var id: String?
    var retry: Int?
}

/// Parses a raw line stream (as produced by `URLSessionStreamingProtocol.lines(for:)`)
/// into a stream of SSE events, following the Server-Sent Events line-processing algorithm.
///
/// Deviates from the strict spec in two ways, both aimed at real-world servers whose
/// framing is slightly off:
/// - If the line stream ends (EOF) without a final blank line but with a pending `data`
///   buffer, that event is still flushed before closing. Real SSE servers often close the
///   connection right after the last event without sending the terminating blank line.
/// - If a new `data:` line arrives while the pending buffer already holds a complete,
///   valid JSON value, and the new line itself starts a new JSON object/array (`{`/`[`),
///   the pending event is flushed before the new line is buffered. Some servers drop the
///   blank line between consecutive events entirely (not just at EOF), which would
///   otherwise silently merge two JSON payloads into one invalid blob. This only fires
///   when the accumulated buffer already parses as standalone JSON, so genuine multi-line
///   `data:` continuations (where the buffer isn't valid JSON until later lines arrive)
///   are unaffected.
enum SSEParser {
    static func parse(_ lines: AsyncThrowingStream<String, Error>) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var pendingEvent: String?
                var pendingDataLines: [String] = []
                var pendingId: String?
                var pendingRetry: Int?

                func flushIfNeeded() {
                    guard !pendingDataLines.isEmpty else {
                        pendingEvent = nil
                        pendingRetry = nil
                        return
                    }
                    let joined = pendingDataLines.joined(separator: "\n")
                    continuation.yield(SSEEvent(event: pendingEvent, data: joined, id: pendingId, retry: pendingRetry))
                    pendingEvent = nil
                    pendingDataLines = []
                    pendingRetry = nil
                }

                do {
                    for try await rawLine in lines {
                        if rawLine.isEmpty {
                            flushIfNeeded()
                            continue
                        }
                        if rawLine.hasPrefix(":") {
                            continue
                        }
                        let (field, value) = SSEParser.splitField(rawLine)
                        switch field {
                        case "event":
                            pendingEvent = value
                        case "data":
                            if !pendingDataLines.isEmpty,
                               SSEParser.looksLikeNewJSONValue(value),
                               SSEParser.isCompleteJSON(pendingDataLines.joined(separator: "\n")) {
                                flushIfNeeded()
                            }
                            pendingDataLines.append(value)
                        case "id":
                            pendingId = value
                        case "retry":
                            pendingRetry = Int(value)
                        default:
                            break
                        }
                    }
                    flushIfNeeded()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func splitField(_ line: String) -> (String, String) {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return (line, "")
        }
        let field = String(line[line.startIndex..<colonIndex])
        var value = String(line[line.index(after: colonIndex)...])
        if value.hasPrefix(" ") {
            value.removeFirst()
        }
        return (field, value)
    }

    private static func looksLikeNewJSONValue(_ value: String) -> Bool {
        value.hasPrefix("{") || value.hasPrefix("[")
    }

    private static func isCompleteJSON(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }
}
