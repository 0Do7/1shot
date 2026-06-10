import AppKit
import Foundation
import OneShotCore
import UniformTypeIdentifiers

/// Built-in clipboard destination (spec:output-destinations "Clipboard
/// destination"). Writes to the pasteboard only — never touches disk, which is
/// what preserves the chip's nothing-on-disk-until-decided guarantee.
public struct ClipboardDestination: CaptureDestination {
    public let descriptor = DestinationDescriptor(
        id: "oneshot.clipboard",
        displayName: "Clipboard",
        icon: "doc.on.clipboard",
        acceptedPayloads: [.image, .text]
    )

    private let pasteboardName: NSPasteboard.Name?

    public init() {
        pasteboardName = nil
    }

    /// Tests inject a private pasteboard so they never clobber the user's.
    public init(pasteboardName: NSPasteboard.Name) {
        self.pasteboardName = pasteboardName
    }

    public func deliver(
        _ payload: DestinationPayload,
        configuration: DestinationConfiguration
    ) async throws -> DeliveryReceipt {
        try requireAccepts(payload)
        let name = pasteboardName
        let written = await MainActor.run { () -> Bool in
            let pasteboard = name.map(NSPasteboard.init(name:)) ?? .general
            pasteboard.clearContents()
            switch payload {
            case let .image(data, utType, _):
                return pasteboard.setData(data, forType: NSPasteboard.PasteboardType(utType))
            case let .text(string):
                return pasteboard.setString(string, forType: .string)
            case .fileURL:
                // requireAccepts already rejected this; keep the switch exhaustive.
                return false
            }
        }

        guard written else {
            throw DestinationError(
                code: .io,
                destinationName: descriptor.displayName,
                reason: "pasteboard rejected the data"
            )
        }
        return DeliveryReceipt()
    }
}
