import XCTest
@testable import PulseNetworking

final class NetworkClientBuilderTests: XCTestCase {
    let testURL = URL(string: "https://api.example.com")!

    func testBuilderBasic() {
        let builder = NetworkClientBuilder()
        let client = builder.build()

        XCTAssertNotNil(client)
    }

    func testBuilderWithBaseURL() {
        let builder = NetworkClientBuilder()
            .withBaseURL(testURL)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithBaseURLString() {
        let builder = NetworkClientBuilder()
            .withBaseURL("https://api.example.com")

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithSession() {
        let customSession = URLSession(configuration: .default)
        let builder = NetworkClientBuilder()
            .withSession(customSession)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithInterceptor() {
        let interceptor = LoggingInterceptor()
        let builder = NetworkClientBuilder()
            .withInterceptor(interceptor)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithMultipleInterceptors() {
        let auth = AuthInterceptor { "token" }
        let logging = LoggingInterceptor()
        let builder = NetworkClientBuilder()
            .withInterceptor(auth)
            .withInterceptor(logging)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithInterceptorsArray() {
        let auth = AuthInterceptor { "token" }
        let logging = LoggingInterceptor()
        let builder = NetworkClientBuilder()
            .withInterceptors([auth, logging])

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithRetryPolicy() {
        let policy = SimpleRetryPolicy(maxRetries: 3)
        let builder = NetworkClientBuilder()
            .withRetryPolicy(policy)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithExponentialBackoffRetry() {
        let builder = NetworkClientBuilder()
            .withExponentialBackoffRetry(maxRetries: 5, initialDelay: 2.0, maxDelay: 60.0)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithExponentialBackoffRetryDefaults() {
        let builder = NetworkClientBuilder()
            .withExponentialBackoffRetry()

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithSimpleRetry() {
        let builder = NetworkClientBuilder()
            .withSimpleRetry(maxRetries: 3, delayInterval: 1.5)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithSimpleRetryDefaults() {
        let builder = NetworkClientBuilder()
            .withSimpleRetry()

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithCache() {
        let builder = NetworkClientBuilder()
            .withCache(enabled: true, duration: 300)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithCacheDisabled() {
        let builder = NetworkClientBuilder()
            .withCache(enabled: false)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithCustomCache() {
        let customCache = InMemoryNetworkCache()
        let builder = NetworkClientBuilder()
            .withCustomCache(customCache, enabled: true)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderChaining() {
        let builder = NetworkClientBuilder()
            .withBaseURL(testURL)
            .withInterceptor(LoggingInterceptor())
            .withExponentialBackoffRetry(maxRetries: 3)
            .withCache(enabled: true)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderWithAllOptions() {
        let auth = AuthInterceptor { "token" }
        let customHeaders = CustomHeaderInterceptor(headers: ["X-ID": "123"])
        let cache = InMemoryNetworkCache()

        let builder = NetworkClientBuilder()
            .withBaseURL(testURL)
            .withSession(URLSession.shared)
            .withInterceptors([auth, customHeaders])
            .withExponentialBackoffRetry(maxRetries: 3, initialDelay: 1.0)
            .withCustomCache(cache, enabled: true)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderReturnsSelf() {
        let builder = NetworkClientBuilder()
        let result = builder.withBaseURL(testURL)

        XCTAssertTrue(result === builder)
    }

    func testBuilderMultipleCallsToWithCache() {
        let builder = NetworkClientBuilder()
            .withCache(enabled: true, duration: 100)
            .withCache(enabled: false, duration: 200)

        let client = builder.build()
        XCTAssertNotNil(client)
    }

    func testBuilderDefaultSession() {
        let builder = NetworkClientBuilder()
            .withBaseURL(testURL)

        let client = builder.build()
        XCTAssertNotNil(client)
    }
}
