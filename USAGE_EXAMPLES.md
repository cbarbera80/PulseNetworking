# Networking Library - Usage Examples

## 1. Basic Setup

```swift
import PulseNetworking

// Simple configuration
let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .build()

// Fetch data
let user: User = try await client.get("/users/1")
```

## 2. With Authentication

```swift
let authInterceptor = AuthInterceptor {
    // Get the token from somewhere (Keychain, UserDefaults, etc)
    return "your-jwt-token"
}

let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .withInterceptor(authInterceptor)
    .build()

let user: User = try await client.get("/users/me")
```

## 3. With Automatic Retry

```swift
let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .withExponentialBackoffRetry(
        maxRetries: 3,
        initialDelay: 1.0,
        maxDelay: 30.0
    )
    .build()

// If it fails, it will automatically retry with exponential backoff
let data: MyData = try await client.get("/data")
```

## 4. With Caching

```swift
let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .withCache(enabled: true, duration: 300) // 5 minutes
    .build()

// First request: fetch from server
let user: User = try await client.get("/users/1")

// Second request: returns from cache
let cachedUser: User = try await client.get("/users/1")
```

## 5. Full Configuration

```swift
let authInterceptor = AuthInterceptor {
    await getToken()
}

let loggingInterceptor = LoggingInterceptor()

let customHeaders = CustomHeaderInterceptor(headers: [
    "X-Custom-Header": "value",
    "User-Agent": "MyApp/1.0"
])

let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .withInterceptors([authInterceptor, loggingInterceptor, customHeaders])
    .withExponentialBackoffRetry(maxRetries: 3)
    .withCache(enabled: true, duration: 600)
    .build()

let user: User = try await client.get("/users/1")
```

## 6. POST with Body

```swift
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
}

let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .build()

let request = CreateUserRequest(
    name: "John Doe",
    email: "john@example.com"
)

let response: UserResponse = try await client.post("/users", body: request)
```

## 7. Different HTTP Methods

```swift
let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .build()

// GET
let user: User = try await client.get("/users/1")

// POST
let newUser: User = try await client.post("/users", body: createRequest)

// PUT (full replacement)
let updated: User = try await client.put("/users/1", body: updateRequest)

// PATCH (partial update)
let patched: User = try await client.patch("/users/1", body: patchRequest)

// DELETE
let deleted: DeleteResponse = try await client.delete("/users/1")
```

## 8. Custom Requests

```swift
let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .build()

var request = NetworkRequest(
    url: URL(string: "https://api.example.com/custom")!,
    method: .post,
    headers: ["X-Custom": "value"],
    body: customData
)

let response: MyResponse = try await client.request(request)
```

## 9. Error Handling

```swift
let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .build()

do {
    let user: User = try await client.get("/users/1")
} catch NetworkError.invalidURL(let url) {
    print("Invalid URL: \(url)")
} catch NetworkError.httpError(let statusCode, _) {
    print("HTTP Error: \(statusCode)")
} catch NetworkError.decodingFailed(let error) {
    print("Decoding failed: \(error)")
} catch NetworkError.retryExhausted(let error, let attempts) {
    print("Retry exhausted after \(attempts) attempts: \(error)")
} catch {
    print("Unknown error: \(error)")
}
```

## 10. Dynamic Token from Async Function

```swift
let authInterceptor = AuthInterceptor {
    // This closure is async, so you can use await
    let token = try? await getTokenFromServer()
    return token
}

let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .withInterceptor(authInterceptor)
    .build()
```

## Sample Models

```swift
// Decodable for receiving data
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

// Encodable for sending data
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
    let age: Int
}

// Can be both
struct UserUpdate: Codable {
    let name: String
    let email: String
}
```

## Custom Interceptor

```swift
class RateLimitInterceptor: NetworkInterceptor {
    private var requestCount = 0
    private let maxRequests = 10
    private let resetInterval = 60.0

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        requestCount += 1
        if requestCount > maxRequests {
            throw NetworkError.custom("Rate limit exceeded")
        }
        return request
    }
}
```

## Custom Retry Policy

```swift
class CustomRetryPolicy: RetryPolicy {
    func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        // Custom logic
        if attempt > 5 { return false }
        return error is URLError
    }

    func delayBeforeRetry(attempt: Int) -> TimeInterval {
        // Fibonacci backoff
        let fibs = [0, 1, 1, 2, 3, 5, 8, 13]
        return TimeInterval(fibs[min(attempt, fibs.count - 1)])
    }
}

let client = NetworkClientBuilder()
    .withBaseURL("https://api.example.com")
    .withRetryPolicy(CustomRetryPolicy())
    .build()
```
