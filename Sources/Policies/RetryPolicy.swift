import Foundation

/// Protocol defining the behavior for retrying failed network requests.
///
/// Implement this protocol to define custom retry behavior, such as determining
/// which errors should trigger a retry and how long to wait between attempts.
public protocol RetryPolicy: Sendable {
    /// Determines whether a request should be retried after a failure.
    ///
    /// - Parameters:
    ///   - error: The error that caused the request to fail
    ///   - attempt: The current attempt number (1-based)
    /// - Returns: true if the request should be retried, false otherwise
    func shouldRetry(_ error: Error, attempt: Int) -> Bool

    /// Calculates the delay before the next retry attempt.
    ///
    /// - Parameter attempt: The current attempt number (1-based)
    /// - Returns: The number of seconds to wait before retrying
    func delayBeforeRetry(attempt: Int) -> TimeInterval
}

/// A retry policy that uses exponential backoff with configurable parameters.
///
/// This policy automatically retries requests on network timeouts and specific HTTP error codes.
/// The delay between retries increases exponentially: `initialDelay * (multiplier ^ (attempt - 1))`,
/// capped at `maxDelay`.
///
/// By default, it retries on:
/// - Network timeouts
/// - Network connection lost
/// - Not connected to internet
/// - HTTP 408 (Request Timeout)
/// - HTTP 429 (Too Many Requests)
/// - HTTP 500 (Internal Server Error)
/// - HTTP 502 (Bad Gateway)
/// - HTTP 503 (Service Unavailable)
/// - HTTP 504 (Gateway Timeout)
///
/// Example:
/// ```swift
/// let policy = ExponentialBackoffRetryPolicy(
///     maxRetries: 3,
///     initialDelay: 1.0,
///     maxDelay: 30.0
/// )
/// ```
public final class ExponentialBackoffRetryPolicy: RetryPolicy, Sendable {
    /// Maximum number of retry attempts allowed.
    private let maxRetries: Int

    /// Initial delay in seconds before the first retry.
    private let initialDelay: TimeInterval

    /// Maximum delay in seconds between retries.
    private let maxDelay: TimeInterval

    /// Multiplier for exponential backoff calculation.
    private let multiplier: Double

    /// HTTP status codes that should trigger a retry.
    private let retryableStatusCodes: Set<Int>

    /// Initializes an exponential backoff retry policy.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (defaults to 3)
    ///   - initialDelay: Initial delay in seconds (defaults to 1.0)
    ///   - maxDelay: Maximum delay in seconds (defaults to 30.0)
    ///   - multiplier: Exponential multiplier (defaults to 2.0)
    ///   - retryableStatusCodes: HTTP codes to retry on (defaults to [408, 429, 500, 502, 503, 504])
    public init(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        multiplier: Double = 2.0,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.retryableStatusCodes = retryableStatusCodes
    }

    /// Determines if a request should be retried based on the error and attempt count.
    ///
    /// - Parameters:
    ///   - error: The error that caused the failure
    ///   - attempt: The current attempt number
    /// - Returns: true if retryable and attempts remain, false otherwise
    public func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        guard attempt <= maxRetries else { return false }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        if let networkError = error as? NetworkError {
            if case .httpError(let statusCode, _) = networkError {
                return retryableStatusCodes.contains(statusCode)
            }
        }

        return false
    }

    /// Calculates the exponential backoff delay for the given attempt.
    ///
    /// - Parameter attempt: The current attempt number
    /// - Returns: The delay in seconds, capped at maxDelay
    public func delayBeforeRetry(attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(multiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }
}

/// A retry policy that uses a fixed delay between retry attempts.
///
/// This policy retries on network timeouts and connection failures with a constant
/// delay between attempts. Useful for simple retry scenarios where exponential backoff
/// is not necessary.
///
/// Example:
/// ```swift
/// let policy = SimpleRetryPolicy(maxRetries: 3, delayInterval: 2.0)
/// ```
public final class SimpleRetryPolicy: RetryPolicy, Sendable {
    /// Maximum number of retry attempts allowed.
    private let maxRetries: Int

    /// Fixed delay in seconds between retry attempts.
    private let delayInterval: TimeInterval

    /// Initializes a simple retry policy with fixed delays.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (defaults to 3)
    ///   - delayInterval: Fixed delay between retries in seconds (defaults to 1.0)
    public init(maxRetries: Int = 3, delayInterval: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.delayInterval = delayInterval
    }

    /// Determines if a request should be retried based on the error.
    ///
    /// Retries only on network timeouts and connection failures.
    ///
    /// - Parameters:
    ///   - error: The error that caused the failure
    ///   - attempt: The current attempt number
    /// - Returns: true if retryable and attempts remain, false otherwise
    public func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        guard attempt <= maxRetries else { return false }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost:
                return true
            default:
                return false
            }
        }

        return false
    }

    /// Returns the fixed delay before the next retry.
    ///
    /// - Parameter attempt: The current attempt number (unused)
    /// - Returns: The fixed delay interval in seconds
    public func delayBeforeRetry(attempt: Int) -> TimeInterval {
        delayInterval
    }
}

/// A retry policy that never retries failed requests.
///
/// This policy disables automatic retries entirely, suitable when you want to handle
/// retries manually or don't want any automatic retry behavior.
public final class NoRetryPolicy: RetryPolicy, Sendable {
    /// Initializes a no-retry policy.
    public init() {}

    /// Never retries any request.
    ///
    /// - Parameters:
    ///   - error: The error (unused)
    ///   - attempt: The current attempt number (unused)
    /// - Returns: Always false
    public func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        false
    }

    /// Returns zero delay since no retry occurs.
    ///
    /// - Parameter attempt: The current attempt number (unused)
    /// - Returns: Always 0
    public func delayBeforeRetry(attempt: Int) -> TimeInterval {
        0
    }
}
