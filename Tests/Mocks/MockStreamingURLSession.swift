import Foundation
@testable import PulseNetworking

class MockStreamingURLSession: NSObject, URLSessionStreamingProtocol, @unchecked Sendable {
    var response: URLResponse?
    var error: Error?
    var lastRequest: URLRequest?
    var callCount = 0

    /// Pre-built lines to emit, in order, ending the stream normally after the last one.
    var linesToEmit: [String] = []

    /// If set, overrides linesToEmit entirely and drives the stream manually
    /// (useful for simulating mid-stream errors or specific timing).
    var linesHandler: ((URLRequest) async throws -> (AsyncThrowingStream<String, Error>, URLResponse))?

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, Error>, URLResponse) {
        lastRequest = request
        callCount += 1

        if let handler = linesHandler {
            return try await handler(request)
        }

        if let error = error {
            throw error
        }

        guard let response = response else {
            throw NetworkError.noData
        }

        let lines = linesToEmit
        let stream = AsyncThrowingStream<String, Error> { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
        return (stream, response)
    }

    func reset() {
        response = nil
        error = nil
        lastRequest = nil
        callCount = 0
        linesToEmit = []
        linesHandler = nil
    }
}
