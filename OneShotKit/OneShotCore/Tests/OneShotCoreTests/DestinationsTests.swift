import Foundation
import Testing
@testable import OneShotCore

private struct MockDestination: CaptureDestination {
    var descriptor: DestinationDescriptor
    var receipt = DeliveryReceipt()
    var error: DestinationError?

    func deliver(
        _ payload: DestinationPayload,
        configuration: DestinationConfiguration
    ) async throws -> DeliveryReceipt {
        try requireAccepts(payload)
        if let error { throw error }
        return receipt
    }
}

private func mock(
    id: String,
    accepts: Set<PayloadKind> = [.image],
    capabilities: DestinationCapabilities = DestinationCapabilities()
) -> MockDestination {
    MockDestination(descriptor: DestinationDescriptor(
        id: id,
        displayName: id,
        icon: "square",
        acceptedPayloads: accepts,
        capabilities: capabilities
    ))
}

// Spec: Registry-driven destination menus — registration alone makes a
// destination discoverable; menus render from descriptors only.
@Test func registry_newDestination_appearsInMenusWithoutCodeChanges() async throws {
    let registry = DestinationRegistry()
    try await registry.register(mock(id: "oneshot.clipboard", accepts: [.image, .text]))
    try await registry.register(mock(id: "vendor.custom", accepts: [.image]))

    let imageMenu = await registry.descriptors(accepting: .image)
    #expect(imageMenu.map(\.id) == ["oneshot.clipboard", "vendor.custom"]) // registration order
    #expect(imageMenu.allSatisfy { !$0.displayName.isEmpty && !$0.icon.isEmpty }) // plugin-declared

    let textMenu = await registry.descriptors(accepting: .text)
    #expect(textMenu.map(\.id) == ["oneshot.clipboard"])
}

@Test func registry_rejectsDuplicateIDs() async throws {
    let registry = DestinationRegistry()
    try await registry.register(mock(id: "oneshot.file"))
    await #expect(throws: DestinationRegistry.RegistrationError.duplicateID("oneshot.file")) {
        try await registry.register(mock(id: "oneshot.file"))
    }
}

// Spec: Typed failure surfaces to the user (name + typed reason)
@Test func deliveryError_userMessage_namesDestinationAndReason() async {
    var failing = mock(id: "oneshot.s3")
    failing.error = DestinationError(code: .network, destinationName: "oneshot.s3", reason: "connection timed out")

    do {
        _ = try await failing.deliver(
            .image(data: Data([1]), utType: "public.png", suggestedFileName: "x.png"),
            configuration: [:]
        )
        Issue.record("expected throw")
    } catch let error as DestinationError {
        #expect(error.code == .network)
        #expect(error.userMessage == "oneshot.s3: connection timed out")
    } catch {
        Issue.record("untyped error: \(error)")
    }
}

@Test func unsupportedPayload_rejectedWithTypedError() async {
    let imageOnly = mock(id: "oneshot.pin", accepts: [.image])
    await #expect(throws: DestinationError(
        code: .unsupportedPayload,
        destinationName: "oneshot.pin",
        reason: "does not accept text payloads"
    )) {
        _ = try await imageOnly.deliver(.text("hello"), configuration: [:])
    }
}

// Spec: Future destination kinds fit the contract — shareable-URL handling is
// generic: capability flag + receipt URL, no type-specific branching.
@Test func shareableURLCapability_flowsThroughReceiptGenerically() async throws {
    var cloud = mock(
        id: "future.cloud",
        capabilities: DestinationCapabilities(returnsShareableURL: true, requiresNetwork: true)
    )
    cloud.receipt = DeliveryReceipt(shareableURL: URL(string: "https://share.example/abc"))

    let receipt = try await cloud.deliver(
        .image(data: Data([1]), utType: "public.png", suggestedFileName: "x.png"),
        configuration: [:]
    )
    // Generic post-delivery rule the app applies to ANY such destination:
    let shouldCopyURL = cloud.descriptor.capabilities.returnsShareableURL && receipt.shareableURL != nil
    #expect(shouldCopyURL)
    #expect(receipt.shareableURL?.absoluteString == "https://share.example/abc")
}

@Test func descriptor_roundTripsThroughCodable() throws {
    let descriptor = DestinationDescriptor(
        id: "oneshot.s3",
        displayName: "S3 Upload",
        icon: "icloud.and.arrow.up",
        acceptedPayloads: [.image, .fileURL],
        capabilities: DestinationCapabilities(returnsShareableURL: true, requiresNetwork: true),
        configurationSchema: [
            ConfigurationField(key: "endpoint", label: "Endpoint", kind: .url, isRequired: true),
            ConfigurationField(key: "secretKey", label: "Secret Key", kind: .secret, isRequired: true),
        ]
    )
    let decoded = try JSONDecoder().decode(
        DestinationDescriptor.self,
        from: JSONEncoder().encode(descriptor)
    )
    #expect(decoded == descriptor)
    // Secrets are schema-visible so settings export can exclude them (task 2.6).
    #expect(decoded.configurationSchema.contains { $0.kind == .secret })
}
