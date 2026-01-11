import Foundation

/// Represents all possible errors that can occur during network operations.
///
/// This enum encompasses various error types that may occur during HTTP requests,
/// including network failures, invalid responses, encoding/decoding errors, and cache-related issues.
public enum NetworkError: LocalizedError {
    /// The provided URL is invalid or malformed.
    case invalidURL(String)

    /// A URLError occurred during the request.
    case requestFailed(URLError)

    /// The server response is invalid or cannot be processed.
    case invalidResponse

    /// JSON decoding failed for the response data.
    case decodingFailed(DecodingError)

    /// JSON encoding failed for the request body.
    case encodingFailed(EncodingError)

    /// No data was received from the server.
    case noData

    /// An HTTP error response was received.
    /// - Parameters:
    ///   - statusCode: The HTTP status code (e.g., 404, 500)
    ///   - data: Optional response data that may contain error details
    case httpError(statusCode: Int, data: Data?)

    /// A cache-related error occurred.
    case cacheError(String)

    /// The request failed after exhausting all retry attempts.
    /// - Parameters:
    ///   - error: The original error that caused the failure
    ///   - attempts: The number of retry attempts made
    case retryExhausted(error: Error, attempts: Int)

    /// A custom error with a user-defined message.
    case custom(String)

    /// A localized description of the error suitable for displaying to users.
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .noData:
            return "No data received from server"
        case .httpError(let statusCode, _):
            return "HTTP error \(statusCode)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .retryExhausted(let error, let attempts):
            return "Request failed after \(attempts) attempts: \(error.localizedDescription)"
        case .custom(let message):
            return message
        }
    }
}
