import XCTest
@testable import PulseNetworking

final class NetworkCacheTests: XCTestCase {
    func testInMemoryCacheSetAndGet() async {
        let cache = InMemoryNetworkCache()
        let key = "test-key"
        let data = "test data".data(using: .utf8)!

        await cache.set(data, for: key, expiresIn: 100)
        let retrieved = await cache.get(for: key)

        XCTAssertEqual(retrieved, data)
    }

    func testInMemoryCacheExpiration() async throws {
        let cache = InMemoryNetworkCache()
        let key = "test-key"
        let data = "test data".data(using: .utf8)!

        await cache.set(data, for: key, expiresIn: 0.1)

        // Should be available immediately
        let cached = await cache.get(for: key)
        XCTAssertNotNil(cached)

        // Wait for expiration
        try await Task.sleep(nanoseconds: 200_000_000)

        // Should be expired
        let expired = await cache.get(for: key)
        XCTAssertNil(expired)
    }

    func testInMemoryCacheRemove() async {
        let cache = InMemoryNetworkCache()
        let key = "test-key"
        let data = "test data".data(using: .utf8)!

        await cache.set(data, for: key, expiresIn: 100)
        let before = await cache.get(for: key)
        XCTAssertNotNil(before)

        await cache.remove(for: key)
        let after = await cache.get(for: key)
        XCTAssertNil(after)
    }

    func testInMemoryCacheClear() async {
        let cache = InMemoryNetworkCache()
        let data = "test".data(using: .utf8)!

        await cache.set(data, for: "key1", expiresIn: 100)
        await cache.set(data, for: "key2", expiresIn: 100)
        await cache.set(data, for: "key3", expiresIn: 100)

        let value1 = await cache.get(for: "key1")
        let value2 = await cache.get(for: "key2")
        let value3 = await cache.get(for: "key3")
        XCTAssertNotNil(value1)
        XCTAssertNotNil(value2)
        XCTAssertNotNil(value3)

        await cache.clear()

        let cleared1 = await cache.get(for: "key1")
        let cleared2 = await cache.get(for: "key2")
        let cleared3 = await cache.get(for: "key3")
        XCTAssertNil(cleared1)
        XCTAssertNil(cleared2)
        XCTAssertNil(cleared3)
    }

    func testInMemoryCacheMultipleKeys() async {
        let cache = InMemoryNetworkCache()
        let data1 = "data1".data(using: .utf8)!
        let data2 = "data2".data(using: .utf8)!

        await cache.set(data1, for: "key1", expiresIn: 100)
        await cache.set(data2, for: "key2", expiresIn: 100)

        let retrieved1 = await cache.get(for: "key1")
        let retrieved2 = await cache.get(for: "key2")
        XCTAssertEqual(retrieved1, data1)
        XCTAssertEqual(retrieved2, data2)
    }

    func testInMemoryCacheGetNonexistent() async {
        let cache = InMemoryNetworkCache()
        let result = await cache.get(for: "nonexistent-key")
        XCTAssertNil(result)
    }

    func testInMemoryCacheThreadSafety() async throws {
        let cache = InMemoryNetworkCache()

        let tasks = (0..<100).map { i -> Task<Void, Never> in
            Task {
                let key = "key-\(i % 10)"
                let data = "data-\(i)".data(using: .utf8)!
                await cache.set(data, for: key, expiresIn: 100)
            }
        }

        for task in tasks {
            await task.value
        }

        // All writes should complete without errors
        let value = await cache.get(for: "key-0")
        XCTAssertNotNil(value)
    }

    func testNoNetworkCacheAlwaysEmpty() async {
        let cache = NoNetworkCache()
        let data = "test".data(using: .utf8)!

        await cache.set(data, for: "key", expiresIn: 100)
        let value = await cache.get(for: "key")
        XCTAssertNil(value)

        await cache.remove(for: "key")
        await cache.clear()
    }

    func testNetworkRequestCacheKey() {
        let url = URL(string: "https://api.example.com/users/1")!
        let getRequest = NetworkRequest(url: url, method: .get)
        let postRequest = NetworkRequest(url: url, method: .post)

        let getKey = getRequest.cacheKey()
        let postKey = postRequest.cacheKey()

        XCTAssertEqual(getKey, "GET_https://api.example.com/users/1")
        XCTAssertEqual(postKey, "POST_https://api.example.com/users/1")
        XCTAssertNotEqual(getKey, postKey)
    }

    func testInMemoryCacheOverwrite() async {
        let cache = InMemoryNetworkCache()
        let key = "test-key"
        let data1 = "data1".data(using: .utf8)!
        let data2 = "data2".data(using: .utf8)!

        await cache.set(data1, for: key, expiresIn: 100)
        let first = await cache.get(for: key)
        XCTAssertEqual(first, data1)

        await cache.set(data2, for: key, expiresIn: 100)
        let second = await cache.get(for: key)
        XCTAssertEqual(second, data2)
    }
}
