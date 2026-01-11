# PulseNetworking

A modern networking library for Swift based on **async/await** and designed with the **Builder** pattern.

## Features

✅ **Async/Await**: Modern and readable syntax
✅ **Builder Pattern**: Fluent and intuitive configuration
✅ **Interceptors**: Add custom logic (authentication, logging, etc.)
✅ **Automatic Retry**: Exponential backoff and custom policies
✅ **Caching**: In-memory cache with configurable TTL
✅ **Type-Safe**: Generics and type safety for request/response
✅ **Fully Testable**: Protocols for mocking dependencies

## Installation

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/cbarbera80/PulseNetworking.git", branch: "main")
```

Or via Xcode: File → Add Packages → paste the URL

## Quick Start

```swift
import PulseNetworking

let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .withExponentialBackoffRetry(maxRetries: 3)
    .withCache(enabled: true)
    .build()

let user: User = try await client.get("/users/1")
```

## Main API

### NetworkClient

```swift
public func get<T: Decodable>(_ path: String) async throws -> T
public func post<T: Decodable>(_ path: String, body: Encodable) async throws -> T
public func put<T: Decodable>(_ path: String, body: Encodable) async throws -> T
public func patch<T: Decodable>(_ path: String, body: Encodable) async throws -> T
public func delete<T: Decodable>(_ path: String) async throws -> T
public func request<T: Decodable>(_ request: NetworkRequest) async throws -> T
```

### NetworkClientBuilder

```swift
NetworkClientBuilder()
    .withBaseURL(_ url: URL) -> Self
    .withBaseURL(_ urlString: String) -> Self
    .withSession(_ session: URLSession) -> Self
    .withInterceptor(_ interceptor: NetworkInterceptor) -> Self
    .withInterceptors(_ interceptors: [NetworkInterceptor]) -> Self
    .withRetryPolicy(_ policy: RetryPolicy) -> Self
    .withExponentialBackoffRetry(...) -> Self
    .withSimpleRetry(...) -> Self
    .withCache(enabled: Bool, duration: TimeInterval) -> Self
    .withCustomCache(_ cache: NetworkCacheProtocol) -> Self
    .build() -> NetworkClient
```

## Interceptors

Implement `NetworkInterceptor` to add custom logic to requests:

```swift
class AuthInterceptor: NetworkInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modified = request
        modified.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return modified
    }
}
```

### Built-in Interceptors

- **AuthInterceptor**: Adds Authorization header
- **LoggingInterceptor**: Logs requests
- **CustomHeaderInterceptor**: Adds custom headers

## Retry Policies

Define how to handle errors and retries:

```swift
.withExponentialBackoffRetry(maxRetries: 3, initialDelay: 1.0, maxDelay: 30.0)
.withSimpleRetry(maxRetries: 3, delayInterval: 1.0)
.withRetryPolicy(MyCustomPolicy())
```

### Built-in Policies

- **ExponentialBackoffRetryPolicy**: Exponential backoff (default for 408, 429, 5xx)
- **SimpleRetryPolicy**: Fixed delay between retries
- **NoRetryPolicy**: No retry

## Caching

```swift
.withCache(enabled: true, duration: 300) // 5 minutes
```

- **InMemoryNetworkCache**: In-memory cache (thread-safe)
- **NoNetworkCache**: No cache
- Custom: Implement `NetworkCacheProtocol`

## Error Handling

```swift
public enum NetworkError: LocalizedError {
    case invalidURL(String)
    case requestFailed(URLError)
    case invalidResponse
    case decodingFailed(DecodingError)
    case encodingFailed(EncodingError)
    case noData
    case httpError(statusCode: Int, data: Data?)
    case cacheError(String)
    case retryExhausted(error: Error, attempts: Int)
    case custom(String)
}
```

## Complete Examples

See [USAGE_EXAMPLES.md](./USAGE_EXAMPLES.md) for 10 complete use cases.

## Requirements

- Swift 5.9+
- iOS 14.0+, macOS 11.0+, watchOS 7.0+, tvOS 14.0+

## License

MIT

## Contributing

Contributions are welcome! Feel free to open a PR or issue with suggestions.
