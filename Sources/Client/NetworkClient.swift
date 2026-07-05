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

    /// The JSONDecoder used to decode response bodies.
    private let decoder: JSONDecoder

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
    ///   - decoder: JSONDecoder used to decode response bodies
    init(
        baseURL: URL?,
        session: URLSessionProtocol = URLSession.shared,
        interceptors: [NetworkInterceptor] = [],
        retryPolicy: RetryPolicy = NoRetryPolicy(),
        cache: NetworkCacheProtocol = NoNetworkCache(),
        cacheEnabled: Bool = false,
        cacheDuration: TimeInterval = 300,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.interceptors = interceptors
        self.retryPolicy = retryPolicy
        self.cache = cache
        self.cacheEnabled = cacheEnabled
        self.cacheDuration = cacheDuration
        self.decoder = decoder
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

    /// Performs a GET request without decoding the response body.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - headers: Optional custom headers
    /// - Throws: NetworkError
    public func get(
        _ path: String,
        headers: [String: String] = [:]
    ) async throws {
        let url = buildURL(path)
        let request = NetworkRequest(url: url, method: .get, headers: headers)
        try await send(request)
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
        let request = try buildBodyRequest(path, method: .post, body: body, headers: headers)
        return try await execute(request)
    }

    /// Performs a POST request with no body and decodes the response.
    ///
    /// Use this for trigger-style endpoints that don't need a request body
    /// but do return a body to decode (e.g. "create resource" endpoints
    /// identified solely by auth/headers).
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - headers: Optional custom headers
    /// - Returns: The decoded response object
    /// - Throws: NetworkError or DecodingError
    public func post<T: Decodable>(
        _ path: String,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = buildURL(path)
        let request = NetworkRequest(url: url, method: .post, headers: headers)
        return try await execute(request)
    }

    /// Performs a POST request with an encoded body, without decoding the response.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - body: The request body to encode as JSON
    ///   - headers: Optional custom headers
    /// - Throws: NetworkError or EncodingError
    public func post(
        _ path: String,
        body: Encodable,
        headers: [String: String] = [:]
    ) async throws {
        let request = try buildBodyRequest(path, method: .post, body: body, headers: headers)
        try await send(request)
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
        let request = try buildBodyRequest(path, method: .put, body: body, headers: headers)
        return try await execute(request)
    }

    /// Performs a PUT request with an encoded body, without decoding the response.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - body: The request body to encode as JSON
    ///   - headers: Optional custom headers
    /// - Throws: NetworkError or EncodingError
    public func put(
        _ path: String,
        body: Encodable,
        headers: [String: String] = [:]
    ) async throws {
        let request = try buildBodyRequest(path, method: .put, body: body, headers: headers)
        try await send(request)
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
        let request = try buildBodyRequest(path, method: .patch, body: body, headers: headers)
        return try await execute(request)
    }

    /// Performs a PATCH request with an encoded body, without decoding the response.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - body: The request body to encode as JSON
    ///   - headers: Optional custom headers
    /// - Throws: NetworkError or EncodingError
    public func patch(
        _ path: String,
        body: Encodable,
        headers: [String: String] = [:]
    ) async throws {
        let request = try buildBodyRequest(path, method: .patch, body: body, headers: headers)
        try await send(request)
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

    /// Performs a DELETE request without decoding the response.
    ///
    /// - Parameters:
    ///   - path: The request path (appended to baseURL if set)
    ///   - headers: Optional custom headers
    /// - Throws: NetworkError
    public func delete(
        _ path: String,
        headers: [String: String] = [:]
    ) async throws {
        let url = buildURL(path)
        let request = NetworkRequest(url: url, method: .delete, headers: headers)
        try await send(request)
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

    /// Performs a custom network request, discarding the response body.
    ///
    /// Use this for endpoints that return no body or a body you don't need decoded
    /// (e.g. 204 No Content, or acknowledgement-only endpoints).
    ///
    /// - Parameter request: The configured NetworkRequest to execute
    /// - Throws: NetworkError
    public func send(_ request: NetworkRequest) async throws {
        _ = try await performRequest(request, attempt: 1)
    }

    /// Builds a NetworkRequest with a JSON-encoded body and a default Content-Type header.
    ///
    /// - Throws: EncodingError if the body cannot be encoded
    private func buildBodyRequest(
        _ path: String,
        method: HTTPMethod,
        body: Encodable,
        headers: [String: String]
    ) throws -> NetworkRequest {
        let url = buildURL(path)
        let bodyData = try JSONEncoder().encode(body)
        var request = NetworkRequest(url: url, method: method, headers: headers, body: bodyData)
        if request.headers["Content-Type"] == nil {
            request.headers["Content-Type"] = "application/json"
        }
        return request
    }

    /// Executes a request with caching and retry logic, then decodes the response.
    ///
    /// Checks the cache first if enabled (GET requests only), then executes with retry policy.
    ///
    /// - Parameter request: The network request to execute
    /// - Returns: The decoded response
    /// - Throws: NetworkError or DecodingError
    private func execute<T: Decodable>(_ request: NetworkRequest) async throws -> T {
        let cacheKey = request.cacheKey()
        let cacheable = cacheEnabled && request.method == .get

        if cacheable, let cachedData = await cache.get(for: cacheKey) {
            do {
                return try decoder.decode(T.self, from: cachedData)
            } catch {
                // If cached data is corrupted, remove it and continue
                await cache.remove(for: cacheKey)
            }
        }

        let data = try await performRequest(request, attempt: 1)

        let decoded = try decoder.decode(T.self, from: data)

        if cacheable {
            await cache.set(data, for: cacheKey, expiresIn: cacheDuration)
        }

        return decoded
    }

    /// Executes a request with automatic retry logic and returns the raw response data.
    ///
    /// Applies all interceptors (re-applied on every retry attempt, so interceptors that
    /// read fresh state such as a refreshed auth token work correctly), executes the
    /// request, validates the HTTP status, and retries if necessary based on the retry policy.
    ///
    /// - Parameters:
    ///   - request: The network request to execute
    ///   - attempt: The current attempt number
    /// - Returns: The raw response data
    /// - Throws: NetworkError
    private func performRequest(_ request: NetworkRequest, attempt: Int) async throws -> Data {
        do {
            var urlRequest = request.toURLRequest()

            for interceptor in interceptors {
                urlRequest = try await interceptor.intercept(urlRequest)
            }

            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
            }

            return data
        } catch {
            if retryPolicy.shouldRetry(error, attempt: attempt) {
                let delay = retryPolicy.delayBeforeRetry(attempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await performRequest(request, attempt: attempt + 1)
            }

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
