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
/// Deviates from the strict spec in one way: if the line stream ends (EOF) without a
/// final blank line but with a pending `data` buffer, that event is still flushed before
/// closing. Real SSE servers often close the connection right after the last event
/// without sending the terminating blank line.
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
}
