import Foundation
import OneShotCore

/// Direct device→endpoint upload destination (task 11.2, spec:output-destinations
/// "S3 / custom-endpoint upload destination"). Uploads go straight from the
/// user's machine to the user's endpoint — the app vendor operates no relay,
/// proxy, or storage (spec: "zero hosting cost"). Credentials live ONLY in the
/// injected `EndpointCredentialStore` (the Keychain in production) and are never
/// part of `AppSettings`, so they are excluded from settings export by
/// construction.
///
/// Two upload modes, selected by the non-secret `mode` configuration field:
/// - `.s3`: SigV4-sign a `PUT object` against the user's S3-compatible endpoint
///   (endpoint URL, region, bucket, prefix), using a `.staticKey` credential.
/// - `.customHTTP`: a generic `PUT`/`POST` to a configured URL with caller-
///   supplied headers; a `.bearerToken` credential (if present) is injected into
///   a configured auth header. The simplest correct S3 path — a presigned `PUT`
///   URL minted out-of-band — is just a `.customHTTP` `PUT` with no credential.
///
/// The HTTP transport is injected (`HTTPUploadClient`) so tests run fully
/// offline; `URLSessionUploadClient` is the only code that opens a socket.
public struct EndpointDestination: CaptureDestination {
    // Non-secret configuration keys (these ARE part of settings export).
    public static let configMode = "mode"
    public static let configEndpointURL = "endpointURL"
    public static let configRegion = "region"
    public static let configBucket = "bucket"
    public static let configPathPrefix = "pathPrefix"
    public static let configPublicURLPattern = "publicURLPattern"
    /// For `.customHTTP`: the HTTP method ("PUT" default, or "POST").
    public static let configHTTPMethod = "httpMethod"
    /// For `.customHTTP`: header carrying a `.bearerToken`, e.g. "Authorization".
    public static let configAuthHeaderName = "authHeaderName"
    /// For `.customHTTP`: prefix prepended to the token in the auth header,
    /// e.g. "Bearer " → "Authorization: Bearer <token>". Empty = raw token.
    public static let configAuthHeaderPrefix = "authHeaderPrefix"

    public enum Mode: String, Sendable {
        case s3
        case customHTTP
    }

    public let descriptor = DestinationDescriptor(
        id: EndpointDestination.identifier,
        displayName: "Upload to Endpoint",
        icon: "externaldrive.badge.icloud",
        acceptedPayloads: [.image, .fileURL],
        // Direct upload IS the only sanctioned network destination, and it
        // hands back a URL the generic machinery copies + toasts.
        capabilities: DestinationCapabilities(returnsShareableURL: true, requiresNetwork: true),
        configurationSchema: [
            ConfigurationField(key: configMode, label: "Mode", kind: .string, isRequired: true),
            ConfigurationField(key: configEndpointURL, label: "Endpoint URL", kind: .url, isRequired: true),
            ConfigurationField(key: configRegion, label: "Region", kind: .string),
            ConfigurationField(key: configBucket, label: "Bucket", kind: .string),
            ConfigurationField(key: configPathPrefix, label: "Path prefix", kind: .string),
            ConfigurationField(key: configPublicURLPattern, label: "Public URL pattern", kind: .string),
            ConfigurationField(key: configHTTPMethod, label: "HTTP method", kind: .string),
            ConfigurationField(key: configAuthHeaderName, label: "Auth header", kind: .string),
            ConfigurationField(key: configAuthHeaderPrefix, label: "Auth header prefix", kind: .string),
            // The secret itself is declared as `.secret` so the settings UI
            // routes it to the Keychain and the exporter omits it.
            ConfigurationField(key: "secret", label: "Credential", kind: .secret),
        ]
    )

    public static let identifier = "oneshot.endpoint"

    private let client: any HTTPUploadClient
    private let credentialStore: any EndpointCredentialStore
    private let now: @Sendable () -> Date

    /// Production initializer: real URLSession transport + the injected Keychain
    /// store (the concrete Keychain implementation lives in the app layer).
    public init(credentialStore: any EndpointCredentialStore) {
        self.init(
            client: URLSessionUploadClient(),
            credentialStore: credentialStore
        )
    }

    /// Test/host seam: inject the transport, the credential store, and the clock
    /// (so SigV4 signatures are deterministic in tests).
    public init(
        client: any HTTPUploadClient,
        credentialStore: any EndpointCredentialStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.credentialStore = credentialStore
        self.now = now
    }

