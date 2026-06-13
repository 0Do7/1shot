import Foundation
import OneShotCore

/// Pure coordinate conversion between the capture domain's CG-oriented global
/// space and AppKit's screen space. Kept free of NSScreen so the flip math is
/// unit-testable with fake screen geometry.
enum WindowPickerGeometry {
    /// Global CG space (top-left origin, y down — the space
    /// `WindowDescriptor.frame` and `DisplayDescriptor.logicalFrame` use) →
    /// AppKit global screen space (bottom-left origin, y up).
    ///
    /// Both spaces are anchored to the PRIMARY screen — the one whose CG
    /// origin is (0, 0), i.e. `NSScreen.screens[0]` — so the whole flip is
    /// `appKitY = primaryScreenHeight − cgMaxY`. X is shared between the two
    /// spaces; only y mirrors.
    static func appKitScreenRect(for logical: LogicalRect, primaryScreenHeight: Double) -> CGRect {
        CGRect(
            x: logical.minX,
            y: primaryScreenHeight - logical.maxY,
            width: logical.width,
            height: logical.height
        )
    }

    /// Inverse of `appKitScreenRect(for:primaryScreenHeight:)`, for routing
    /// AppKit-space input (e.g. NSEvent.mouseLocation) into the domain space.
    static func logicalRect(forAppKit rect: CGRect, primaryScreenHeight: Double) -> LogicalRect {
        LogicalRect(
            x: rect.minX,
            y: primaryScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Point flip used for cursor positions (same anchor rules as the rects).
    static func logicalPoint(forAppKit point: CGPoint, primaryScreenHeight: Double) -> LogicalPoint {
        LogicalPoint(x: point.x, y: primaryScreenHeight - point.y)
    }
}
