import Foundation
import OneShotCore
import Testing
@testable import OneShotDestinations

// MARK: - Mock transport

/// Records the request it was handed and returns a scripted response (or throws
/// a scripted transport error). No socket is ever opened — this is the seam that
/// keeps the upload destination fully offline in tests (spec:output-destinations
/// "Network surface is limited to configured uploads"). `@unchecked Sendable`:
/// mutation is serialized by the single in-test deliver() call.
private final class MockUploadClient: HTTPUploadClient, @unchecked Sendable {
    private(set) var sentRequests: [HTTPUploadRequest] = []
    var response: HTTPUploadResponse
    var transportError: Error?

    init(response: HTTPUploadResponse = HTTPUploadResponse(statusCode: 200), transportError: Error? = nil) {
        self.response = response
        self.transportError = transportError
    }

    func send(_ request: HTTPUploadRequest) async throws -> HTTPUploadResponse {
        sentRequests.append(request)
        if let transportError {
            throw transportError
        }
        return response
    }

    var lastRequest: HTTPUploadRequest? {
        sentRequests.last
    }
}

private let pngPayload = DestinationPayload.image(
    data: Data([0x89, 0x50, 0x4E, 0x47]),
    utType: "public.png",
    suggestedFileName: "stripe-webhook-error.png"
)

private let fixedDate = Date(timeIntervalSince1970: 1_718_323_200) // 2024-06-14 00:00:00 UTC

private func s3Config(prefix: String? = "shots", pattern: String? = nil) -> DestinationConfiguration {
    var config: DestinationConfiguration = [
        EndpointDestination.configMode: "s3",
        EndpointDestination.configEndpointURL: "https://bucket.s3.us-east-1.amazonaws.com",
        EndpointDestination.configRegion: "us-east-1",
        EndpointDestination.configBucket: "bucket",
    ]
    if let prefix { config[EndpointDestination.configPathPrefix] = prefix }
    if let pattern { config[EndpointDestination.configPublicURLPattern] = pattern }
    return config
}

// MARK: - Upload returns a usable URL (spec scenario)

@Test func endpoint_s3Upload_putsObjectAndReturnsShareableURL() async throws {
    let client = MockUploadClient(response: HTTPUploadResponse(statusCode: 200))
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKIDEXAMPLE", secretAccessKey: "secret"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    let receipt = try await destination.deliver(
        pngPayload,
        configuration: s3Config(pattern: "https://cdn.example.com/{key}")
    )

    // A single PUT carrying exactly the encoded image bytes, direct to endpoint.
    let request = try #require(client.lastRequest)
    #expect(request.method == .put)
    #expect(request.body == Data([0x89, 0x50, 0x4E, 0x47]))
    #expect(request.url.absoluteString == "https://bucket.s3.us-east-1.amazonaws.com/shots/stripe-webhook-error.png")
    // SigV4 produced an Authorization header bound to the user's key + region.
    let auth = try #require(request.headers["Authorization"])
    #expect(auth.hasPrefix("AWS4-HMAC-SHA256 "))
    #expect(auth.contains("Credential=AKIDEXAMPLE/"))
    #expect(auth.contains("/us-east-1/s3/aws4_request"))
    #expect(request.headers["x-amz-content-sha256"] != nil)
    // The rendered public URL (per the user's pattern) is the shareable result.
    #expect(receipt.shareableURL?.absoluteString == "https://cdn.example.com/shots/stripe-webhook-error.png")
}

@Test func endpoint_publicURLDefaultsToEndpointSlashKey_whenNoPattern() async throws {
    let client = MockUploadClient()
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKID", secretAccessKey: "s"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    let receipt = try await destination.deliver(pngPayload, configuration: s3Config())
    #expect(
        receipt.shareableURL?.absoluteString
            == "https://bucket.s3.us-east-1.amazonaws.com/shots/stripe-webhook-error.png"
    )
}

// MARK: - Upload failure is honest and recoverable (spec scenario)

@Test func endpoint_403Response_failsUnauthorizedWithNoURLCopied() async throws {
    let xml = #"<?xml version="1.0"?><Error><Code>AccessDenied</Code></Error>"#
    let client = MockUploadClient(response: HTTPUploadResponse(statusCode: 403, body: Data(xml.utf8)))
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKID", secretAccessKey: "s"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    do {
        _ = try await destination.deliver(pngPayload, configuration: s3Config())
        Issue.record("expected throw")
    } catch let error as DestinationError {
        #expect(error.code == .unauthorized)
        #expect(error.destinationName == "Upload to Endpoint")
        #expect(error.reason.contains("403"))
        #expect(error.reason.contains("AccessDenied")) // folded-in S3 detail
        #expect(error.userMessage.contains("Upload to Endpoint"))
    } catch {
        Issue.record("untyped error: \(error)")
    }
}