    // MARK: Delivery

    public func deliver(
        _ payload: DestinationPayload,
        configuration: DestinationConfiguration
    ) async throws -> DeliveryReceipt {
        try requireAccepts(payload)
        let config = try EndpointConfig(configuration)
        let object = try objectBytes(from: payload, prefix: config.pathPrefix)

        let request = try buildRequest(config: config, object: object)
        let response = try await send(request, destinationName: descriptor.displayName)

        guard response.isSuccess else {
            // No partial-success URL is ever copied (spec: "no partial-success
            // URL is copied"): we only render the public URL after a 2xx.
            throw failure(for: response, config: config)
        }

        let publicURL = config.renderedPublicURL(objectKey: object.key)
        return DeliveryReceipt(shareableURL: publicURL)
    }

    // MARK: Connection test

    /// Minimal authenticated request against the endpoint (spec: "Configure and
    /// test connection"). For S3 this is a signed `HEAD` on the bucket; for a
    /// custom endpoint it is a `HEAD`/`GET` on the configured URL. Returns the
    /// specific failure (DNS, auth, bucket access, TLS) — never a stored
    /// "working" state on an unverified endpoint.
    public func testConnection(configuration: DestinationConfiguration) async throws {
        let config = try EndpointConfig(configuration)
        let probe: HTTPUploadRequest
        switch config.mode {
        case .s3:
            // HEAD the bucket root — a minimal authenticated request.
            let url = config.endpointURL
            var headers: [String: String] = [:]
            let credentials = try resolveCredentials()
            if case let .staticKey(accessKeyID, secretAccessKey) = credentials {
                let signer = SigV4Signer(
                    accessKeyID: accessKeyID,
                    secretAccessKey: secretAccessKey,
                    region: config.region ?? "us-east-1"
                )
                let unsigned = HTTPUploadRequest(method: .head, url: url)
                headers = signer.signedHeaders(for: unsigned, date: now(), host: host(of: url))
            }
            probe = HTTPUploadRequest(method: .head, url: url, headers: headers)
        case .customHTTP:
            var headers: [String: String] = [:]
            applyBearerHeaderIfAny(into: &headers, config: config)
            probe = HTTPUploadRequest(method: .head, url: config.endpointURL, headers: headers)
        }

        let response = try await send(probe, destinationName: descriptor.displayName)
        guard response.isSuccess else {
            throw failure(for: response, config: config)
        }
    }

    // MARK: Request construction

    private func buildRequest(config: EndpointConfig, object: UploadObject) throws -> HTTPUploadRequest {
        switch config.mode {
        case .s3:
            try buildS3Request(config: config, object: object)
        case .customHTTP:
            buildCustomRequest(config: config, object: object)
        }
    }

    private func buildS3Request(config: EndpointConfig, object: UploadObject) throws -> HTTPUploadRequest {
        let credentials = try resolveCredentials()
        guard case let .staticKey(accessKeyID, secretAccessKey) = credentials else {
            throw DestinationError(
                code: .invalidConfiguration,
                destinationName: descriptor.displayName,
                reason: "S3 mode requires an access-key / secret-key credential"
            )
        }
        // Object URL = endpoint + "/" + key (the endpoint already encodes the
        // bucket for virtual-hosted style, or the path for path style).
        let objectURL = config.endpointURL.appendingPathComponent(object.key)
        let signer = SigV4Signer(
            accessKeyID: accessKeyID,
            secretAccessKey: secretAccessKey,
            region: config.region ?? "us-east-1"
        )
        var unsigned = HTTPUploadRequest(
            method: .put,
            url: objectURL,
            headers: ["Content-Type": object.contentType],
            body: object.data
        )
        let signed = signer.signedHeaders(for: unsigned, date: now(), host: host(of: objectURL))
        unsigned.headers.merge(signed) { _, new in new }
        return unsigned
    }

    private func buildCustomRequest(config: EndpointConfig, object: UploadObject) -> HTTPUploadRequest {
        // The object lands at endpoint/key for PUT (presigned or pre-shared);
        // POST endpoints typically accept the body at the bare URL.
        let method = config.httpMethod
        let url = method == .put ? config.endpointURL.appendingPathComponent(object.key) : config.endpointURL
        var headers = ["Content-Type": object.contentType]
        applyBearerHeaderIfAny(into: &headers, config: config)
        return HTTPUploadRequest(method: method, url: url, headers: headers, body: object.data)
    }

