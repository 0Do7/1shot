import CryptoKit
import Foundation

/// AWS Signature Version 4 signer for S3 `PUT object` requests (task 11.2,
/// spec:output-destinations "S3 / custom-endpoint upload destination"). This is
/// the "correct path" for direct device→endpoint S3 uploads when the user
/// supplies an access-key/secret pair: we sign the request locally and the
/// bytes go straight to the user's bucket — no presigning service, no vendor
/// relay (spec: "zero hosting cost").
///
/// The canonical-request and string-to-sign construction is the security-
/// critical part, so it is built deterministically here and asserted against
/// AWS's published worked example in tests.
///
/// References: AWS SigV4 "Authenticating Requests: Using the Authorization
/// Header" — the canonical request, scope, and signing-key derivation are
/// reproduced verbatim.
public struct SigV4Signer: Sendable {
    public let accessKeyID: String
    public let secretAccessKey: String
    public let region: String
    public let service: String

    /// `service` defaults to `s3` (the only service this destination signs for);
    /// it is injectable so the AWS worked-example vectors (`iam`, `service`) can
    /// be reproduced in tests.
    public init(accessKeyID: String, secretAccessKey: String, region: String, service: String = "s3") {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
        self.region = region
        self.service = service
    }

    /// The fully-signed header set to add to `request` for the given instant.
    /// Returns the `Authorization`, `x-amz-date`, and `x-amz-content-sha256`
    /// headers (S3 requires the content hash header). Merge these over the
    /// request's existing headers, then send.
    public func signedHeaders(
        for request: HTTPUploadRequest,
        date: Date,
        host: String
    ) -> [String: String] {
        let amzDate = Self.amzDateFormatter.string(from: date)
        let payloadHash = Self.hexSHA256(request.body)

        // Headers we sign. host + x-amz-content-sha256 + x-amz-date are the
        // minimal canonical set S3 expects; we sign exactly what we send.
        var headersToSign: [String: String] = [
            "host": host,
            "x-amz-content-sha256": payloadHash,
            "x-amz-date": amzDate,
        ]
        // Fold in any caller headers that S3 cares to sign (e.g. content-type).
        if let contentType = request.headers.first(where: { $0.key.lowercased() == "content-type" }) {
            headersToSign["content-type"] = contentType.value
        }

        let authorization = authorizationHeader(
            method: request.method.rawValue,
            url: request.url,
            headersToSign: headersToSign,
            payloadHash: payloadHash,
            amzDate: amzDate
        )

        var out = [
            "Authorization": authorization,
            "x-amz-date": amzDate,
            "x-amz-content-sha256": payloadHash,
        ]
        if let contentType = headersToSign["content-type"] {
            out["Content-Type"] = contentType
        }
        return out
    }

    /// The full `Authorization` header value for an explicit signed-header set
    /// and payload hash. Factored out so it can be exercised directly against
    /// AWS's published worked example (which signs a different header set than
    /// the S3 production path forces). `internal` for tests.
    func authorizationHeader(
        method: String,
        url: URL,
        headersToSign: [String: String],
        payloadHash: String,
        amzDate: String
    ) -> String {
        let dateStamp = String(amzDate.prefix(8))
        let canonical = Self.canonicalRequest(
            method: method,
            url: url,
            headersToSign: headersToSign,
            payloadHash: payloadHash
        )
        let signedHeaderList = headersToSign.keys.map { $0.lowercased() }.sorted().joined(separator: ";")

        let scope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            scope,
            Self.hexSHA256(Data(canonical.utf8)),
        ].joined(separator: "\n")

        let signingKey = Self.signingKey(
            secret: secretAccessKey,
            dateStamp: dateStamp,
            region: region,
            service: service
        )
        let signature = Self.hex(Self.hmac(key: signingKey, data: Data(stringToSign.utf8)))

