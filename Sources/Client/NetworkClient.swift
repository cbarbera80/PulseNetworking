import Foundation

/// Protocol for URLSession abstraction to enable testing and custom implementations.
///
/// This protocol allows the NetworkClient to work with any object that can perform
/// URL data requests, not just URLSession.
public protocol URLSessionProtocol: Sendable {
    /// Performs a data request.
    ///
    /// - Parameter request: The URLRequest to execute
    /// - Returns: A tuple containing the response data and URLResponse
    /// - Throws: Any error that occurs during the request
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

/// The main HTTP client for making network requests with async/await support.
///
/// `NetworkClient` provides a high-level interface for making HTTP requests with features like:
/// - Automatic request/response handling with JSON encoding/decoding
/// - Request interceptors for custom logic (auth, logging, headers)
/// - Automatic retry with configurable backoff strategies
/// - Response caching with TTL support
/// - Support for all standard HTTP methods
///
/// Use `NetworkClientBuilder` to create an instance with desired configuration.
///
/// Example:
/// ```swift
/// let client = NetworkClientBuilder()
///     .withBaseURL("https://api.example.com")
///     .withInterceptor(AuthInterceptor { await getToken() })
///     .withExponentialBackoffRetry(maxRetries: 3)
///     .build()
///
/// let user: User = try await client.get("/users/123")
/// ```
public class NetworkClient: @unchecked Sendable {
    /// The base URL for all requests (optional).
    private let baseURL: URL?

    /// The URLSession used for network requests.
    private let session: URLSessionProtocol

    /// Array of interceptors to apply to requests in order.
    private let interceptors: [NetworkInterceptor]

    /// Policy for retrying failed requests.
    private let retryPolicy: RetryPolicy

    /// Cache for storing responses.
    private let cache: NetworkCacheProtocol

    /// Whether caching is enabled.
    private let cacheEnabled: Bool

    /// How long cached responses remain valid in seconds.
    private let cacheDuration: TimeInterval

    /// Initializes a NetworkClient with the specified configuration.
    ///
    /// - Parameters:
    ///   - baseURL: Optional base URL for all requests
    ///   - session: URLSession or compatible object (defaults to URLSession.shared)
    ///   - interceptors: Array of request interceptors
    ///   - retryPolicy: Policy for retrying failed requests
    ///   - cache: Cache implementation
    ///   - cacheEnabled: Whether to use the cache
    ///   - cacheDuration: Cache expiration time in seconds
    init(
        baseURL: URL?,
        session: URLSessionProtocol = URLSession.shared,
        interceptors: [NetworkInterceptor] = [],
        retryPolicy: RetryPolicy = NoRetryPolicy(),
        cache: NetworkCacheProtocol = NoNetworkCache(),
        cacheEnabled: Bool = false,
        cacheDuration: TimeInterval = 300
    ) {
        self.baseURL = baseURL
        self.session = session
        self.interceptors = interceptors
        self.retryPolicy = retryPolicy
        self.cache = cache
        self.cacheEnabled = cacheEnabled
        self.cacheDuration = cacheDuration
    }

    /// Performs a GET request and decodes the response.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - headers: Optional custom headers
    /// - Returns: The decoded response object
    /// - Throws: NetworkError or DecodingError
    public func get<T: Decodable>(
        _ path: String,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = buildURL(path)
        let request = NetworkRequest(url: url, method: .get, headers: headers)
        return try await execute(request)
    }

    /// Performs a POST request with an encoded body and decodes the response.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - body: The request body to encode as JSON
    ///   - headers: Optional custom headers
    /// - Returns: The decoded response object
    /// - Throws: NetworkError, EncodingError, or DecodingError
    public func post<T: Decodable>(
        _ path: String,
        body: Encodable,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = buildURL(path)
        let bodyData = try JSONEncoder().encode(body)
        var request = NetworkRequest(url: url, method: .post, headers: headers, body: bodyData)
        if request.headers["Content-Type"] == nil {
            request.headers["Content-Type"] = "application/json"
        }
        return try await execute(request)
    }