    /// Inject a `.bearerToken` credential into the configured auth header (if a
    /// token exists and an auth-header name is configured). For a presigned-URL
    /// `PUT` there is typically no credential — the signature is in the URL.
    private func applyBearerHeaderIfAny(into headers: inout [String: String], config: EndpointConfig) {
        guard let headerName = config.authHeaderName,
              let credentials = try? resolveCredentials(),
              case let .bearerToken(token) = credentials
        else {
            return
        }
        headers[headerName] = config.authHeaderPrefix + token
    }

    // MARK: Helpers

    private func resolveCredentials() throws -> EndpointCredentials {
        guard let credentials = try credentialStore.credentials(for: descriptor.id) else {
            throw DestinationError(
                code: .unauthorized,
                destinationName: descriptor.displayName,
                reason: "no credentials stored for this endpoint"
            )
        }
        return credentials
    }

    private func objectBytes(from payload: DestinationPayload, prefix: String?) throws -> UploadObject {
        switch payload {
        case let .image(data, utType, suggestedFileName):
            UploadObject(
                data: data,
                fileName: suggestedFileName,
                contentType: Self.mimeType(forUTType: utType, fileName: suggestedFileName),
                prefix: prefix
            )
        case let .fileURL(source):
            try UploadObject(
                data: readData(at: source),
                fileName: source.lastPathComponent,
                contentType: Self.mimeType(forUTType: nil, fileName: source.lastPathComponent),
                prefix: prefix
            )
        case .text:
            // requireAccepts already rejected this; keep the switch exhaustive.
            throw DestinationError(
                code: .unsupportedPayload,
                destinationName: descriptor.displayName,
                reason: "does not accept text payloads"
            )
        }
    }

    private func readData(at source: URL) throws -> Data {
        do {
            return try Data(contentsOf: source)
        } catch {
            throw DestinationError(
                code: .targetMissing,
                destinationName: descriptor.displayName,
                reason: "source file \(source.lastPathComponent) is unreadable"
            )
        }
    }

    private func send(
        _ request: HTTPUploadRequest,
        destinationName: String
    ) async throws -> HTTPUploadResponse {
        do {
            return try await client.send(request)
        } catch let error as DestinationError {
            throw error
        } catch {
            // Transport-level failure (DNS, TLS, connection drop) — honest
            // network classification, capture is untouched and re-sendable.
            throw DestinationError(
                code: .network,
                destinationName: destinationName,
                reason: Self.networkReason(for: error)
            )
        }
    }

    /// Map an HTTP error status into the typed destination error, surfacing the
    /// specific cause (auth vs. bucket access vs. server). S3 returns XML with a
    /// `<Code>` element we fold into the reason for actionable detail.
    private func failure(for response: HTTPUploadResponse, config: EndpointConfig) -> DestinationError {
        let detail = Self.s3ErrorCode(in: response.body).map { " (\($0))" } ?? ""
        switch response.statusCode {
        case 401, 403:
            return DestinationError(
                code: .unauthorized,
                destinationName: descriptor.displayName,
                reason: "endpoint rejected the credentials — HTTP \(response.statusCode)\(detail)"
            )
        case 404:
            return DestinationError(
                code: .targetMissing,
                destinationName: descriptor.displayName,
                reason: "bucket or path not found — HTTP \(response.statusCode)\(detail)"
            )
        default:
            return DestinationError(
                code: .io,
                destinationName: descriptor.displayName,
                reason: "upload failed — HTTP \(response.statusCode)\(detail)"
            )
        }
    }

    private func host(of url: URL) -> String {
        guard let host = url.host else { return "" }
        if let port = url.port {
            return "\(host):\(port)"
        }
        return host
    }

    // MARK: Static utilities

