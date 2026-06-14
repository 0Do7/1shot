import Foundation
import OneShotCore
import Testing
@testable import OneShotDestinations

// Regression coverage for the custom-HTTP shareable-URL contract: a POST upload
// lands where the *server* decides (reported via the Location / Content-Location
// header), so the receipt URL must come from that header or the user's URL
// pattern — never a fabricated endpoint/key, which is almost never where a POST
// object actually lands.

// MARK: - Fixtures (file-private; `private` is file-scoped so these do not
// collide with the like-shaped fixtures in EndpointDestinationTests.swift).

private final class ShareURLMockClient: HTTPUploadClient, @unchecked Sendable {
    private(set) var sentRequests: [HTTPUploadRequest] = []
    var response: HTTPUploadResponse

    init(response: HTTPUploadResponse) {
        self.response = response
    }

    func send(_ request: HTTPUploadRequest) async throws -> HTTPUploadResponse {
        sentRequests.append(request)
        return response
    }
}

private let shareURLPayload = DestinationPayload.image(
    data: Data([0x89, 0x50, 0x4E, 0x47]),
    utType: "public.png",
    suggestedFileName: "stripe-webhook-error.png"
)

private let shareURLFixedDate = Date(timeIntervalSince1970: 1_718_323_200)

// MARK: - Tests

@Test func endpoint_customHTTP_POST_relativeLocationResolvedAgainstEndpoint() async throws {
    let client = ShareURLMockClient(response: HTTPUploadResponse(
        statusCode: 201,
        headers: ["Content-Location": "/files/abc123.png"]
    ))
    let store = InMemoryCredentialStore()
    let destination = EndpointDestination(client: client, credentialStore: store, now: { shareURLFixedDate })

    let config: DestinationConfiguration = [
        EndpointDestination.configMode: "customHTTP",
        EndpointDestination.configEndpointURL: "https://uploads.example.com/api/files",
        EndpointDestination.configHTTPMethod: "POST",
    ]
    let receipt = try await destination.deliver(shareURLPayload, configuration: config)
    // Relative Content-Location is resolved against the endpoint origin.
    #expect(receipt.shareableURL?.absoluteString == "https://uploads.example.com/files/abc123.png")
}

@Test func endpoint_customHTTP_POST_noLocationNoPattern_returnsNilNotFabricatedURL() async throws {
    // A POST with neither a public-URL pattern nor a Location header gives us no
    // honest object URL — we return nil rather than copy a wrong endpoint/key URL.
    let client = ShareURLMockClient(response: HTTPUploadResponse(statusCode: 201))
    let store = InMemoryCredentialStore()
    let destination = EndpointDestination(client: client, credentialStore: store, now: { shareURLFixedDate })

    let config: DestinationConfiguration = [
        EndpointDestination.configMode: "customHTTP",
        EndpointDestination.configEndpointURL: "https://uploads.example.com/api/files",
        EndpointDestination.configHTTPMethod: "POST",
    ]
    let receipt = try await destination.deliver(shareURLPayload, configuration: config)
    #expect(receipt.shareableURL == nil)
}

@Test func endpoint_customHTTP_POST_publicURLPatternWins_overLocationHeader() async throws {
    // When the user configured an authoritative pattern, it takes precedence.
    let client = ShareURLMockClient(response: HTTPUploadResponse(
        statusCode: 201,
        headers: ["Location": "https://internal.example.com/o/abc123.png"]
    ))
    let store = InMemoryCredentialStore()
    let destination = EndpointDestination(client: client, credentialStore: store, now: { shareURLFixedDate })

    let config: DestinationConfiguration = [
        EndpointDestination.configMode: "customHTTP",
        EndpointDestination.configEndpointURL: "https://uploads.example.com/api/files",
        EndpointDestination.configHTTPMethod: "POST",
        EndpointDestination.configPathPrefix: "shots",
        EndpointDestination.configPublicURLPattern: "https://cdn.example.com/{key}",
    ]
    let receipt = try await destination.deliver(shareURLPayload, configuration: config)
    #expect(receipt.shareableURL?.absoluteString
        == "https://cdn.example.com/shots/stripe-webhook-error.png")
}

@Test func endpoint_customHTTP_PUT_noPattern_stillReturnsEndpointSlashKey() async throws {
    // A PUT lands exactly where we PUT it, so endpoint/key remains a correct
    // deterministic shareable URL even without a pattern or Location header.
    let client = ShareURLMockClient(response: HTTPUploadResponse(statusCode: 200))
    let store = InMemoryCredentialStore()
    let destination = EndpointDestination(client: client, credentialStore: store, now: { shareURLFixedDate })

    let config: DestinationConfiguration = [
        EndpointDestination.configMode: "customHTTP",
        EndpointDestination.configEndpointURL: "https://uploads.example.com/files",
        EndpointDestination.configHTTPMethod: "PUT",
        EndpointDestination.configPathPrefix: "shots",
    ]
    let receipt = try await destination.deliver(shareURLPayload, configuration: config)
    #expect(receipt.shareableURL?.absoluteString
        == "https://uploads.example.com/files/shots/stripe-webhook-error.png")
}
