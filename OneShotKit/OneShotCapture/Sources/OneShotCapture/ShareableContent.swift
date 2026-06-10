import CoreGraphics
import Foundation
import OneShotCore
import ScreenCaptureKit

/// Portable description of one capturable window, built from SCWindow at
/// enumeration time. Downstream surfaces (window-pick overlay, auto-namer
/// provenance) consume this value type, never SCWindow itself.
public struct WindowDescriptor: Codable, Hashable, Sendable {
    /// CGWindowID — stable for the window's lifetime.
    public var windowID: UInt32
    public var title: String?
    public var owningAppBundleID: String?
    public var owningAppName: String?
    /// Global logical points, CG orientation (top-left origin, y down) — the
    /// same space as `DisplayDescriptor.logicalFrame`.
    public var frame: LogicalRect
    public var isOnScreen: Bool
    /// CGWindowLevel-style layer; 0 = normal app windows.
    public var windowLayer: Int

    public init(
        windowID: UInt32,
        title: String? = nil,
        owningAppBundleID: String? = nil,
        owningAppName: String? = nil,
        frame: LogicalRect,
        isOnScreen: Bool,
        windowLayer: Int
    ) {
        self.windowID = windowID
        self.title = title
        self.owningAppBundleID = owningAppBundleID
        self.owningAppName = owningAppName
        self.frame = frame
        self.isOnScreen = isOnScreen
        self.windowLayer = windowLayer
    }

    init(_ window: SCWindow) {
        self.init(
            windowID: window.windowID,
            title: window.title.flatMap { $0.isEmpty ? nil : $0 },
            owningAppBundleID: window.owningApplication
                .flatMap { $0.bundleIdentifier.isEmpty ? nil : $0.bundleIdentifier },
            owningAppName: window.owningApplication
                .flatMap { $0.applicationName.isEmpty ? nil : $0.applicationName },
            frame: LogicalRect(
                x: window.frame.origin.x,
                y: window.frame.origin.y,
                width: window.frame.width,
                height: window.frame.height
            ),
            isOnScreen: window.isOnScreen,
            windowLayer: window.windowLayer
        )
    }
}

/// One enumeration pass over the shareable content: every display (as the
/// portable `DisplayLayout`) plus every window.
public struct ShareableContentSnapshot: Hashable, Sendable {
    public var layout: DisplayLayout
    public var windows: [WindowDescriptor]

    public init(layout: DisplayLayout, windows: [WindowDescriptor]) {
        self.layout = layout
        self.windows = windows
    }
}

/// Wraps SCShareableContent enumeration (S0: 20–27 ms per pass) into portable
/// value types.
public enum ShareableContentService {
    /// Enumerate displays and windows. Throws `CaptureError.permissionDenied`
    /// when Screen Recording is not granted (-3801).
    public static func snapshot(
        excludeDesktopWindows: Bool = true,
        onScreenWindowsOnly: Bool = true
    ) async throws -> ShareableContentSnapshot {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                excludeDesktopWindows,
                onScreenWindowsOnly: onScreenWindowsOnly
            )
        } catch {
            throw CaptureError(wrapping: error)
        }
        return ShareableContentSnapshot(
            layout: DisplayLayout(displays: descriptors(for: content.displays)),
            windows: content.windows.map(WindowDescriptor.init)
        )
    }

    /// Main display first — `DisplayLayout.display(bestFor:)` breaks overlap
    /// ties by array order, and the spec wants the main display to win them.
    static func descriptors(for displays: [SCDisplay]) -> [DisplayDescriptor] {
        let mainID = CGMainDisplayID()
        let all = displays.map(descriptor(for:))
        return all.filter { $0.id == mainID } + all.filter { $0.id != mainID }
    }

    private static func descriptor(for display: SCDisplay) -> DisplayDescriptor {
        let frame = display.frame
        return DisplayDescriptor(
            id: display.displayID,
            logicalFrame: LogicalRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.width,
                height: frame.height
            ),
            scale: backingScale(for: display.displayID, pointWidth: frame.width)
        )
    }

    /// SCDisplay exposes no backing scale, and `CGDisplayPixelsWide` is a trap
    /// (it reports points, not pixels, on Retina). The active display mode's
    /// `pixelWidth` is the framebuffer's true pixel width — exactly what
    /// SCScreenshotManager captures — so scale = pixelWidth / point width.
    /// This also handles scaled "More Space" modes where scale is non-integral
    /// (e.g. 3456 px / 1800 pt = 1.92).
    static func backingScale(for displayID: CGDirectDisplayID, pointWidth: Double) -> Double {
        guard pointWidth > 0, let mode = CGDisplayCopyDisplayMode(displayID) else { return 1 }
        let scale = Double(mode.pixelWidth) / pointWidth
        return scale > 0 ? scale : 1
    }
}
