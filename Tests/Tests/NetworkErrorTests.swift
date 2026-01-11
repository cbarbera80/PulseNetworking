import XCTest
@testable import PulseNetworking

final class NetworkErrorTests: XCTestCase {
    func testInvalidURLDescription() {
        let error = NetworkError.invalidURL("invalid://url")
        XCTAssertEqual(error.errorDescription, "Invalid URL: invalid://url")
    }

    func testRequestFailedDescription() {
        let urlError = URLError(.badURL)
        let error = NetworkError.requestFailed(urlError)
        XCTAssertTrue(error.errorDescription?.contains("Request failed") ?? false)
    }

    func testInvalidResponseDescription() {
        let error = NetworkError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response from server")
    }

    func testDecodingFailedDescription() {
        let data = "invalid json".data(using: .utf8)!
        let decoder = JSONDecoder()
        do {
            _ = try decoder.decode(MockUser.self, from: data)
            XCTFail("Should have thrown")
        } catch let decodingError as DecodingError {
            let error = NetworkError.decodingFailed(decodingError)
            XCTAssertTrue(error.errorDescription?.contains("Decoding failed") ?? false)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testEncodingFailedDescription() {
        // Create a real encoding error by attempting to encode something non-codable
        class NonEncodableClass {}

        struct NonCodable: Encodable {
            let instance: NonEncodableClass

            enum CodingKeys: CodingKey {
                case instance
            }

            func encode(to encoder: Encoder) throws {
                // Attempt to encode a non-Encodable type which will fail
                let container = encoder.container(keyedBy: CodingKeys.self)
                let _ = Mirror(reflecting: instance)
                throw EncodingError.invalidValue(
                    instance,
                    EncodingError.Context(
                        codingPath: container.codingPath + [CodingKeys.instance],
                        debugDescription: "NonEncodableClass is not encodable"
                    )
                )
            }
        }

        let encoder = JSONEncoder()
        do {
            let nonCodable = NonCodable(instance: NonEncodableClass())
            _ = try encoder.encode(nonCodable)
            XCTFail("Should have thrown")
        } catch let encodingError as EncodingError {
            let error = NetworkError.encodingFailed(encodingError)
            XCTAssertTrue(error.errorDescription?.contains("Encoding") ?? false)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNoDataDescription() {
        let error = NetworkError.noData
        XCTAssertEqual(error.errorDescription, "No data received from server")
    }

    func testHTTPErrorDescription() {
        let error = NetworkError.httpError(statusCode: 404, data: nil)
        XCTAssertEqual(error.errorDescription, "HTTP error 404")
    }

    func testCacheErrorDescription() {
        let error = NetworkError.cacheError("Cache is full")
        XCTAssertEqual(error.errorDescription, "Cache error: Cache is full")
    }

    func testRetryExhaustedDescription() {
        let originalError = NSError(domain: "test", code: 1)
        let error = NetworkError.retryExhausted(error: originalError, attempts: 3)
        XCTAssertTrue(error.errorDescription?.contains("Request failed after 3 attempts") ?? false)
    }

    func testCustomErrorDescription() {
        let error = NetworkError.custom("Something went wrong")
        XCTAssertEqual(error.errorDescription, "Something went wrong")
    }
}
