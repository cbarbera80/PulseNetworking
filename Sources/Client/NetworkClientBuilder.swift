import Foundation

/// A fluent builder for creating and configuring NetworkClient instances.
///
/// `NetworkClientBuilder` uses the builder pattern to provide a convenient, readable way
/// to configure all aspects of a NetworkClient. All methods return `Self` to allow
/// method chaining.
///
/// Example:
/// ```swift
/// let client = NetworkClientBuilder()
///     .withBaseURL("https://api.example.com")
///     .withInterceptor(AuthInterceptor { await getToken() })
///     .withExponentialBackoffRetry(maxRetries: 3)
///     .withCache(enabled: true, duration: 600)
///     .build()
/// ```
public class NetworkClientBuilder {
    /// The base URL for all requests.
    private var baseURL: URL?

    /// The URLSession to use for network requests.
    private var session: URLSessionProtocol = URLSession.shared

    /// Array of request interceptors.
    private var interceptors: [NetworkInterceptor] = []

    /// Policy for retrying failed requests.
    private var retryPolicy: RetryPolicy = NoRetryPolicy()

    /// Cache implementation.
    private var cache: NetworkCacheProtocol = NoNetworkCache()

    /// Whether caching is enabled.
    private var cacheEnabled: Bool = false

    /// Cache duration in seconds.
    private var cacheDuration: TimeInterval = 300

    /// Initializes a new NetworkClientBuilder with default settings.
    public init() {}

    /// Sets the base URL for all requests.
    ///
    /// - Parameter url: The base URL
    /// - Returns: Self for method chaining
    @discardableResult
    public func withBaseURL(_ url: URL) -> Self {
        self.baseURL = url
        return self
    }

    /// Sets the base URL for all requests from a string.
    ///
    /// - Parameter urlString: A valid URL string
    /// - Returns: Self for method chaining
    /// - Fatalizes: If the URL string is invalid
    @discardableResult
    public func withBaseURL(_ urlString: String) -> Self {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL: \(urlString)")
        }
        self.baseURL = url
        return self
    }

    /// Sets a custom URLSession for network requests.
    ///
    /// - Parameter session: The URLSession or compatible object to use
    /// - Returns: Self for method chaining
    @discardableResult
    public func withSession(_ session: URLSessionProtocol) -> Self {
        self.session = session
        return self
    }

    /// Adds a single interceptor to the request pipeline.
    ///
    /// Interceptors are applied in the order they are added.
    ///
    /// - Parameter interceptor: The interceptor to add
    /// - Returns: Self for method chaining
    @discardableResult
    public func withInterceptor(_ interceptor: NetworkInterceptor) -> Self {
        self.interceptors.append(interceptor)
        return self
    }

    /// Adds multiple interceptors to the request pipeline.
    ///
    /// Interceptors are applied in the order they appear in the array.
    ///
    /// - Parameter interceptors: Array of interceptors to add
    /// - Returns: Self for method chaining
    @discardableResult
    public func withInterceptors(_ interceptors: [NetworkInterceptor]) -> Self {
        self.interceptors.append(contentsOf: interceptors)
        return self
    }

    /// Sets a custom retry policy.
    ///
    /// - Parameter policy: The retry policy to use
    /// - Returns: Self for method chaining
    @discardableResult
    public func withRetryPolicy(_ policy: RetryPolicy) -> Self {
        self.retryPolicy = policy
        return self
    }

    /// Enables exponential backoff retry strategy.
    ///
    /// Retries failed requests with exponentially increasing delays.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (defaults to 3)
    ///   - initialDelay: Initial delay in seconds (defaults to 1.0)
    ///   - maxDelay: Maximum delay in seconds (defaults to 30.0)
    /// - Returns: Self for method chaining
    @discardableResult
    public func withExponentialBackoffRetry(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0
    ) -> Self {
        self.retryPolicy = ExponentialBackoffRetryPolicy(
            maxRetries: maxRetries,
            initialDelay: initialDelay,
            maxDelay: maxDelay
        )
        return self
    }

    /// Enables simple retry strategy with fixed delays.
    ///
    /// Retries failed requests with a constant delay between attempts.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (defaults to 3)
    ///   - delayInterval: Fixed delay in seconds between retries (defaults to 1.0)
    /// - Returns: Self for method chaining
    @discardableResult
    public func withSimpleRetry(
        maxRetries: Int = 3,
        delayInterval: TimeInterval = 1.0
    ) -> Self {
        self.retryPolicy = SimpleRetryPolicy(
            maxRetries: maxRetries,
            delayInterval: delayInterval
        )
        return self
    }

    /// Enables or disables in-memory response caching.
    ///
    /// When enabled, successful responses are cached with the specified TTL.
    /// Subsequent identical requests will return cached data if available and not expired.
    ///
    /// - Parameters:
    ///   - enabled: Whether caching should be enabled
    ///   - duration: Cache TTL in seconds (defaults to 300/5 minutes)
    /// - Returns: Self for method chaining
    @discardableResult
    public func withCache(enabled: Bool, duration: TimeInterval = 300) -> Self {
        self.cacheEnabled = enabled
        self.cacheDuration = duration
        if enabled {
            self.cache = InMemoryNetworkCache()
        }
        return self
    }

    /// Sets a custom cache implementation.
    ///
    /// - Parameters:
    ///   - cache: The cache implementation to use
    ///   - enabled: Whether caching should be enabled (defaults to true)
    /// - Returns: Self for method chaining
    @discardableResult
    public func withCustomCache(_ cache: NetworkCacheProtocol, enabled: Bool = true) -> Self {
        self.cache = cache
        self.cacheEnabled = enabled
        return self
    }

    /// Builds and returns the configured NetworkClient instance.
    ///
    /// - Returns: A fully configured NetworkClient
    public func build() -> NetworkClient {
        NetworkClient(
            baseURL: baseURL,
            session: session,
            interceptors: interceptors,
            retryPolicy: retryPolicy,
            cache: cache,
            cacheEnabled: cacheEnabled,
            cacheDuration: cacheDuration
        )
    }
}
