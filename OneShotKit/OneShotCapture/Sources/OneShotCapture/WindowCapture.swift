import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import OneShotCore
import ScreenCaptureKit

// Window capture (task 3.3, spec:capture-engine "Window capture with true
// transparent shadows", design D5: composite an alpha-preserving shadow).
//
// EMPIRICAL FINDING (probed live, macOS 26.3 / Xcode 26.5 — see the doc
// comment on `captureShadowed` for the verified recipe): ScreenCaptureKit
// renders the window-server drop shadow ONLY on the CMSampleBuffer screenshot
// path with a display-bound filter. The CGImage screenshot paths
// (`captureImage(contentFilter:configuration:)` and macOS 26's
// `captureScreenshot`) never composite the shadow, and
// `SCContentFilter(desktopIndependentWindow:)` never yields shadow pixels
// under ANY SCStreamConfiguration combination (`ignoreShadows*`,
// `capturesShadowsOnly`, oversized output, negative `sourceRect`,
// `scalesToFit`, `includeChildWindows` were all probed).

// MARK: - Pick list

extension ShareableContentService {
    /// 1shot's own bundle id — its overlays/panels are never capture candidates.
    static let ownBundleID = "com.sidequests.oneshot"

    /// Minimum candidate size in points. Layer-0 windows smaller than this are
    /// almost always invisible helper windows, not something a user aims at.
    static let minimumPickableSize = 50.0

    /// The windows the window-picking UX cycles through: normal app windows
    /// (layer 0) that are on screen, reasonably sized, and not our own.
    ///
    /// Order is preserved from the snapshot. SCShareableContent enumerates
    /// windows FRONT-TO-BACK (verified by live probe on macOS 26.3: a window
    /// ordered directly above another always appears at the lower array
    /// index), so "first frame containing the cursor" is the topmost window.
    public static func capturableWindows(from snapshot: ShareableContentSnapshot) -> [WindowDescriptor] {
        snapshot.windows.filter { window in
            window.windowLayer == 0
                && window.isOnScreen
                && window.frame.width >= minimumPickableSize
                && window.frame.height >= minimumPickableSize
                && window.owningAppBundleID != ownBundleID
        }
    }
}

// MARK: - Window capture

extension StillCaptureService {
    /// Logical points of margin reserved around the window so the shadow fits.
    /// Measured on macOS 26.3: a focused window's shadow extends ≤56pt left/
    /// right, ≤38pt above, ≤74pt below its frame; 100pt covers with headroom.
    static let shadowMargin = 100.0

    /// Transparent pixels kept around the shadow when trimming the oversized
    /// capture to the alpha extent. ≥1 guarantees the output's corner pixels
    /// are fully transparent (the corners sit outside the alpha bounding box
    /// on both axes).
    static let shadowTrimPadding = 2

