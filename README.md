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
✅ **Streaming (SSE)**: Server-Sent Events support via native `URLSession.bytes`

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
public func post<T: Decodable>(_ path: String) async throws -> T // no body, e.g. trigger-style endpoints
public func put<T: Decodable>(_ path: String, body: Encodable) async throws -> T
public func patch<T: Decodable>(_ path: String, body: Encodable) async throws -> T
public func delete<T: Decodable>(_ path: String) async throws -> T
public func request<T: Decodable>(_ request: NetworkRequest) async throws -> T
public func stream<T: Decodable & Sendable>(_ path: String, headers: [String: String], queryItems: [URLQueryItem]) async throws -> AsyncThrowingStream<T, Error>

// No-decode variants, for endpoints with no body or a response you don't need
// (e.g. 204 No Content, ack-only endpoints)
public func get(_ path: String) async throws
public func post(_ path: String, body: Encodable) async throws
public func put(_ path: String, body: Encodable) async throws
public func patch(_ path: String, body: Encodable) async throws
public func delete(_ path: String) async throws
public func send(_ request: NetworkRequest) async throws
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
    .withDecoder(_ decoder: JSONDecoder) -> Self
    .withStreamingSession(_ session: URLSessionStreamingProtocol) -> Self
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

Only GET requests are cached — mutating requests (POST/PUT/PATCH/DELETE) always hit the network, since the cache key doesn't account for the request body.

- **InMemoryNetworkCache**: In-memory cache (thread-safe)
- **NoNetworkCache**: No cache
- Custom: Implement `NetworkCacheProtocol`

## Streaming (Server-Sent Events)

Opens a Server-Sent Events connection via native `URLSession.bytes(for:)` (no external dependencies), parses events per the SSE spec, and decodes each event's `data` field as JSON into `T`.

```swift
struct ChatEvent: Decodable {
    let type: String
    // ...custom fields, including a custom init(from:) if you need to
    // discriminate on "type" (e.g. tool_use vs message)
}

let stream: AsyncThrowingStream<ChatEvent, Error> = try await client.stream(
    "/v1/streaming/conversations/123",
    headers: ["Accept-Language": "it"],
    queryItems: [URLQueryItem(name: "q", value: "hello")]
)

for try await event in stream {
    // handle event
}
```

### Limitations

- **No automatic retry**: if the connection drops mid-stream, the error propagates to the consumer. It's up to the caller to decide whether/how to reopen the stream.
- **Cache is always bypassed**, even if enabled on the client.
- **Interceptors are applied once**, when the connection opens — never re-applied, since there's no retry.
- **`event:`/`id:`/`retry:` fields are parsed for SSE-spec correctness but not exposed publicly** — only the `data` field is decoded into `T`.
- **The error body isn't read** on a non-2xx initial HTTP status (`NetworkError.httpError(data: nil)`), to avoid blocking on a response that might itself be a stream.

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

- Swift 6.0+
- iOS 15.0+, macOS 12.0+, watchOS 8.0+, tvOS 15.0+

## License

MIT

## Contributing

Contributions are welcome! Feel free to open a PR or issue with suggestions.
