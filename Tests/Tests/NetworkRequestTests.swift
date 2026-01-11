import XCTest
@testable import PulseNetworking

final class NetworkRequestTests: XCTestCase {
    let testURL = URL(string: "https://api.example.com/users")!

    func testNetworkRequestInitialization() {
        let request = NetworkRequest(url: testURL)
        XCTAssertEqual(request.url, testURL)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.headers.count, 0)
        XCTAssertNil(request.body)
        XCTAssertEqual(request.timeoutInterval, 30)
    }

    func testNetworkRequestWithCustomValues() {
        let body = "test body".data(using: .utf8)!
        let headers = ["Authorization": "Bearer token"]
        let request = NetworkRequest(
            url: testURL,
            method: .post,
            headers: headers,
            body: body,
            timeoutInterval: 60
        )

        XCTAssertEqual(request.url, testURL)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.headers, headers)
        XCTAssertEqual(request.body, body)
        XCTAssertEqual(request.timeoutInterval, 60)
    }

    func testNetworkRequestToURLRequest() {
        let headers = ["Content-Type": "application/json"]
        let body = "test".data(using: .utf8)
        let request = NetworkRequest(
            url: testURL,
            method: .put,
            headers: headers,
            body: body,
            timeoutInterval: 45
        )

        let urlRequest = request.toURLRequest()

        XCTAssertEqual(urlRequest.url, testURL)
        XCTAssertEqual(urlRequest.httpMethod, "PUT")
        XCTAssertEqual(urlRequest.allHTTPHeaderFields, headers)
        XCTAssertEqual(urlRequest.httpBody, body)
        XCTAssertEqual(urlRequest.timeoutInterval, 45)
    }

    func testCacheKey() {
        let request = NetworkRequest(url: testURL, method: .get)
        let cacheKey = request.cacheKey()
        XCTAssertEqual(cacheKey, "GET_https://api.example.com/users")
    }

    func testCacheKeyDifferentMethods() {
        let getRequest = NetworkRequest(url: testURL, method: .get)
        let postRequest = NetworkRequest(url: testURL, method: .post)

        XCTAssertNotEqual(getRequest.cacheKey(), postRequest.cacheKey())
    }

    func testHTTPMethodRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.head.rawValue, "HEAD")
        XCTAssertEqual(HTTPMethod.options.rawValue, "OPTIONS")
    }
}
