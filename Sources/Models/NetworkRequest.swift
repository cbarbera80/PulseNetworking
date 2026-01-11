import Foundation

/// Represents an HTTP network request with all necessary configuration.
///
/// `NetworkRequest` encapsulates the details needed to perform an HTTP request,
/// including the URL, HTTP method, headers, body, and timeout settings.
public struct NetworkRequest: Sendable {
    /// The URL endpoint for the request.
    public let url: URL

    /// The HTTP method to use (GET, POST, PUT, etc.). Defaults to GET.
    public var method: HTTPMethod = .get

    /// HTTP headers to include in the request. Empty by default.
    public var headers: [String: String] = [:]

    /// Optional request body data. Typically used for POST and PUT requests.
    public var body: Data?

    /// Request timeout interval in seconds. Defaults to 30 seconds.
    public var timeoutInterval: TimeInterval = 30

    /// Initializes a new network request.
    ///
    /// - Parameters:
    ///   - url: The URL endpoint for the request
    ///   - method: The HTTP method (defaults to GET)
    ///   - headers: Dictionary of HTTP headers (defaults to empty)
    ///   - body: Optional request body data
    ///   - timeoutInterval: Request timeout in seconds (defaults to 30)
    public init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval = 30
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
    }

    /// Converts this network request to a URLRequest.
    ///
    /// - Returns: A URLRequest object configured with the properties of this network request
    func toURLRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        request.timeoutInterval = timeoutInterval
        return request
    }

    /// Generates a unique cache key for this request.
    ///
    /// The cache key is based on the HTTP method and URL, allowing cached responses
    /// to be retrieved for identical requests.
    ///
    /// - Returns: A string cache key in the format "METHOD_url"
    func cacheKey() -> String {
        "\(method.rawValue)_\(url.absoluteString)"
    }
}

/// Enumeration of standard HTTP methods.
///
/// Includes all common HTTP methods used for REST APIs and web services.
public enum HTTPMethod: String, Sendable {
    /// GET request - retrieve data
    case get = "GET"

    /// POST request - create new data
    case post = "POST"

    /// PUT request - replace entire resource
    case put = "PUT"

    /// PATCH request - partially update resource
    case patch = "PATCH"

    /// DELETE request - remove resource
    case delete = "DELETE"

    /// HEAD request - like GET but without response body
    case head = "HEAD"

    /// OPTIONS request - describe communication options
    case options = "OPTIONS"
}
