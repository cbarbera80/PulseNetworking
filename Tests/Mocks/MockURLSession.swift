import Foundation
@testable import PulseNetworking

class MockURLSession: NSObject, URLSessionProtocol, @unchecked Sendable {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var lastRequest: URLRequest?
    var callCount = 0
    var dataHandler: ((URLRequest) async throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        callCount += 1

        if let handler = dataHandler {
            return try await handler(request)
        }

        if let error = error {
            throw error
        }

        guard let data = data, let response = response else {
            throw NetworkError.noData
        }

        return (data, response)
    }

    func reset() {
        data = nil
        response = nil
        error = nil
        lastRequest = nil
        callCount = 0
        dataHandler = nil
    }
}

func mockHTTPResponse(
    statusCode: Int = 200,
    url: URL = URL(string: "https://api.example.com/test")!
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: [:]
    )!
}

func mockJSONData<T: Encodable>(_ object: T) -> Data {
    try! JSONEncoder().encode(object)
}
