import Foundation

/// Secret material for an upload destination. Lives ONLY in the Keychain
/// (spec:output-destinations "Credentials live in Keychain only") — it is never
/// part of `AppSettings`, so it cannot ride along in the settings export/import
/// (Core's `AppSettings` documents destination secrets as Keychain-only by
/// construction). Non-secret config (endpoint URL, region, bucket, prefix, URL
/// pattern) lives in the destination's `DestinationConfiguration` and IS exported.
///
/// Two credential shapes are supported:
/// - `staticKey`: an S3 access-key / secret-key pair, signed with SigV4 at
///   upload time (the destination never persists a signed request).
/// - `presignedHeader`: a single opaque secret sent as an HTTP header value
///   (e.g. a bearer token, or a pre-shared key for a generic custom endpoint).
public enum EndpointCredentials: Equatable, Sendable {
    /// AWS-style access key id + secret access key (SigV4).
    case staticKey(accessKeyID: String, secretAccessKey: String)
    /// An opaque token placed verbatim into a configured header.
    case bearerToken(String)

    /// JSON for Keychain storage. The Keychain stores the *encoded blob*; the
    /// plaintext fields are never written anywhere else.
    func encoded() throws -> Data {
        try JSONEncoder().encode(CredentialWire(self))
    }

    static func decoded(from data: Data) throws -> EndpointCredentials {
        try JSONDecoder().decode(CredentialWire.self, from: data).credentials
    }
}

/// Codable bridge — keeps `EndpointCredentials` a clean enum while persisting a
/// tagged shape that survives adding future credential kinds.
private struct CredentialWire: Codable {
    enum Kind: String, Codable { case staticKey, bearerToken }
    var kind: Kind
    var accessKeyID: String?
    var secretAccessKey: String?
    var token: String?

    init(_ credentials: EndpointCredentials) {
        switch credentials {
        case let .staticKey(accessKeyID, secretAccessKey):
            kind = .staticKey
            self.accessKeyID = accessKeyID
            self.secretAccessKey = secretAccessKey
        case let .bearerToken(token):
            kind = .bearerToken
            self.token = token
        }
    }

    var credentials: EndpointCredentials {
        switch kind {
        case .staticKey:
            .staticKey(accessKeyID: accessKeyID ?? "", secretAccessKey: secretAccessKey ?? "")
        case .bearerToken:
            .bearerToken(token ?? "")
        }
    }
}

/// Storage seam for endpoint secrets. The production implementation (real
/// `SecItem*` Keychain) lives in the app layer; this package ships only the
/// protocol and an in-memory fake so the destination is testable without
/// touching the user's Keychain — exactly the licensing lane's `TrialOriginStore`
/// pattern.
public protocol EndpointCredentialStore: Sendable {
    /// Read the stored credentials for `destinationID`, or `nil` if none.
    func credentials(for destinationID: String) throws -> EndpointCredentials?
    /// Store (overwriting) the credentials for `destinationID`.
    func store(_ credentials: EndpointCredentials, for destinationID: String) throws
    /// Delete the credentials for `destinationID` (spec: "removing the
    /// destination deletes its Keychain items"). A no-op if absent.
    func deleteCredentials(for destinationID: String) throws
}

/// An in-memory `EndpointCredentialStore` for tests and a reference for the
/// app-layer Keychain implementation. `@unchecked Sendable`: the dictionary is
/// guarded by a lock.
public final class InMemoryCredentialStore: EndpointCredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: EndpointCredentials]

    public init(_ initial: [String: EndpointCredentials] = [:]) {
        storage = initial
    }

    public func credentials(for destinationID: String) throws -> EndpointCredentials? {
        lock.lock(); defer { lock.unlock() }
        return storage[destinationID]
    }

    public func store(_ credentials: EndpointCredentials, for destinationID: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[destinationID] = credentials
    }

    public func deleteCredentials(for destinationID: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[destinationID] = nil
    }

    /// Test/audit affordance: how many secrets are currently held (lets tests
    /// assert that removal actually clears Keychain material).
    public var storedSecretCount: Int {
        lock.lock(); defer { lock.unlock() }
        return storage.count
    }
}