    /// Capture one window via SCScreenshotManager at the native density of the
    /// display that owns (most of) the window.
    ///
    /// - `shadow: true` (default): window plus its real window-server drop
    ///   shadow over a fully transparent background — true alpha, trimmed to
    ///   the shadow's extent plus `shadowTrimPadding`.
    /// - `shadow: false`: window content only, tight bounds, no shadow pixels
    ///   (the rounded window corners remain transparent).
    public func captureWindow(
        _ window: WindowDescriptor,
        shadow: Bool = true,
        options: CaptureOptions = CaptureOptions()
    ) async throws -> CapturedFrame {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        } catch {
            throw CaptureError(wrapping: error)
        }
        guard let scWindow = content.windows.first(where: { $0.windowID == window.windowID }) else {
            throw CaptureError.windowNotFound(window.windowID)
        }
        // The window's CURRENT frame — it may have moved since enumeration.
        let frame = LogicalRect(
            x: scWindow.frame.origin.x,
            y: scWindow.frame.origin.y,
            width: scWindow.frame.width,
            height: scWindow.frame.height
        )
        guard !frame.isEmpty else { throw CaptureError.invalidRect }
        let layout = DisplayLayout(displays: ShareableContentService.descriptors(for: content.displays))
        // Native density comes from the display owning the largest share of
        // the window (spec: window fully on a secondary display → that
        // display's scale). Fallback: main display (first in layout).
        guard let display = layout.display(bestFor: frame) ?? layout.displays.first else {
            throw CaptureError.displayNotFound(0)
        }
        if shadow {
            guard let scDisplay = content.displays.first(where: { $0.displayID == display.id }) else {
                throw CaptureError.displayNotFound(display.id)
            }
            return try await captureShadowed(scWindow, on: scDisplay, frame: frame, display: display, options: options)
        }
        return try await captureTight(scWindow, frame: frame, display: display, options: options)
    }

    /// Shadow mode — the combination verified by live probe (macOS 26.3) to be
    /// the ONLY SCScreenshotManager recipe that produces the real shadow with
    /// a true alpha channel:
    ///
    /// 1. `SCContentFilter(display:including:[window])` — the window server
    ///    composites window "framing" (the drop shadow) only for display-bound
    ///    filters; `desktopIndependentWindow` never gets one.
    /// 2. `SCScreenshotManager.captureSampleBuffer` — the CMSampleBuffer path
    ///    renders the shadow exactly like an SCStream frame (pixel-identical
    ///    in probes); the CGImage paths do not.
    /// 3. `shouldBeOpaque = false` — background stays alpha-0, shadow stays
    ///    partially transparent.
    /// 4. `sourceRect` = window frame + `shadowMargin`, with `width`/`height`
    ///    set to the same rect in native pixels — room for the shadow at the
    ///    owning display's density. ScreenCaptureKit maps `sourceRect` 1:1
    ///    even where it extends past the display edge (probed): those pixels
    ///    are simply transparent.
    private func captureShadowed(
        _ window: SCWindow,
        on scDisplay: SCDisplay,
        frame: LogicalRect,
        display: DisplayDescriptor,
        options: CaptureOptions
    ) async throws -> CapturedFrame {
        let filter = SCContentFilter(display: scDisplay, including: [window])
        let (configuration, region) = Self.shadowConfiguration(windowFrame: frame, display: display, options: options)
        let sampleBuffer: CMSampleBuffer
        do {
            sampleBuffer = try await SCScreenshotManager.captureSampleBuffer(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            throw CaptureError(wrapping: error)
        }
        // Tag the image with the buffer's color space (display P3 on modern
        // Macs); fall back to sRGB inside makeImage when absent.
        let colorSpace = sampleBuffer.imageBuffer.flatMap { CVImageBufferGetColorSpace($0)?.takeUnretainedValue() }
        guard let bitmap = BGRABitmap(sampleBuffer: sampleBuffer), let full = bitmap.makeImage(colorSpace: colorSpace)
        else {
            throw CaptureError.captureFailed(domain: Self.conversionErrorDomain, code: 0)
        }
        // Trim the fixed margin down to the actual window+shadow extent.
        guard
            let bounds = bitmap.alphaBounds(padding: Self.shadowTrimPadding),
            let trimmed = full.cropping(to: CGRect(
                x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height
            ))
        else {
            // Nothing visible (fully transparent capture) — return the full
            // region rather than inventing pixels.
            return CapturedFrame(type: .image, image: full, displayID: display.id, pixels: region, scale: display.scale)
        }
        let pixels = PixelRect(
            x: region.x + bounds.x,
            y: region.y + bounds.y,
            width: bounds.width,
            height: bounds.height
        )
        return CapturedFrame(type: .image, image: trimmed, displayID: display.id, pixels: pixels, scale: display.scale)
    }

    /// Shadowless mode: `desktopIndependentWindow` filter (works even for
    /// occluded windows), tight output. The CGImage screenshot path never
    /// renders a shadow (probed); `ignoreShadowsSingleWindow` is set anyway to
    /// document intent and guard against OS behavior changes.
    private func captureTight(
        _ window: SCWindow,
        frame: LogicalRect,
        display: DisplayDescriptor,
        options: CaptureOptions
    ) async throws -> CapturedFrame {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let (configuration, region) = Self.tightConfiguration(windowFrame: frame, display: display, options: options)
        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            return CapturedFrame(
                type: .image,
                image: image,
                displayID: display.id,
                pixels: region,
                scale: display.scale
            )
        } catch {
            throw CaptureError(wrapping: error)
        }
    }

    static let conversionErrorDomain = "OneShotCapture.SampleBufferConversion"

    // MARK: Configuration mapping (internal, unit-testable without permission)

    /// Shadow-mode configuration + the display-local pixel region it captures.
    static func shadowConfiguration(
        windowFrame: LogicalRect,
        display: DisplayDescriptor,
        options: CaptureOptions
    ) -> (configuration: SCStreamConfiguration, region: PixelRect) {
        let expanded = LogicalRect(
            x: windowFrame.minX - shadowMargin,
            y: windowFrame.minY - shadowMargin,
            width: windowFrame.width + 2 * shadowMargin,
            height: windowFrame.height + 2 * shadowMargin
        )
        let region = displayLocalPixels(of: expanded, on: display)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(
            x: expanded.minX - display.logicalFrame.minX,
            y: expanded.minY - display.logicalFrame.minY,
            width: expanded.width,
            height: expanded.height
        )
        configuration.width = region.width
        configuration.height = region.height
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.shouldBeOpaque = false
        configuration.showsCursor = options.includeCursor
        return (configuration, region)
    }

    /// Shadowless configuration: output exactly the window frame in native
    /// pixels of the owning display.
    static func tightConfiguration(
        windowFrame: LogicalRect,
        display: DisplayDescriptor,
        options: CaptureOptions
    ) -> (configuration: SCStreamConfiguration, region: PixelRect) {
        let region = displayLocalPixels(of: windowFrame, on: display)
        let configuration = SCStreamConfiguration()
        configuration.width = region.width
        configuration.height = region.height
        configuration.ignoreShadowsSingleWindow = true
        configuration.shouldBeOpaque = false
        configuration.showsCursor = options.includeCursor
        return (configuration, region)
    }

    /// Global logical rect → display-local pixels, UNCLAMPED (unlike
    /// `DisplayDescriptor.pixelRect(for:)`): a window hanging off the display
    /// edge is still captured whole by the window filters, so the region may
    /// have negative origin or extend past the display.
    static func displayLocalPixels(of logical: LogicalRect, on display: DisplayDescriptor) -> PixelRect {
        PixelRect(
            x: Int(((logical.minX - display.logicalFrame.minX) * display.scale).rounded()),
            y: Int(((logical.minY - display.logicalFrame.minY) * display.scale).rounded()),
            width: Int((logical.width * display.scale).rounded()),
            height: Int((logical.height * display.scale).rounded())
        )
    }
}

