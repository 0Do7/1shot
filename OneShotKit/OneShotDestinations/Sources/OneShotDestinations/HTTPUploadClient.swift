import Foundation

/// The HTTP transport seam for the upload destination (task 11.2). Putting the
/// network behind this protocol is what keeps `EndpointDestination` unit-testable
/// with a mock — no real socket is ever opened in tests, and the production
/// `URLSessionUploadClient` is the ONLY place in the destinations subsystem that
/// touches the network (spec:output-destinations "Network surface is limited to
/// configured uploads").
public protocol HTTPUploadClient: Sendable {
    /// Send `request` (with `body` as the message body, possibly empty) and
    /// return the response. Implementations MUST surface transport-level
    /// failures (DNS, TLS, connection drop) as a thrown error rather than a
    /// synthesized response, so the destination can classify them honestly.
    func send(_ request: HTTPUploadRequest) async throws -> HTTPUploadResponse
}

/// A single HTTP request the destination wants performed. Value type so it
/// crosses the actor/Sendable boundary and is trivially assertable in tests.
public struct HTTPUploadRequest: Equatable, Sendable {
    public enum Method: String, Sendable {
        case put = "PUT"
        case post = "POST"
        case get = "GET"
        case head = "HEAD"
    }

    public var method: Method
    public var url: URL
    /// Header name → value. Ordered semantics never matter to HTTP, but the
    /// dictionary keeps assertions order-independent.
    public var headers: [String: String]
    public var body: Data

    public init(method: Method, url: URL, headers: [String: String] = [:], body: Data = Data()) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

/// The response the transport observed. `body` is captured because S3 returns
/// human-meaningful XML error detail (e.g. `<Code>AccessDenied</Code>`) that we
/// fold into the typed failure reason.
public struct HTTPUploadResponse: Equatable, Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    /// 2xx — anything else is an application-level failure the destination
    /// translates into a typed error.
    public var isSuccess: Bool {
        (200 ..< 300).contains(statusCode)
    }
}

/// Production transport over `URLSession`. The only networking code in the
/// package; everything else operates on the protocol so tests stay offline.
public struct URLSessionUploadClient: HTTPUploadClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPUploadRequest) async throws -> HTTPUploadResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        // HEAD/GET carry no body; PUT/POST upload `request.body` directly
        // (device → endpoint, no vendor relay — spec: "zero hosting cost").
        if request.method == .put || request.method == .post {
            urlRequest.httpBody = request.body
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            // A non-HTTP response means the URL scheme was wrong (e.g. a file://
            // endpoint). Treat as a transport failure the caller can classify.
            throw URLError(.badServerResponse)
        }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        return HTTPUploadResponse(statusCode: http.statusCode, headers: headers, body: data)
    }
}
