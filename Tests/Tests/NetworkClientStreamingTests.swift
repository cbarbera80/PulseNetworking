import XCTest
@testable import PulseNetworking

final class NetworkClientStreamingTests: XCTestCase {
    let baseURL = URL(string: "https://api.example.com")!

    func testStreamYieldsDecodedEvents() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesToEmit = [
            "data: {\"id\":1}", "",
            "data: {\"id\":2}", ""
        ]

        let client = NetworkClient(baseURL: baseURL, streamingSession: mockStreamingSession)
        let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream("/events")

        var results: [Int] = []
        for try await item in stream {
            results.append(item.id)
        }

        XCTAssertEqual(results, [1, 2])
    }

    func testStreamAppliesInterceptorsOnce() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesToEmit = ["data: {\"id\":1}", ""]

        let interceptor = CustomHeaderInterceptor(headers: ["X-ID": "123"])
        let client = NetworkClient(
            baseURL: baseURL,
            streamingSession: mockStreamingSession,
            interceptors: [interceptor]
        )

        let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream("/events")
        for try await _ in stream {}

        XCTAssertEqual(mockStreamingSession.lastRequest?.value(forHTTPHeaderField: "X-ID"), "123")
        XCTAssertEqual(mockStreamingSession.callCount, 1)
    }

    func testStreamValidatesInitialHTTPStatus() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 500)
        mockStreamingSession.linesToEmit = []

        let client = NetworkClient(baseURL: baseURL, streamingSession: mockStreamingSession)

        do {
            let _: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream("/events")
            XCTFail("Should have thrown")
        } catch NetworkError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 500)
        }
    }

    func testStreamDoesNotUseCacheEvenWhenEnabled() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesToEmit = ["data: {\"id\":1}", ""]

        let client = NetworkClient(
            baseURL: baseURL,
            streamingSession: mockStreamingSession,
            cache: InMemoryNetworkCache(),
            cacheEnabled: true
        )

        for _ in 0..<2 {
            let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream("/events")
            for try await _ in stream {}
        }

        XCTAssertEqual(mockStreamingSession.callCount, 2)
    }

    func testStreamDoesNotRetryOnMidStreamError() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        let response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesHandler = { _ in
            let stream = AsyncThrowingStream<String, Error> { continuation in
                continuation.yield("data: {\"id\":1}")
                continuation.yield("")
                continuation.finish(throwing: URLError(.networkConnectionLost))
            }
            return (stream, response)
        }

        let client = NetworkClient(
            baseURL: baseURL,
            streamingSession: mockStreamingSession,
            retryPolicy: SimpleRetryPolicy(maxRetries: 3, delayInterval: 0.01)
        )

        let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream("/events")

        var results: [Int] = []
        do {
            for try await item in stream {
                results.append(item.id)
            }
            XCTFail("Should have thrown")
        } catch is URLError {
            // Expected
        }

        XCTAssertEqual(results, [1])
        XCTAssertEqual(mockStreamingSession.callCount, 1)
    }

    func testStreamPropagatesDecodingErrorForMalformedEvent() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesToEmit = ["data: not json", ""]

        let client = NetworkClient(baseURL: baseURL, streamingSession: mockStreamingSession)
        let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream("/events")

        do {
            for try await _ in stream {}
            XCTFail("Should have thrown")
        } catch is DecodingError {
            // Expected
        }
    }

    func testStreamSkipsEventsWithoutDataField() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesToEmit = [
            "data: {\"id\":1}", "",
            "event: ping", "",
            "data: {\"id\":2}", ""
        ]

        let client = NetworkClient(baseURL: baseURL, streamingSession: mockStreamingSession)
        let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream("/events")

        var results: [Int] = []
        for try await item in stream {
            results.append(item.id)
        }

        XCTAssertEqual(results, [1, 2])
    }

    func testStreamRespectsCustomDecoder() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesToEmit = ["data: {\"item_id\":42}", ""]

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let client = NetworkClient(baseURL: baseURL, streamingSession: mockStreamingSession, decoder: decoder)
        let stream: AsyncThrowingStream<MockSnakeCaseStreamItem, Error> = try await client.stream("/events")

        var results: [Int] = []
        for try await item in stream {
            results.append(item.itemId)
        }

        XCTAssertEqual(results, [42])
    }

    func testStreamBuildsGETRequestWithEventStreamAcceptHeader() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesToEmit = ["data: {\"id\":1}", ""]

        let client = NetworkClient(baseURL: baseURL, streamingSession: mockStreamingSession)
        let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream("/events")
        for try await _ in stream {}

        XCTAssertEqual(mockStreamingSession.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(mockStreamingSession.lastRequest?.value(forHTTPHeaderField: "Accept"), "text/event-stream")
    }

    func testStreamHeadersPassthrough() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesToEmit = ["data: {\"id\":1}", ""]

        let client = NetworkClient(baseURL: baseURL, streamingSession: mockStreamingSession)
        let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream(
            "/events",
            headers: ["Accept-Language": "it"]
        )
        for try await _ in stream {}

        XCTAssertEqual(mockStreamingSession.lastRequest?.value(forHTTPHeaderField: "Accept-Language"), "it")
    }

    func testStreamQueryItemsBuildURLCorrectly() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        mockStreamingSession.response = mockHTTPResponse(statusCode: 200)
        mockStreamingSession.linesToEmit = ["data: {\"id\":1}", ""]

        let client = NetworkClient(baseURL: baseURL, streamingSession: mockStreamingSession)
        let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream(
            "/events",
            queryItems: [URLQueryItem(name: "q", value: "hello"), URLQueryItem(name: "format", value: "md")]
        )
        for try await _ in stream {}

        let url = mockStreamingSession.lastRequest?.url
        XCTAssertEqual(url?.path, "/events")
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "q" })?.value, "hello")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "format" })?.value, "md")
    }

    func testStreamCancellationStopsUnderlyingConnection() async throws {
        let mockStreamingSession = MockStreamingURLSession()
        let response = mockHTTPResponse(statusCode: 200)
        let terminationFlag = TerminationFlag()

        mockStreamingSession.linesHandler = { _ in
            let stream = AsyncThrowingStream<String, Error> { continuation in
                let producer = Task {
                    while !Task.isCancelled {
                        continuation.yield("data: {\"id\":1}")
                        continuation.yield("")
                        try? await Task.sleep(nanoseconds: 5_000_000)
                    }
                }
                continuation.onTermination = { _ in
                    producer.cancel()
                    Task { await terminationFlag.markTerminated() }
                }
            }
            return (stream, response)
        }

        let client = NetworkClient(baseURL: baseURL, streamingSession: mockStreamingSession)
        let stream: AsyncThrowingStream<MockStreamItem, Error> = try await client.stream("/events")

        let consumerTask = Task {
            for try await _ in stream {
                await terminationFlag.markReceivedFirstItem()
            }
        }

        await terminationFlag.waitForFirstItem()
        consumerTask.cancel()

        let didTerminate = await terminationFlag.waitForTermination()
        XCTAssertTrue(didTerminate)
    }
}

actor TerminationFlag {
    private var terminated = false
    private var receivedFirstItem = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func markTerminated() {
        terminated = true
    }

    func markReceivedFirstItem() {
        guard !receivedFirstItem else { return }
        receivedFirstItem = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }

    func waitForFirstItem() async {
        if receivedFirstItem { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForTermination() async -> Bool {
        for _ in 0..<50 {
            if terminated { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return terminated
    }
}

struct MockStreamItem: Decodable, Sendable {
    let id: Int
}

struct MockSnakeCaseStreamItem: Decodable, Sendable {
    let itemId: Int
}
