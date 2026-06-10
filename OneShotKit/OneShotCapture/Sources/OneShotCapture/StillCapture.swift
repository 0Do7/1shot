import CoreGraphics
import Foundation
import OneShotCore
import ScreenCaptureKit

/// Per-capture knobs (spec:capture-engine "Cursor inclusion control").
public struct CaptureOptions: Hashable, Sendable {
    /// Maps to `SCStreamConfiguration.showsCursor`.
    public var includeCursor: Bool

    public init(includeCursor: Bool = false) {
        self.includeCursor = includeCursor
    }
}

/// A completed in-memory capture (spec:capture-engine "In-memory capture
/// results" — the engine never writes a file; persistence is downstream).
///
/// `@unchecked Sendable` invariant: `image` is produced fully formed by
/// ScreenCaptureKit and never mutated afterwards — CGImage has no mutating
/// API and this struct hands out only the immutable reference, so reads from
/// any isolation domain are safe.
public struct CapturedFrame: @unchecked Sendable {
    /// Always `.image` from the still service; typed so v2 recording slots in
    /// without changing consumer interfaces (spec "Capture type extensibility").
    public let type: CaptureType
    public let image: CGImage
    /// Display the pixels came from.
    public let displayID: UInt32
    /// Display-local pixel region the image covers (image is exactly this size).
    public let pixels: PixelRect
    /// Backing scale of the source display, for downstream point math.
    public let scale: Double

    public init(type: CaptureType, image: CGImage, displayID: UInt32, pixels: PixelRect, scale: Double) {
        self.type = type
        self.image = image
        self.displayID = displayID
        self.pixels = pixels
        self.scale = scale
    }
}

/// Typed capture failures. Permission denial is distinguished from everything
/// else because S0 found -3801 after a prior in-process success signals the
/// Sequoia/Tahoe re-auth lapse, and the spec requires guided recovery — never
/// a silent failure or black image.
public enum CaptureError: Error, Hashable, Sendable {
    /// Screen Recording TCC denial: SCStreamErrorDomain code -3801
    /// ("user declined TCCs").
    case permissionDenied
    /// The requested display is no longer attached.
    case displayNotFound(UInt32)
    /// Zero-area pixel rect.
    case invalidRect
    /// Any other ScreenCaptureKit failure, preserved for diagnostics.
    case captureFailed(domain: String, code: Int)

    /// Map an error thrown by ScreenCaptureKit into the typed domain.
    public init(wrapping error: Error) {
        if let captureError = error as? CaptureError {
            self = captureError
            return
        }
        let nsError = error as NSError
        if nsError.domain == SCStreamErrorDomain, nsError.code == SCStreamError.Code.userDeclined.rawValue {
            self = .permissionDenied
        } else {
            self = .captureFailed(domain: nsError.domain, code: nsError.code)
        }
    }
}

/// Still capture via SCContentFilter + SCScreenshotManager (design D5: no
/// picker, no deprecated APIs).
public struct StillCaptureService: Sendable {
    public init() {}

    /// Capture `pixels` (display-local native pixels) from `display`. The
    /// returned image is exactly `pixels.width × pixels.height` — native
    /// density, regardless of the display's scale factor.
    public func capture(
        display: DisplayDescriptor,
        pixels: PixelRect,
        options: CaptureOptions = CaptureOptions()
    ) async throws -> CapturedFrame {
        guard pixels.width > 0, pixels.height > 0 else { throw CaptureError.invalidRect }
        let scDisplay = try await scDisplay(withID: display.id)
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        let configuration = Self.configuration(display: display, pixels: pixels, options: options)
        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            return CapturedFrame(
                type: .image,
                image: image,
                displayID: display.id,
                pixels: pixels,
                scale: display.scale
            )
        } catch {
            throw CaptureError(wrapping: error)
        }
    }

    /// Fullscreen grab of one whole display at native density.
    public func captureFullDisplay(
        _ display: DisplayDescriptor,
        options: CaptureOptions = CaptureOptions()
    ) async throws -> CapturedFrame {
        try await capture(
            display: display,
            pixels: PixelRect(x: 0, y: 0, width: display.pixelWidth, height: display.pixelHeight),
            options: options
        )
    }

    private func scDisplay(withID id: UInt32) async throws -> SCDisplay {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        } catch {
            throw CaptureError(wrapping: error)
        }
        guard let display = content.displays.first(where: { $0.displayID == id }) else {
            throw CaptureError.displayNotFound(id)
        }
        return display
    }

    /// `sourceRect` is in points in the display's local space; `width`/`height`
    /// are the output size in pixels — together they pin native density (a
    /// 100×100 px request yields a 100×100 px image on any scale factor).
    /// Internal so the mapping is unit-testable without Screen Recording.
    static func configuration(
        display: DisplayDescriptor,
        pixels: PixelRect,
        options: CaptureOptions
    ) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(
            x: Double(pixels.x) / display.scale,
            y: Double(pixels.y) / display.scale,
            width: Double(pixels.width) / display.scale,
            height: Double(pixels.height) / display.scale
        )
        configuration.width = pixels.width
        configuration.height = pixels.height
        configuration.showsCursor = options.includeCursor
        return configuration
    }
}