        return "AWS4-HMAC-SHA256 "
            + "Credential=\(accessKeyID)/\(scope), "
            + "SignedHeaders=\(signedHeaderList), "
            + "Signature=\(signature)"
    }

    // MARK: Canonical request

    /// The SigV4 canonical request string. Exposed `internal` so the canonical
    /// form can be asserted directly against AWS's published vector.
    static func canonicalRequest(
        method: String,
        url: URL,
        headersToSign: [String: String],
        payloadHash: String
    ) -> String {
        let canonicalURI = canonicalURIPath(url)
        let canonicalQuery = canonicalQueryString(url)

        let sortedKeys = headersToSign.keys.map { $0.lowercased() }.sorted()
        let canonicalHeaders = sortedKeys.map { key in
            let value = headersToSign.first { $0.key.lowercased() == key }?.value ?? ""
            return "\(key):\(value.trimmingCharacters(in: .whitespaces))\n"
        }.joined()
        let signedHeaders = sortedKeys.joined(separator: ";")

        return [
            method,
            canonicalURI,
            canonicalQuery,
            canonicalHeaders,
            signedHeaders,
            payloadHash,
        ].joined(separator: "\n")
    }

    /// URI-encode each path segment per SigV4 (S3 does NOT double-encode the
    /// path; each segment is encoded once, `/` preserved as the separator).
    static func canonicalURIPath(_ url: URL) -> String {
        let path = url.path.isEmpty ? "/" : url.path
        return canonicalEncode(path: path)
    }

    /// Encode an *already-decoded* path string (e.g. an object key joined with a
    /// base path) the same way `canonicalURIPath` encodes a URL's path: each
    /// `/`-separated segment is percent-encoded with the AWS unreserved set, and
    /// the separators are preserved. Exposed so the request builder can construct
    /// the wire URL with byte-identical encoding to what gets signed — otherwise
    /// sub-delimiters (`+ & = , ; @` …) that survive `URL.path` but are encoded by
    /// the signer would produce a `SignatureDoesNotMatch` 403.
    static func canonicalEncode(path: String) -> String {
        let normalized = path.isEmpty ? "/" : path
        let segments = normalized.split(separator: "/", omittingEmptySubsequences: false)
        let encoded = segments.map { uriEncode(String($0), encodeSlash: true) }
        let joined = encoded.joined(separator: "/")
        return joined.isEmpty ? "/" : joined
    }

    static func canonicalQueryString(_ url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems, !items.isEmpty
        else {
            return ""
        }
        let encoded = items.map { item in
            "\(uriEncode(item.name, encodeSlash: true))=\(uriEncode(item.value ?? "", encodeSlash: true))"
        }
        return encoded.sorted().joined(separator: "&")
    }

    /// RFC 3986 unreserved-set encoding (AWS rule): A–Z a–z 0–9 `-_.~` are kept;
    /// everything else is percent-encoded uppercase. `/` is encoded for query
    /// values and individual path segments but is restored as the separator by
    /// the path joiner above.
    static func uriEncode(_ string: String, encodeSlash: Bool) -> String {
        var allowed = CharacterSet()
        allowed.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        if !encodeSlash {
            allowed.insert("/")
        }
        // Percent-encode manually to guarantee uppercase hex (AWS requires it;
        // `addingPercentEncoding` also yields uppercase, but we keep it explicit).
        var result = ""
        for byte in string.utf8 {
            let scalar = UnicodeScalar(byte)
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else {
                result += String(format: "%%%02X", byte)
            }
        }
        return result
    }

    // MARK: Signing-key derivation

    static func signingKey(secret: String, dateStamp: String, region: String, service: String) -> SymmetricKey {
        let kSecret = SymmetricKey(data: Data("AWS4\(secret)".utf8))
        let kDate = hmac(key: kSecret, data: Data(dateStamp.utf8))
        let kRegion = hmac(key: SymmetricKey(data: kDate), data: Data(region.utf8))
        let kService = hmac(key: SymmetricKey(data: kRegion), data: Data(service.utf8))
        let kSigning = hmac(key: SymmetricKey(data: kService), data: Data("aws4_request".utf8))
        return SymmetricKey(data: kSigning)
    }

    // MARK: Crypto primitives

    static func hmac(key: SymmetricKey, data: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
    }

    static func hexSHA256(_ data: Data) -> String {
        hex(Data(SHA256.hash(data: data)))
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Date formatting

    static let amzDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let dateStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
