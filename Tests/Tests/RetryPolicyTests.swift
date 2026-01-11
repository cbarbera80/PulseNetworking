import XCTest
@testable import PulseNetworking

final class RetryPolicyTests: XCTestCase {
    func testExponentialBackoffRetryPolicyShouldRetry() {
        let policy = ExponentialBackoffRetryPolicy(maxRetries: 3)

        let timeoutError = URLError(.timedOut)
        XCTAssertTrue(policy.shouldRetry(timeoutError, attempt: 1))
        XCTAssertTrue(policy.shouldRetry(timeoutError, attempt: 2))
        XCTAssertTrue(policy.shouldRetry(timeoutError, attempt: 3))
        XCTAssertFalse(policy.shouldRetry(timeoutError, attempt: 4))
    }

    func testExponentialBackoffRetryNetworkErrors() {
        let policy = ExponentialBackoffRetryPolicy(maxRetries: 3)

        let networkError = URLError(.networkConnectionLost)
        XCTAssertTrue(policy.shouldRetry(networkError, attempt: 1))

        let noInternetError = URLError(.notConnectedToInternet)
        XCTAssertTrue(policy.shouldRetry(noInternetError, attempt: 1))

        let badURLError = URLError(.badURL)
        XCTAssertFalse(policy.shouldRetry(badURLError, attempt: 1))
    }

    func testExponentialBackoffRetryHTTPErrors() {
        let policy = ExponentialBackoffRetryPolicy(
            maxRetries: 3,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504]
        )

        let error500 = NetworkError.httpError(statusCode: 500, data: nil)
        XCTAssertTrue(policy.shouldRetry(error500, attempt: 1))

        let error429 = NetworkError.httpError(statusCode: 429, data: nil)
        XCTAssertTrue(policy.shouldRetry(error429, attempt: 1))

        let error404 = NetworkError.httpError(statusCode: 404, data: nil)
        XCTAssertFalse(policy.shouldRetry(error404, attempt: 1))
    }

    func testExponentialBackoffRetryDelay() {
        let policy = ExponentialBackoffRetryPolicy(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0
        )

        let delay1 = policy.delayBeforeRetry(attempt: 1)
        XCTAssertEqual(delay1, 1.0)

        let delay2 = policy.delayBeforeRetry(attempt: 2)
        XCTAssertEqual(delay2, 2.0)

        let delay3 = policy.delayBeforeRetry(attempt: 3)
        XCTAssertEqual(delay3, 4.0)

        let delay4 = policy.delayBeforeRetry(attempt: 4)
        XCTAssertEqual(delay4, 8.0)
    }

    func testExponentialBackoffRetryMaxDelay() {
        let policy = ExponentialBackoffRetryPolicy(
            initialDelay: 1.0,
            maxDelay: 10.0,
            multiplier: 2.0
        )

        let delay5 = policy.delayBeforeRetry(attempt: 5)
        XCTAssertLessThanOrEqual(delay5, 10.0)
    }

    func testSimpleRetryPolicyShouldRetry() {
        let policy = SimpleRetryPolicy(maxRetries: 3)

        let timeoutError = URLError(.timedOut)
        XCTAssertTrue(policy.shouldRetry(timeoutError, attempt: 1))
        XCTAssertTrue(policy.shouldRetry(timeoutError, attempt: 3))
        XCTAssertFalse(policy.shouldRetry(timeoutError, attempt: 4))
    }

    func testSimpleRetryPolicyDelay() {
        let policy = SimpleRetryPolicy(maxRetries: 3, delayInterval: 2.5)

        XCTAssertEqual(policy.delayBeforeRetry(attempt: 1), 2.5)
        XCTAssertEqual(policy.delayBeforeRetry(attempt: 2), 2.5)
        XCTAssertEqual(policy.delayBeforeRetry(attempt: 100), 2.5)
    }

    func testSimpleRetryPolicyDoesNotRetryHTTPErrors() {
        let policy = SimpleRetryPolicy(maxRetries: 3)

        let httpError = NetworkError.httpError(statusCode: 500, data: nil)
        XCTAssertFalse(policy.shouldRetry(httpError, attempt: 1))
    }

    func testNoRetryPolicyNeverRetries() {
        let policy = NoRetryPolicy()

        let timeoutError = URLError(.timedOut)
        XCTAssertFalse(policy.shouldRetry(timeoutError, attempt: 1))

        let httpError = NetworkError.httpError(statusCode: 500, data: nil)
        XCTAssertFalse(policy.shouldRetry(httpError, attempt: 1))
    }

    func testNoRetryPolicyZeroDelay() {
        let policy = NoRetryPolicy()

        XCTAssertEqual(policy.delayBeforeRetry(attempt: 1), 0)
        XCTAssertEqual(policy.delayBeforeRetry(attempt: 100), 0)
    }

    func testCustomRetryableStatusCodes() {
        let policy = ExponentialBackoffRetryPolicy(
            retryableStatusCodes: [429, 503]
        )

        let error429 = NetworkError.httpError(statusCode: 429, data: nil)
        XCTAssertTrue(policy.shouldRetry(error429, attempt: 1))

        let error503 = NetworkError.httpError(statusCode: 503, data: nil)
        XCTAssertTrue(policy.shouldRetry(error503, attempt: 1))

        let error500 = NetworkError.httpError(statusCode: 500, data: nil)
        XCTAssertFalse(policy.shouldRetry(error500, attempt: 1))
    }
}
