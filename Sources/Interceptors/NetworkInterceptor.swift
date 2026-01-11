import Foundation

/// Protocol for intercepting and modifying HTTP requests.
///
/// Interceptors allow you to add custom logic to requests before they are sent.
/// Common use cases include adding authentication headers, logging, or modifying headers.
///
/// Multiple interceptors can be chained together and will be executed in order.
public protocol NetworkInterceptor: Sendable {
    /// Intercepts a request and returns a potentially modified request.
    ///
    /// - Parameter request: The original URLRequest
    /// - Returns: The modified URLRequest (or unchanged if no modifications needed)
    /// - Throws: Any error that should prevent the request from being sent
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

/// An interceptor that adds Bearer token authentication to requests.
///
/// This interceptor automatically injects an Authorization header with a Bearer token
/// obtained from an async token provider function. Useful for OAuth and JWT authentication.
///
/// Example:
/// ```swift
/// let interceptor = AuthInterceptor {
///     await getAuthToken()
/// }
/// ```
public class AuthInterceptor: NetworkInterceptor, @unchecked Sendable {
    /// Closure that asynchronously provides the authentication token.
    private let tokenProvider: @Sendable () async -> String?

    /// Initializes an AuthInterceptor with a token provider.
    ///
    /// - Parameter tokenProvider: An async closure that returns the authentication token,
    ///                            or nil if no token is available
    public init(tokenProvider: @escaping @Sendable () async -> String?) {
        self.tokenProvider = tokenProvider
    }

    /// Intercepts the request and adds the Bearer token if available.
    ///
    /// - Parameter request: The original URLRequest
    /// - Returns: The request with Authorization header added (if token is available)
    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        if let token = await tokenProvider() {
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return modifiedRequest
    }
}

/// An interceptor that logs network requests for debugging purposes.
///
/// Prints information about each request including the HTTP method, URL, and headers.
/// This is useful during development and debugging.
public class LoggingInterceptor: NetworkInterceptor, @unchecked Sendable {
    /// Initializes a new LoggingInterceptor.
    public init() {}

    /// Intercepts the request and logs its details.
    ///
    /// - Parameter request: The URLRequest to log
    /// - Returns: The request unchanged
    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        print("📤 [Network] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")")
        if let headers = request.allHTTPHeaderFields {
            print("   Headers: \(headers)")
        }
        return request
    }
}

/// An interceptor that adds custom HTTP headers to all requests.
///
/// This interceptor is useful for adding headers that should be sent with every request,
/// such as API version headers, custom authentication schemes, or tracking headers.
///
/// Example:
/// ```swift
/// let interceptor = CustomHeaderInterceptor(headers: [
///     "X-API-Version": "2.0",
///     "X-Client-ID": "myapp"
/// ])
/// ```
public class CustomHeaderInterceptor: NetworkInterceptor, @unchecked Sendable {
    /// The headers to add to requests.
    private let headers: [String: String]

    /// Initializes a CustomHeaderInterceptor with the specified headers.
    ///
    /// - Parameter headers: Dictionary of header names and values to add to requests
    public init(headers: [String: String]) {
        self.headers = headers
    }

    /// Intercepts the request and adds the custom headers.
    ///
    /// - Parameter request: The original URLRequest
    /// - Returns: The request with custom headers added
    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        headers.forEach { key, value in
            modifiedRequest.setValue(value, forHTTPHeaderField: key)
        }
        return modifiedRequest
    }
}
