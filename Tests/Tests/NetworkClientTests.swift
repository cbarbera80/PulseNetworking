import XCTest
@testable import PulseNetworking

final class NetworkClientTests: XCTestCase {
    let baseURL = URL(string: "https://api.example.com")!
    let mockUser = MockUser(id: 1, name: "John", email: "john@example.com")

    func testGetRequest() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let result: MockUser = try await client.get("/users/1")

        XCTAssertEqual(result.id, mockUser.id)
        XCTAssertEqual(result.name, mockUser.name)
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "GET")
    }

    func testPostRequest() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 201)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let request = MockCreateUserRequest(name: "Jane", email: "jane@example.com")
        let result: MockUser = try await client.post("/users", body: request)

        XCTAssertEqual(result.id, mockUser.id)
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testPutRequest() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let request = MockCreateUserRequest(name: "Jane", email: "jane@example.com")
        let _: MockUser = try await client.put("/users/1", body: request)

        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "PUT")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testPatchRequest() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let request = MockCreateUserRequest(name: "Jane", email: "jane@example.com")
        let _: MockUser = try await client.patch("/users/1", body: request)

        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "PATCH")
    }

    func testDeleteRequest() async throws {
        let mockSession = MockURLSession()
        let deleteResponse = [String: String]()
        mockSession.data = try JSONEncoder().encode(deleteResponse)
        mockSession.response = mockHTTPResponse(statusCode: 204)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let _: [String: String] = try await client.delete("/users/1")

        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "DELETE")
    }

    func testRequestWithCustomHeaders() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let headers = ["X-Custom": "value"]
        let _: MockUser = try await client.get("/users/1", headers: headers)

        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "X-Custom"), "value")
    }

    func testHTTPErrorResponse() async throws {
        let mockSession = MockURLSession()
        mockSession.data = "".data(using: .utf8)
        mockSession.response = mockHTTPResponse(statusCode: 404)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)

        do {
            let _: MockUser = try await client.get("/users/999")
            XCTFail("Should have thrown")
        } catch NetworkError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 404)
        }
    }

    func testNetworkError() async throws {
        let mockSession = MockURLSession()
        mockSession.error = URLError(.networkConnectionLost)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)

        do {
            let _: MockUser = try await client.get("/users/1")
            XCTFail("Should have thrown")
        } catch is URLError {
            // Expected
        }
    }

    func testInvalidResponse() async throws {
        let mockSession = MockURLSession()
        mockSession.data = "not json".data(using: .utf8)!
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)

        do {
            let _: MockUser = try await client.get("/users/1")
            XCTFail("Should have thrown")
        } catch is DecodingError {
            // Expected
        }
    }

    func testWithInterceptors() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let interceptor = CustomHeaderInterceptor(headers: ["X-ID": "123"])

        let client = NetworkClient(
            baseURL: baseURL,
            session: mockSession,
            interceptors: [interceptor]
        )

        let _: MockUser = try await client.get("/users/1")

        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "X-ID"), "123")
    }

    func testWithRetryPolicy() async throws {
        let mockSession = MockURLSession()
        var callCount = 0

        mockSession.dataHandler = { _ in
            callCount += 1
            if callCount < 3 {
                throw URLError(.timedOut)
            }
            return (try JSONEncoder().encode(self.mockUser), mockHTTPResponse(statusCode: 200))
        }

        let retryPolicy = SimpleRetryPolicy(maxRetries: 3, delayInterval: 0.01)

        let client = NetworkClient(
            baseURL: baseURL,
            session: mockSession,
            retryPolicy: retryPolicy
        )

        let result: MockUser = try await client.get("/users/1")

        XCTAssertEqual(result.id, mockUser.id)
        XCTAssertGreaterThanOrEqual(callCount, 3)
    }

    func testWithCache() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let cache = InMemoryNetworkCache()

        let client = NetworkClient(
            baseURL: baseURL,
            session: mockSession,
            cache: cache,
            cacheEnabled: true,
            cacheDuration: 100
        )

        // First request
        let result1: MockUser = try await client.get("/users/1")
        XCTAssertEqual(mockSession.callCount, 1)

        // Second request should use cache
        let result2: MockUser = try await client.get("/users/1")
        XCTAssertEqual(mockSession.callCount, 1) // No additional call

        XCTAssertEqual(result1.id, result2.id)
    }

    func testCacheDisabled() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let cache = InMemoryNetworkCache()

        let client = NetworkClient(
            baseURL: baseURL,
            session: mockSession,
            cache: cache,
            cacheEnabled: false,
            cacheDuration: 100
        )

        // First request
        let _: MockUser = try await client.get("/users/1")
        XCTAssertEqual(mockSession.callCount, 1)

        // Second request should NOT use cache
        let _: MockUser = try await client.get("/users/1")
        XCTAssertEqual(mockSession.callCount, 2)
    }

    func testCustomRequest() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let customURL = URL(string: "https://api.example.com/custom/endpoint")!
        let request = NetworkRequest(url: customURL, method: .get)

        let result: MockUser = try await client.request(request)

        XCTAssertEqual(result.id, mockUser.id)
    }

    func testHTTPStatusCodeError() async throws {
        let mockSession = MockURLSession()
        let errorData = try JSONEncoder().encode(MockErrorResponse(error: "Not Found", message: "User not found"))
        mockSession.data = errorData
        mockSession.response = mockHTTPResponse(statusCode: 404)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)

        do {
            let _: MockUser = try await client.get("/users/999")
            XCTFail("Should have thrown")
        } catch NetworkError.httpError(let statusCode, let data) {
            XCTAssertEqual(statusCode, 404)
            XCTAssertEqual(data, errorData)
        }
    }

    func testBaseURLConstruction() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let _: MockUser = try await client.get("/users/1")

        XCTAssertEqual(mockSession.lastRequest?.url?.path, "/users/1")
    }

    func testNoBaseURL() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: nil, session: mockSession)
        let fullURL = "https://api.example.com/users/1"
        let _: MockUser = try await client.get(fullURL)

        XCTAssertEqual(mockSession.lastRequest?.url?.absoluteString, fullURL)
    }

    func testContentTypeHeader() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let request = MockCreateUserRequest(name: "Jane", email: "jane@example.com")
        let _: MockUser = try await client.post("/users", body: request)

        XCTAssertEqual(
            mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
    }

    func testVoidGetRequest() async throws {
        let mockSession = MockURLSession()
        mockSession.data = Data()
        mockSession.response = mockHTTPResponse(statusCode: 204)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        try await client.get("/users/1/email_verify/abc")

        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(mockSession.callCount, 1)
    }

    func testPostRequestWithoutBody() async throws {
        let mockSession = MockURLSession()
        mockSession.data = try JSONEncoder().encode(mockUser)
        mockSession.response = mockHTTPResponse(statusCode: 201)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let result: MockUser = try await client.post("/conversations")

        XCTAssertEqual(result.id, mockUser.id)
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertNil(mockSession.lastRequest?.httpBody)
    }

    func testVoidPostRequestWithoutBody() async throws {
        let mockSession = MockURLSession()
        mockSession.data = Data()
        mockSession.response = mockHTTPResponse(statusCode: 204)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        try await client.post("/shorts/1/progress")

        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertNil(mockSession.lastRequest?.httpBody)
        XCTAssertEqual(mockSession.callCount, 1)
    }

    func testVoidPostRequest() async throws {
        let mockSession = MockURLSession()
        mockSession.data = Data()
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)
        let request = MockCreateUserRequest(name: "Jane", email: "jane@example.com")
        try await client.post("/users", body: request)

        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(
            mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
    }

    func testVoidRequestSurfacesHTTPError() async throws {
        let mockSession = MockURLSession()
        mockSession.data = "".data(using: .utf8)
        mockSession.response = mockHTTPResponse(statusCode: 404)

        let client = NetworkClient(baseURL: baseURL, session: mockSession)

        do {
            try await client.get("/users/999")
            XCTFail("Should have thrown")
        } catch NetworkError.httpError(let statusCode, _) {
            XCTAssertEqual(statusCode, 404)
        }
    }

    func testCustomDecoder() async throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        struct SnakeCaseUser: Decodable {
            let userId: Int
            let userName: String
        }

        let mockSession = MockURLSession()
        mockSession.data = "{\"user_id\": 1, \"user_name\": \"John\"}".data(using: .utf8)
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let client = NetworkClient(baseURL: baseURL, session: mockSession, decoder: decoder)
        let result: SnakeCaseUser = try await client.get("/users/1")

        XCTAssertEqual(result.userId, 1)
        XCTAssertEqual(result.userName, "John")
    }

    func testCacheIgnoresNonGETRequests() async throws {
        let mockSession = MockURLSession()
        mockSession.response = mockHTTPResponse(statusCode: 200)

        let userA = MockUser(id: 1, name: "Alice", email: "alice@example.com")
        let userB = MockUser(id: 2, name: "Bob", email: "bob@example.com")

        mockSession.dataHandler = { _ in
            (try JSONEncoder().encode(mockSession.callCount == 1 ? userA : userB), mockHTTPResponse(statusCode: 200))
        }

        let client = NetworkClient(
            baseURL: baseURL,
            session: mockSession,
            cache: InMemoryNetworkCache(),
            cacheEnabled: true,
            cacheDuration: 100
        )

        let resultA: MockUser = try await client.post("/users", body: MockCreateUserRequest(name: "Alice", email: "alice@example.com"))
        let resultB: MockUser = try await client.post("/users", body: MockCreateUserRequest(name: "Bob", email: "bob@example.com"))

        XCTAssertEqual(mockSession.callCount, 2)
        XCTAssertEqual(resultA.name, "Alice")
        XCTAssertEqual(resultB.name, "Bob")
    }
}