    static func networkReason(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return error.localizedDescription
        }
        switch urlError.code {
        case .cannotFindHost, .dnsLookupFailed:
            return "could not resolve the endpoint host (DNS)"
        case .secureConnectionFailed, .serverCertificateUntrusted,
             .serverCertificateHasBadDate, .serverCertificateNotYetValid:
            return "TLS/certificate error connecting to the endpoint"
        case .notConnectedToInternet, .networkConnectionLost, .timedOut:
            return "network connection to the endpoint was lost"
        default:
            return urlError.localizedDescription
        }
    }

    /// Extract `<Code>…</Code>` from an S3 XML error body, if present.
    static func s3ErrorCode(in body: Data) -> String? {
        guard let xml = String(data: body, encoding: .utf8),
              let open = xml.range(of: "<Code>"),
              let close = xml.range(of: "</Code>"),
              open.upperBound <= close.lowerBound
        else {
            return nil
        }
        let code = String(xml[open.upperBound ..< close.lowerBound])
        return code.isEmpty ? nil : code
    }

    static func mimeType(forUTType utType: String?, fileName: String) -> String {
        if let utType {
            switch utType {
            case "public.png": return "image/png"
            case "public.jpeg": return "image/jpeg"
            case "public.heic", "public.heif": return "image/heic"
            case "org.webmproject.webp": return "image/webp"
            default: break
            }
        }
        switch (fileName as NSString).pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "heic", "heif": return "image/heic"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Resolved configuration

/// The non-secret config parsed and validated once per delivery. Parsing here
/// (not in `deliver`) keeps the typed-error surface centralized.
struct EndpointConfig {
    let mode: EndpointDestination.Mode
    let endpointURL: URL
    let region: String?
    let bucket: String?
    let pathPrefix: String?
    let publicURLPattern: String?
    let httpMethod: HTTPUploadRequest.Method
    let authHeaderName: String?
    let authHeaderPrefix: String

    init(_ configuration: DestinationConfiguration) throws {
        guard let modeRaw = configuration[EndpointDestination.configMode],
              let mode = EndpointDestination.Mode(rawValue: modeRaw)
        else {
            throw DestinationError(
                code: .invalidConfiguration,
                destinationName: "Upload to Endpoint",
                reason: "missing or unknown upload mode"
            )
        }
        guard let urlString = configuration[EndpointDestination.configEndpointURL],
              !urlString.isEmpty,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host != nil
        else {
            throw DestinationError(
                code: .invalidConfiguration,
                destinationName: "Upload to Endpoint",
                reason: "endpoint URL is missing or not a valid http(s) URL"
            )
        }
        self.mode = mode
        endpointURL = url
        region = configuration[EndpointDestination.configRegion]
        bucket = configuration[EndpointDestination.configBucket]
        pathPrefix = configuration[EndpointDestination.configPathPrefix]
        publicURLPattern = configuration[EndpointDestination.configPublicURLPattern]
        httpMethod = HTTPUploadRequest.Method(
            rawValue: (configuration[EndpointDestination.configHTTPMethod] ?? "PUT").uppercased()
        ) ?? .put
        authHeaderName = configuration[EndpointDestination.configAuthHeaderName]
        authHeaderPrefix = configuration[EndpointDestination.configAuthHeaderPrefix] ?? ""
    }

    /// Render the object's public URL from the user's pattern. Tokens:
    /// `{endpoint}`, `{bucket}`, `{region}`, `{key}`. When no pattern is set,
    /// fall back to `endpoint/key`.
    func renderedPublicURL(objectKey: String) -> URL? {
        guard let pattern = publicURLPattern, !pattern.isEmpty else {
            return endpointURL.appendingPathComponent(objectKey)
        }
        var rendered = pattern
        rendered = rendered.replacingOccurrences(of: "{endpoint}", with: endpointURL.absoluteString)
        rendered = rendered.replacingOccurrences(of: "{bucket}", with: bucket ?? "")
        rendered = rendered.replacingOccurrences(of: "{region}", with: region ?? "")
        rendered = rendered.replacingOccurrences(of: "{key}", with: objectKey)
        return URL(string: rendered)
    }
}

// MARK: - Upload object

/// The bytes + derived object key for one upload.
struct UploadObject {
    let data: Data
    let contentType: String
    /// The object key (prefix + filename), used to build the request URL and
    /// render the public URL. Always slash-joined, prefix sanitized of a
    /// leading/trailing slash so we don't emit `//`.
    let key: String

    init(data: Data, fileName: String, contentType: String, prefix: String?) {
        self.data = data
        self.contentType = contentType
        let cleanedPrefix = (prefix ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if cleanedPrefix.isEmpty {
            key = fileName
        } else {
            key = "\(cleanedPrefix)/\(fileName)"
        }
    }
}
