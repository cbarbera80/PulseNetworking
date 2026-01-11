import Foundation

/// Protocol for implementing caching strategies in network requests.
///
/// Conforming types can implement different caching strategies, such as in-memory caching,
/// disk caching, or custom implementations.
public protocol NetworkCacheProtocol: Sendable {
    /// Retrieves cached data for the specified key.
    ///
    /// - Parameter key: The cache key
    /// - Returns: The cached data if available and not expired, nil otherwise
    func get(for key: String) async -> Data?

    /// Stores data in the cache with an expiration time.
    ///
    /// - Parameters:
    ///   - data: The data to cache
    ///   - key: The cache key
    ///   - expiresIn: Time in seconds until the cache entry expires
    func set(_ data: Data, for key: String, expiresIn: TimeInterval) async

    /// Removes a specific cache entry.
    ///
    /// - Parameter key: The cache key to remove
    func remove(for key: String) async

    /// Clears all cache entries.
    func clear() async
}

/// An in-memory cache implementation with TTL support and thread safety.
///
/// This cache stores response data in memory with automatic expiration.
/// It uses a Swift actor for thread-safe access with automatic data isolation.
/// Expired entries are automatically removed when accessed.
///
/// Example:
/// ```swift
/// let cache = InMemoryNetworkCache()
/// await cache.set(data, for: "user_1", expiresIn: 300) // 5 minutes
/// if let cached = await cache.get(for: "user_1") {
///     // Use cached data
/// }
/// ```
public actor InMemoryNetworkCache: NetworkCacheProtocol {
    /// The in-memory cache storage.
    private var cache: [String: CachedData] = [:]

    /// Internal structure for storing cached data with expiration.
    private struct CachedData {
        /// The cached response data.
        let data: Data

        /// The time when this cache entry expires.
        let expiresAt: Date
    }

    /// Initializes an in-memory network cache.
    public init() {}

    /// Retrieves cached data if available and not expired.
    ///
    /// - Parameter key: The cache key
    /// - Returns: The cached data if valid, nil if not found or expired
    public func get(for key: String) -> Data? {
        guard let cached = cache[key] else { return nil }
        guard cached.expiresAt > Date() else {
            cache.removeValue(forKey: key)
            return nil
        }
        return cached.data
    }

    /// Stores data in the cache with an expiration time.
    ///
    /// - Parameters:
    ///   - data: The data to cache
    ///   - key: The cache key
    ///   - expiresIn: Expiration time in seconds
    public func set(_ data: Data, for key: String, expiresIn: TimeInterval) {
        cache[key] = CachedData(
            data: data,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
    }

    /// Removes a specific cache entry.
    ///
    /// - Parameter key: The cache key to remove
    public func remove(for key: String) {
        cache.removeValue(forKey: key)
    }

    /// Clears all cached data.
    public func clear() {
        cache.removeAll()
    }
}

/// A cache implementation that does not cache anything.
///
/// Use this when you want to disable caching entirely.
/// This is a no-op cache that always returns nil and ignores all write operations.
public class NoNetworkCache: NetworkCacheProtocol, @unchecked Sendable {
    /// Initializes a no-op cache.
    public init() {}

    /// Always returns nil.
    ///
    /// - Parameter key: The cache key (unused)
    /// - Returns: Always nil
    public func get(for key: String) async -> Data? {
        nil
    }

    /// Does nothing.
    ///
    /// - Parameters:
    ///   - data: The data (unused)
    ///   - key: The cache key (unused)
    ///   - expiresIn: The expiration time (unused)
    public func set(_ data: Data, for key: String, expiresIn: TimeInterval) async {}

    /// Does nothing.
    ///
    /// - Parameter key: The cache key (unused)
    public func remove(for key: String) async {}

    /// Does nothing.
    public func clear() async {}
}
