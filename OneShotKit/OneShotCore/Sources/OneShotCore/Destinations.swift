import Foundation

// Destination plugin contract (task 2.5, spec:output-destinations "Destination
// plugin contract"). Chip/editor/capture code consumes ONLY this contract and
// the registry — adding a destination (incl. future hosted-cloud/LLM drop-ins,
// docs/deferred/) never touches their code.

// MARK: Payloads

public enum PayloadKind: String, Codable, CaseIterable, Sendable {
    case image, fileURL, text
}

public enum DestinationPayload: Sendable {
    /// Encoded image bytes plus the name a file-materializing destination should use.
    case image(data: Data, utType: String, suggestedFileName: String)
    case fileURL(URL)
    case text(String)

    public var kind: PayloadKind {
        switch self {
        case .image: .image
        case .fileURL: .fileURL
        case .text: .text
        }
    }
}

// MARK: Descriptor

public struct DestinationCapabilities: Codable, Hashable, Sendable {
    /// Delivery yields a URL others can open; generic machinery puts it on the
    /// clipboard and toasts it — no per-destination special-casing.
    public var returnsShareableURL: Bool
    /// Used by offline checks and the zero-network privacy audit (design D12).
    public var requiresNetwork: Bool

    public init(returnsShareableURL: Bool = false, requiresNetwork: Bool = false) {
        self.returnsShareableURL = returnsShareableURL
        self.requiresNetwork = requiresNetwork
    }
}

/// One field of a destination's configuration UI, rendered generically.
public struct ConfigurationField: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case string, url, boolean
        /// Stored in the Keychain only; excluded from settings export (spec:
        /// utilities-settings "import/export excluding secrets").
        case secret
    }

    public var key: String
    public var label: String
    public var kind: Kind
    public var isRequired: Bool

    public init(key: String, label: String, kind: Kind, isRequired: Bool = false) {
        self.key = key
        self.label = label
        self.kind = kind
        self.isRequired = isRequired
    }
}

public struct DestinationDescriptor: Codable, Hashable, Sendable {
    /// Stable forever (persisted in settings/shortcuts); reverse-dot style,
    /// e.g. "oneshot.clipboard".
    public var id: String
    public var displayName: String
    /// SF Symbol name (or asset name) — the plugin declares its own icon.
    public var icon: String
    public var acceptedPayloads: Set<PayloadKind>
    public var capabilities: DestinationCapabilities
    /// Empty = no configuration UI.
    public var configurationSchema: [ConfigurationField]

    public init(
        id: String,
        displayName: String,
        icon: String,
        acceptedPayloads: Set<PayloadKind>,
        capabilities: DestinationCapabilities = DestinationCapabilities(),
        configurationSchema: [ConfigurationField] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
        self.acceptedPayloads = acceptedPayloads
        self.capabilities = capabilities
        self.configurationSchema = configurationSchema
    }
}

// MARK: Delivery

/// Non-secret configuration values keyed by `ConfigurationField.key`; secrets
/// are resolved by the app from the Keychain and injected the same way at
/// delivery time (they never persist here).
public typealias DestinationConfiguration = [String: String]

public struct DeliveryReceipt: Sendable {
    /// Set when `capabilities.returnsShareableURL`.
    public var shareableURL: URL?
    /// File the destination materialized, if any (drives "Reveal in Finder").
    public var materializedFileURL: URL?

    public init(shareableURL: URL? = nil, materializedFileURL: URL? = nil) {
        self.shareableURL = shareableURL
        self.materializedFileURL = materializedFileURL
    }
}

/// Typed failure surface: every user-visible delivery error names the
/// destination and the reason; the source capture always remains re-sendable
/// (delivery never consumes or mutates the capture).
public struct DestinationError: Error, Equatable, Sendable {
    public enum Code: String, Sendable {
        case unsupportedPayload
        case invalidConfiguration
        case targetMissing
        case unauthorized
        case network
        case io
        case cancelled
    }

    public var code: Code
    public var destinationName: String
    public var reason: String

    public init(code: Code, destinationName: String, reason: String) {
        self.code = code
        self.destinationName = destinationName
        self.reason = reason
    }

    /// The user-facing message (spec: contains destination name + typed reason).
    public var userMessage: String {
        "\(destinationName): \(reason)"
    }
}

// MARK: Protocol

public protocol CaptureDestination: Sendable {
    var descriptor: DestinationDescriptor { get }
    /// Deliver the payload. Throws `DestinationError`; success returns a receipt.
    func deliver(
        _ payload: DestinationPayload,
        configuration: DestinationConfiguration
    ) async throws -> DeliveryReceipt
}

public extension CaptureDestination {
    /// Shared guard: reject payloads the descriptor doesn't accept, with the
    /// spec-mandated typed error.
    func requireAccepts(_ payload: DestinationPayload) throws {
        guard descriptor.acceptedPayloads.contains(payload.kind) else {
            throw DestinationError(
                code: .unsupportedPayload,
                destinationName: descriptor.displayName,
                reason: "does not accept \(payload.kind.rawValue) payloads"
            )
        }
    }
}

// MARK: Registry

/// Discovery point for all destinations. Chip/editor menus render from
/// `descriptors(accepting:)`; nothing else in the app knows concrete types.
public actor DestinationRegistry {
    public enum RegistrationError: Error, Equatable {
        case duplicateID(String)
    }

    private var ordered: [any CaptureDestination] = []
    private var byID: [String: any CaptureDestination] = [:]

    public init() {}

    public func register(_ destination: any CaptureDestination) throws {
        let id = destination.descriptor.id
        guard byID[id] == nil else { throw RegistrationError.duplicateID(id) }
        byID[id] = destination
        ordered.append(destination)
    }

    public func destination(withID id: String) -> (any CaptureDestination)? {
        byID[id]
    }

    public func all() -> [any CaptureDestination] {
        ordered
    }

    /// Menu source: registration order, filtered by payload compatibility.
    public func descriptors(accepting kind: PayloadKind) -> [DestinationDescriptor] {
        ordered.map(\.descriptor).filter { $0.acceptedPayloads.contains(kind) }
    }
}