// MARK: - BGRA bitmap

/// Tightly packed copy of a 32BGRA sample buffer, with alpha inspection used
/// to trim the shadow capture. Internal + value-typed so the trim math is
/// unit-testable without ScreenCaptureKit.
struct BGRABitmap {
    var data: Data
    var width: Int
    var height: Int

    init(data: Data, width: Int, height: Int) {
        self.data = data
        self.width = width
        self.height = height
    }

    init?(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = sampleBuffer.imageBuffer,
              CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA
        else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rowBytes = width * 4
        var data = Data(count: rowBytes * height)
        data.withUnsafeMutableBytes { (destination: UnsafeMutableRawBufferPointer) in
            guard let destinationBase = destination.baseAddress else { return }
            for row in 0 ..< height {
                memcpy(destinationBase + row * rowBytes, base + row * stride, rowBytes)
            }
        }
        self.init(data: data, width: width, height: height)
    }

    func alpha(x: Int, y: Int) -> UInt8 {
        // BGRA memory order: alpha is the 4th byte of each pixel.
        data[(y * width + x) * 4 + 3]
    }

    /// Bounding box of all pixels with alpha > 0, expanded by `padding` and
    /// clamped to the bitmap. Nil when fully transparent.
    func alphaBounds(padding: Int) -> PixelRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0 ..< height {
                let row = base + y * width * 4
                for x in 0 ..< width where row[x * 4 + 3] > 0 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    maxY = y
                }
            }
        }
        guard maxX >= 0 else { return nil }
        let x0 = Swift.max(0, minX - padding)
        let y0 = Swift.max(0, minY - padding)
        let x1 = Swift.min(width, maxX + 1 + padding)
        let y1 = Swift.min(height, maxY + 1 + padding)
        return PixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// Wrap the bytes in a CGImage (premultiplied BGRA little-endian, tagged
    /// with the buffer's color space when derivable, else sRGB).
    func makeImage(colorSpace: CGColorSpace? = nil) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        let space = colorSpace
            ?? CGColorSpace(name: CGColorSpace.sRGB)
            ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
