import XCTest
@testable import PulseNetworking

final class NetworkInterceptorTests: XCTestCase {
    let testURL = URL(string: "https://api.example.com/users")!

    func testAuthInterceptorWithToken() async throws {
        let token = "test-token-123"
        let interceptor = AuthInterceptor { token }

        let request = URLRequest(url: testURL)
        let modifiedRequest = try await interceptor.intercept(request)

        XCTAssertEqual(
            modifiedRequest.value(forHTTPHeaderField: "Authorization"),
            "Bearer \(token)"
        )
    }

    func testAuthInterceptorWithoutToken() async throws {
        let interceptor = AuthInterceptor { nil }

        let request = URLRequest(url: testURL)
        let modifiedRequest = try await interceptor.intercept(request)

        XCTAssertNil(modifiedRequest.value(forHTTPHeaderField: "Authorization"))
    }

    func testAuthInterceptorAsync() async throws {
        let interceptor = AuthInterceptor {
            try? await Task.sleep(nanoseconds: 100_000)
            return "async-token"
        }

        let request = URLRequest(url: testURL)
        let modifiedRequest = try await interceptor.intercept(request)

        XCTAssertEqual(
            modifiedRequest.value(forHTTPHeaderField: "Authorization"),
            "Bearer async-token"
        )
    }

    func testLoggingInterceptor() async throws {
        let interceptor = LoggingInterceptor()

        let request = URLRequest(url: testURL)
        let modifiedRequest = try await interceptor.intercept(request)

        // Logging interceptor just returns the request unchanged
        XCTAssertEqual(modifiedRequest.url, request.url)
    }

    func testCustomHeaderInterceptor() async throws {
        let customHeaders = [
            "X-Custom-Header": "custom-value",
            "User-Agent": "MyApp/1.0"
        ]
        let interceptor = CustomHeaderInterceptor(headers: customHeaders)

        let request = URLRequest(url: testURL)
        let modifiedRequest = try await interceptor.intercept(request)

        XCTAssertEqual(
            modifiedRequest.value(forHTTPHeaderField: "X-Custom-Header"),
            "custom-value"
        )
        XCTAssertEqual(
            modifiedRequest.value(forHTTPHeaderField: "User-Agent"),
            "MyApp/1.0"
        )
    }

    func testCustomHeaderInterceptorEmpty() async throws {
        let interceptor = CustomHeaderInterceptor(headers: [:])

        let request = URLRequest(url: testURL)
        let modifiedRequest = try await interceptor.intercept(request)

        XCTAssertEqual(modifiedRequest.url, request.url)
    }

    func testMultipleInterceptors() async throws {
        let authInterceptor = AuthInterceptor { "test-token" }
        let customInterceptor = CustomHeaderInterceptor(headers: ["X-ID": "123"])

        var request = URLRequest(url: testURL)
        request = try await authInterceptor.intercept(request)
        request = try await customInterceptor.intercept(request)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-token"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-ID"), "123")
    }
}
