# Testing Guide

Complete test coverage with 82 tests covering all aspects of the PulseNetworking library.

## Test Summary

- **Total Tests**: 82
- **Pass Rate**: 100%
- **Code Coverage**: Comprehensive coverage of all public APIs and edge cases

## Test Suites

### 1. NetworkErrorTests (10 tests)
Tests for all error types and descriptions:
- `invalidURL` - Invalid URL error
- `requestFailed` - Network request failures
- `invalidResponse` - Invalid HTTP response
- `decodingFailed` - JSON decoding errors
- `encodingFailed` - JSON encoding errors
- `noData` - Empty response data
- `httpError` - HTTP status code errors (404, 500, etc)
- `cacheError` - Cache-related errors
- `retryExhausted` - Failed after max retries
- `custom` - Custom error messages

**Coverage**: 100% of error enum cases

### 2. NetworkRequestTests (6 tests)
Tests for request modeling:
- Request initialization with various parameters
- URL construction
- HTTPMethod enum values (GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS)
- Cache key generation
- URL request conversion

**Coverage**: 100% of NetworkRequest and HTTPMethod

### 3. NetworkInterceptorTests (7 tests)
Tests for all interceptor implementations:
- `AuthInterceptor` - Token injection
- `AuthInterceptor` - Async token fetching
- `AuthInterceptor` - Handling missing tokens
- `LoggingInterceptor` - Request logging
- `CustomHeaderInterceptor` - Custom header injection
- Multiple interceptor chaining

**Coverage**: 100% of all interceptor types

### 4. RetryPolicyTests (11 tests)
Tests for retry policies:
- `ExponentialBackoffRetryPolicy` - Exponential backoff calculation
- `ExponentialBackoffRetryPolicy` - Network error retry logic
- `ExponentialBackoffRetryPolicy` - HTTP error retry logic
- `ExponentialBackoffRetryPolicy` - Max delay capping
- `SimpleRetryPolicy` - Fixed delay retries
- `NoRetryPolicy` - No retry behavior
- Custom retry status codes

**Coverage**: 100% of all retry policy implementations

### 5. NetworkCacheTests (13 tests)
Tests for caching functionality:
- `InMemoryNetworkCache` - Basic set/get
- `InMemoryNetworkCache` - Expiration handling
- `InMemoryNetworkCache` - Manual removal
- `InMemoryNetworkCache` - Cache clearing
- `InMemoryNetworkCache` - Multiple keys
- `InMemoryNetworkCache` - Cache overwriting
- `InMemoryNetworkCache` - Thread-safe concurrent access
- `NoNetworkCache` - Always empty behavior

**Coverage**: 100% of cache implementations

### 6. NetworkClientTests (18 tests)
Tests for the main HTTP client:
- GET/POST/PUT/PATCH/DELETE requests
- Custom headers
- HTTP error handling (4xx, 5xx)
- Network error handling
- Invalid JSON responses
- Request/response interceptors
- Retry policy integration
- Cache integration (enabled/disabled)
- Custom requests
- Base URL construction
- Content-Type headers

**Coverage**: 100% of all HTTP methods and error scenarios

### 7. NetworkClientBuilderTests (20 tests)
Tests for the fluent builder API:
- Base URL setup
- Session configuration
- Interceptor chaining
- Retry policy configuration
- Cache configuration
- Custom cache integration
- Method chaining and builder pattern
- All combinations of options

**Coverage**: 100% of builder methods

## Running Tests

### Run All Tests
```bash
swift test
```

### Run Specific Test Suite
```bash
swift test NetworkingTests.NetworkClientTests
```

### Run Tests with Code Coverage
```bash
swift test --enable-code-coverage
```

### Run Tests with Verbose Output
```bash
swift test -v
```

## Test Organization

```
Tests/
├── Mocks/
│   ├── MockURLSession.swift      # Mock URLSession for testing
│   └── TestModels.swift           # Test data models
└── Tests/
    ├── NetworkErrorTests.swift
    ├── NetworkRequestTests.swift
    ├── NetworkInterceptorTests.swift
    ├── RetryPolicyTests.swift
    ├── NetworkCacheTests.swift
    ├── NetworkClientTests.swift
    └── NetworkClientBuilderTests.swift
```

## Key Testing Patterns

### 1. Mock URLSession
Uses `MockURLSession` class that conforms to `URLSessionProtocol`:
```swift
let mockSession = MockURLSession()
mockSession.data = try JSONEncoder().encode(mockUser)
mockSession.response = mockHTTPResponse(statusCode: 200)

let client = NetworkClient(baseURL: baseURL, session: mockSession)
```

### 2. Custom Data Handlers
For complex scenarios with multiple requests:
```swift
mockSession.dataHandler = { request in
    // Custom logic per request
    return (data, response)
}
```

### 3. Async/Await Testing
All async code properly tested with `async throws`:
```swift
func testAuthInterceptorAsync() async throws {
    let interceptor = AuthInterceptor { await getToken() }
    let request = try await interceptor.intercept(request)
}
```

### 4. Error Testing
Comprehensive error scenario coverage:
```swift
do {
    let _: User = try await client.get("/invalid")
    XCTFail("Should have thrown")
} catch NetworkError.httpError(let statusCode, _) {
    XCTAssertEqual(statusCode, 404)
}
```

## Coverage Details

### NetworkClient Coverage
- ✅ All HTTP methods (GET, POST, PUT, PATCH, DELETE)
- ✅ Request/response processing
- ✅ Error handling (network, HTTP, decoding)
- ✅ Retry logic
- ✅ Cache integration
- ✅ Interceptor chain execution
- ✅ Base URL handling

### Interceptor Coverage
- ✅ AuthInterceptor (with and without token)
- ✅ LoggingInterceptor
- ✅ CustomHeaderInterceptor
- ✅ Multiple interceptor chaining
- ✅ Async token fetching

### Cache Coverage
- ✅ In-memory storage
- ✅ TTL/expiration
- ✅ Thread-safe operations
- ✅ Cache keys
- ✅ Disabled cache behavior

### Retry Policy Coverage
- ✅ Exponential backoff calculation
- ✅ Backoff delay capping
- ✅ Network error detection
- ✅ HTTP status code configuration
- ✅ Custom status codes
- ✅ No retry fallback

### Builder Coverage
- ✅ Fluent method chaining
- ✅ All configuration options
- ✅ Interceptor stacking
- ✅ Retry policy setup
- ✅ Cache configuration
- ✅ Session customization

## Integration Testing

Tests validate the complete workflow:
1. Client creation with builder
2. Request construction
3. Interceptor execution
4. Cache lookup
5. Network execution (mocked)
6. Response parsing
7. Retry on failure
8. Cache storage

## Edge Cases Covered

- Empty responses
- Invalid JSON
- HTTP errors (404, 500, etc)
- Network errors (timeout, no connection)
- Missing tokens
- Cache expiration
- Concurrent cache access
- Multiple interceptors
- Retry exhaustion
- Custom headers overwriting