    /// Performs a PUT request with an encoded body and decodes the response.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - body: The request body to encode as JSON
    ///   - headers: Optional custom headers
    /// - Returns: The decoded response object
    /// - Throws: NetworkError, EncodingError, or DecodingError
    public func put<T: Decodable>(
        _ path: String,
        body: Encodable,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = buildURL(path)
        let bodyData = try JSONEncoder().encode(body)
        var request = NetworkRequest(url: url, method: .put, headers: headers, body: bodyData)
        if request.headers["Content-Type"] == nil {
            request.headers["Content-Type"] = "application/json"
        }
        return try await execute(request)
    }

    /// Performs a PATCH request with an encoded body and decodes the response.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - body: The request body to encode as JSON
    ///   - headers: Optional custom headers
    /// - Returns: The decoded response object
    /// - Throws: NetworkError, EncodingError, or DecodingError
    public func patch<T: Decodable>(
        _ path: String,
        body: Encodable,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = buildURL(path)
        let bodyData = try JSONEncoder().encode(body)
        var request = NetworkRequest(url: url, method: .patch, headers: headers, body: bodyData)
        if request.headers["Content-Type"] == nil {
            request.headers["Content-Type"] = "application/json"
        }
        return try await execute(request)
    }

    /// Performs a DELETE request and decodes the response.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - headers: Optional custom headers
    /// - Returns: The decoded response object
    /// - Throws: NetworkError or DecodingError
    public func delete<T: Decodable>(
        _ path: String,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = buildURL(path)
        let request = NetworkRequest(url: url, method: .delete, headers: headers)
        return try await execute(request)
    }

    /// Performs a custom network request and decodes the response.
    ///
    /// - Parameter request: The configured NetworkRequest to execute
    /// - Returns: The decoded response object
    /// - Throws: NetworkError or DecodingError
    public func request<T: Decodable>(
        _ request: NetworkRequest
    ) async throws -> T {
        try await execute(request)
    }

    /// Executes a request with caching and retry logic.
    ///
    /// Checks the cache first if enabled, then executes with retry policy.
    ///
    /// - Parameter request: The network request to execute
    /// - Returns: The decoded response
    /// - Throws: NetworkError or DecodingError
    private func execute<T: Decodable>(_ request: NetworkRequest) async throws -> T {
        let cacheKey = request.cacheKey()

        // Try to get from cache if enabled
        if cacheEnabled, let cachedData = await cache.get(for: cacheKey) {
            do {
                let response = try JSONDecoder().decode(T.self, from: cachedData)
                return response
            } catch {
                // If cached data is corrupted, remove it and continue
                await cache.remove(for: cacheKey)
            }
        }

        return try await executeWithRetry(request, attempt: 1, cacheKey: cacheKey)
    }

    /// Executes a request with automatic retry logic.
    ///
    /// Applies all interceptors, executes the request, and retries if necessary
    /// based on the retry policy.
    ///
    /// - Parameters:
    ///   - request: The network request to execute
    ///   - attempt: The current attempt number
    ///   - cacheKey: The cache key for the response
    /// - Returns: The decoded response
    /// - Throws: NetworkError or DecodingError
    private func executeWithRetry<T: Decodable>(
        _ request: NetworkRequest,
        attempt: Int,
        cacheKey: String
    ) async throws -> T {
        do {
            var urlRequest = request.toURLRequest()

            // Apply all interceptors in order
            for interceptor in interceptors {
                urlRequest = try await interceptor.intercept(urlRequest)
            }

            // Perform the request
            let (data, response) = try await session.data(for: urlRequest)

            // Validate the response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            // Check HTTP status code
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
            }

            // Decode the response
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)

            // Cache the raw response data if caching is enabled
            if cacheEnabled {
                await cache.set(data, for: cacheKey, expiresIn: cacheDuration)
            }

            return decodedResponse
        } catch {
            // Check if we should retry
            if retryPolicy.shouldRetry(error, attempt: attempt) {
                let delay = retryPolicy.delayBeforeRetry(attempt: attempt)
                // Sleep for the calculated delay
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                // Retry recursively
                return try await executeWithRetry(request, attempt: attempt + 1, cacheKey: cacheKey)
            }

            // No more retries, throw the error
            throw error
        }
    }

    /// Constructs the full URL from the base URL and path.
    ///
    /// - Parameter path: The relative path or full URL
    /// - Returns: The complete URL
    private func buildURL(_ path: String) -> URL {
        if let baseURL {
            return baseURL.appendingPathComponent(path)
        }
        guard let url = URL(string: path) else {
            fatalError("Invalid URL: \(path)")
        }
        return url
    }
}