@Test func endpoint_networkDrop_failsNetworkAndCaptureUntouched() async throws {
    let client = MockUploadClient(transportError: URLError(.networkConnectionLost))
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKID", secretAccessKey: "s"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    do {
        _ = try await destination.deliver(pngPayload, configuration: s3Config())
        Issue.record("expected throw")
    } catch let error as DestinationError {
        #expect(error.code == .network)
        #expect(error.reason.contains("connection")) // honest network cause
    } catch {
        Issue.record("untyped error: \(error)")
    }
    // The payload bytes are unchanged and re-sendable — deliver() never mutates
    // them; a fresh deliver with a healthy client succeeds.
    let healthy = MockUploadClient(response: HTTPUploadResponse(statusCode: 200))
    let destination2 = EndpointDestination(client: healthy, credentialStore: store, now: { fixedDate })
    let receipt = try await destination2.deliver(pngPayload, configuration: s3Config())
    #expect(receipt.shareableURL != nil)
}

@Test func endpoint_dnsFailure_reportsDNSCause() async throws {
    let client = MockUploadClient(transportError: URLError(.cannotFindHost))
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKID", secretAccessKey: "s"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    await #expect {
        _ = try await destination.deliver(pngPayload, configuration: s3Config())
    } throws: { error in
        guard let error = error as? DestinationError else { return false }
        return error.code == .network && error.reason.contains("DNS")
    }
}

// MARK: - Credentials live in Keychain only (spec scenario)

@Test func endpoint_credentialsResolvedFromStore_notFromExportableConfig() async throws {
    // The exported configuration (the dictionary) carries NO secret material.
    let config = s3Config()
    #expect(config["secret"] == nil)
    #expect(!config.values.contains("secret-key-material"))

    // Delivery only succeeds because the secret lives in the injected store.
    let client = MockUploadClient()
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKID", secretAccessKey: "secret-key-material"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })
    _ = try await destination.deliver(pngPayload, configuration: config)

    // The signed request likewise never leaks the raw secret (only a derived
    // signature) — the secret-access-key string appears nowhere in the request.
    let request = try #require(client.lastRequest)
    let auth = request.headers["Authorization"] ?? ""
    #expect(!auth.contains("secret-key-material"))
}

@Test func endpoint_missingCredentials_failsUnauthorizedBeforeAnyNetwork() async throws {
    let client = MockUploadClient()
    let store = InMemoryCredentialStore() // empty Keychain
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    do {
        _ = try await destination.deliver(pngPayload, configuration: s3Config())
        Issue.record("expected throw")
    } catch let error as DestinationError {
        #expect(error.code == .unauthorized)
    } catch {
        Issue.record("untyped error: \(error)")
    }
    // No request was attempted without credentials.
    #expect(client.sentRequests.isEmpty)
}

@Test func endpoint_removingDestinationDeletesKeychainItems() throws {
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKID", secretAccessKey: "s"),
    ])
    #expect(store.storedSecretCount == 1)
    try store.deleteCredentials(for: EndpointDestination.identifier)
    #expect(store.storedSecretCount == 0)
    #expect(try store.credentials(for: EndpointDestination.identifier) == nil)
}

// MARK: - Configure and test connection (spec scenario)

@Test func endpoint_connectionTest_makesMinimalAuthenticatedRequest_reportsSuccess() async throws {
    let client = MockUploadClient(response: HTTPUploadResponse(statusCode: 200))
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKID", secretAccessKey: "s"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    try await destination.testConnection(configuration: s3Config())

    let probe = try #require(client.lastRequest)
    #expect(probe.method == .head) // minimal — no object body uploaded
    #expect(probe.body.isEmpty)
    #expect(probe.headers["Authorization"]?.hasPrefix("AWS4-HMAC-SHA256") == true)
}

@Test func endpoint_connectionTest_authFailure_reportsSpecificFailureNotWorkingState() async throws {
    let client = MockUploadClient(response: HTTPUploadResponse(statusCode: 403))
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKID", secretAccessKey: "s"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    await #expect {
        try await destination.testConnection(configuration: s3Config())
    } throws: { error in
        guard let error = error as? DestinationError else { return false }
        return error.code == .unauthorized // never a stored "working" state
    }
}

