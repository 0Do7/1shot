import Foundation
import OneShotCore

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

    /// True when `bucket` is configured but is NOT already baked into the
    /// endpoint host (virtual-hosted style is e.g. `bucket.s3.region.amazonaws.com`).
    /// In that case the endpoint addresses the S3 *service*, so the bucket must be
    /// the first path segment (path-style: `s3.region.amazonaws.com/bucket/key`).
    var usesPathStyleBucket: Bool {
        guard let bucket, !bucket.isEmpty else { return false }
        let host = endpointURL.host ?? ""
        // Virtual-hosted: the bucket is the leading host label (`bucket.` …) or
        // the whole host. Otherwise we must insert the bucket into the path.
        return host != bucket && !host.hasPrefix("\(bucket).")
    }

    /// The S3 object URL for `key`, encoded byte-identically to the SigV4 signer's
    /// canonical URI (so the signature validates for keys with sub-delimiters),
    /// with the bucket prepended for path-style endpoints.
    func s3ObjectURL(forKey key: String) -> URL {
        url(appendingCanonicalPath: usesPathStyleBucket ? "\(bucket ?? "")/\(key)" : key)
    }

    /// The S3 bucket URL probed by the connection test: the endpoint root for
    /// virtual-hosted style, or `endpoint/bucket` for path-style.
    var s3BucketURL: URL {
        usesPathStyleBucket ? url(appendingCanonicalPath: bucket ?? "") : endpointURL
    }

    /// Append an *already-decoded* path (object key, optionally bucket-prefixed)
    /// to the endpoint using the signer's canonical segment encoding, so the URL
    /// sent on the wire matches `SigV4Signer.canonicalURIPath` exactly. Falls back
    /// to the bare endpoint only if the assembled URL is somehow unparseable.
    private func url(appendingCanonicalPath path: String) -> URL {
        let base = endpointURL.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let combined = base.isEmpty ? path : "\(base)/\(path)"
        let canonicalPath = SigV4Signer.canonicalEncode(path: "/\(combined)")
        guard var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false) else {
            return endpointURL
        }
        // `percentEncodedPath` accepts our pre-encoded canonical path verbatim;
        // assigning `.path` would re-encode the `%` escapes and corrupt them.
        components.percentEncodedPath = canonicalPath
        return components.url ?? endpointURL
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