// MARK: - Generic custom HTTP endpoint + presigned PUT

@Test func endpoint_customHTTP_presignedPUT_uploadsBodyWithNoCredential() async throws {
    let client = MockUploadClient(response: HTTPUploadResponse(statusCode: 200))
    let store = InMemoryCredentialStore() // presigned URL needs no stored secret
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    let presigned =
        "https://bucket.s3.amazonaws.com/uploads/x?X-Amz-Signature=abc&X-Amz-Expires=900"
    let config: DestinationConfiguration = [
        EndpointDestination.configMode: "customHTTP",
        EndpointDestination.configEndpointURL: presigned,
        EndpointDestination.configHTTPMethod: "PUT",
    ]
    let receipt = try await destination.deliver(pngPayload, configuration: config)

    let request = try #require(client.lastRequest)
    #expect(request.method == .put)
    #expect(request.body == Data([0x89, 0x50, 0x4E, 0x47]))
    // No auth header injected when no bearer token is configured/stored.
    #expect(request.headers["Authorization"] == nil)
    #expect(request.headers["Content-Type"] == "image/png")
    #expect(receipt.shareableURL != nil)
}

@Test func endpoint_customHTTP_injectsBearerTokenIntoConfiguredHeader() async throws {
    let client = MockUploadClient(response: HTTPUploadResponse(statusCode: 201))
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .bearerToken("tok-123"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store, now: { fixedDate })

    let config: DestinationConfiguration = [
        EndpointDestination.configMode: "customHTTP",
        EndpointDestination.configEndpointURL: "https://uploads.example.com/api/files",
        EndpointDestination.configHTTPMethod: "POST",
        EndpointDestination.configAuthHeaderName: "Authorization",
        EndpointDestination.configAuthHeaderPrefix: "Bearer ",
    ]
    _ = try await destination.deliver(pngPayload, configuration: config)

    let request = try #require(client.lastRequest)
    #expect(request.method == .post)
    #expect(request.headers["Authorization"] == "Bearer tok-123")
    // POST goes to the bare configured URL (no key appended).
    #expect(request.url.absoluteString == "https://uploads.example.com/api/files")
}

// MARK: - Invalid configuration

@Test func endpoint_invalidEndpointURL_failsInvalidConfiguration() async throws {
    let client = MockUploadClient()
    let store = InMemoryCredentialStore([
        EndpointDestination.identifier: .staticKey(accessKeyID: "AKID", secretAccessKey: "s"),
    ])
    let destination = EndpointDestination(client: client, credentialStore: store)

    let config: DestinationConfiguration = [
        EndpointDestination.configMode: "s3",
        EndpointDestination.configEndpointURL: "ftp://not-http",
    ]
    await #expect {
        _ = try await destination.deliver(pngPayload, configuration: config)
    } throws: { error in
        (error as? DestinationError)?.code == .invalidConfiguration
    }
    #expect(client.sentRequests.isEmpty)
}

@Test func endpoint_rejectsTextPayload() async throws {
    let client = MockUploadClient()
    let store = InMemoryCredentialStore()
    let destination = EndpointDestination(client: client, credentialStore: store)

    await #expect {
        _ = try await destination.deliver(.text("ocr"), configuration: s3Config())
    } throws: { error in
        (error as? DestinationError)?.code == .unsupportedPayload
    }
}

// MARK: - Registry + capability contract

@Test func endpoint_registersAndDeclaresShareableURLAndNetworkCapability() async throws {
    let registry = DestinationRegistry()
    let store = InMemoryCredentialStore()
    try await registry.register(EndpointDestination(client: MockUploadClient(), credentialStore: store))

    let descriptors = await registry.descriptors(accepting: .image)
    let endpoint = try #require(descriptors.first { $0.id == EndpointDestination.identifier })
    #expect(endpoint.capabilities.returnsShareableURL)
    #expect(endpoint.capabilities.requiresNetwork)
    // The secret field is declared `.secret` so the exporter omits it / the UI
    // routes it to the Keychain.
    #expect(endpoint.configurationSchema.contains { $0.kind == .secret })
}

// MARK: - Credentials codec round-trip (Keychain blob)

@Test func credentials_encodeDecodeRoundTrip_staticKeyAndBearer() throws {
    let key = EndpointCredentials.staticKey(accessKeyID: "AKID", secretAccessKey: "shhh")
    #expect(try EndpointCredentials.decoded(from: key.encoded()) == key)

    let token = EndpointCredentials.bearerToken("tok")
    #expect(try EndpointCredentials.decoded(from: token.encoded()) == token)
}
