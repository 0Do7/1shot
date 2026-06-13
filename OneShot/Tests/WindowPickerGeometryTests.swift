import CoreGraphics
import OneShotCore
import Testing
@testable import OneShot

/// Fake screen layout — no real NSScreen required. Primary screen: 1512x982pt;
/// CG space puts (0,0) at its TOP-left, AppKit at its BOTTOM-left.
private let primaryHeight = 982.0

@Test func appKitScreenRect_flipsYWithinPrimaryScreen() {
    let logical = LogicalRect(x: 100, y: 100, width: 400, height: 300)
    let flipped = WindowPickerGeometry.appKitScreenRect(for: logical, primaryScreenHeight: primaryHeight)
    // cgMaxY = 400 → appKitY = 982 − 400 = 582; x passes through.
    #expect(flipped == CGRect(x: 100, y: 582, width: 400, height: 300))
}

@Test func appKitScreenRect_topLeftWindowLandsAtTopInAppKitSpace() {
    let logical = LogicalRect(x: 0, y: 0, width: 200, height: 100)
    let flipped = WindowPickerGeometry.appKitScreenRect(for: logical, primaryScreenHeight: primaryHeight)
    #expect(flipped == CGRect(x: 0, y: 882, width: 200, height: 100))
}

@Test func appKitScreenRect_secondaryDisplayAbovePrimaryGetsNegativeCGPositiveAppKit() {
    // A display arranged ABOVE the primary has negative CG y; in AppKit space
    // it sits above the primary's top (y > primaryHeight).
    let logical = LogicalRect(x: 300, y: -500, width: 400, height: 300)
    let flipped = WindowPickerGeometry.appKitScreenRect(for: logical, primaryScreenHeight: primaryHeight)
    #expect(flipped == CGRect(x: 300, y: 1182, width: 400, height: 300))
}

@Test func appKitScreenRect_secondaryDisplayBelowPrimaryGetsNegativeAppKitY() {
    let logical = LogicalRect(x: 0, y: 982, width: 400, height: 300)
    let flipped = WindowPickerGeometry.appKitScreenRect(for: logical, primaryScreenHeight: primaryHeight)
    #expect(flipped == CGRect(x: 0, y: -300, width: 400, height: 300))
}

@Test func logicalRect_isExactInverseOfAppKitRect() {
    let original = LogicalRect(x: -120, y: 444.5, width: 333, height: 77)
    let roundTripped = WindowPickerGeometry.logicalRect(
        forAppKit: WindowPickerGeometry.appKitScreenRect(for: original, primaryScreenHeight: primaryHeight),
        primaryScreenHeight: primaryHeight
    )
    #expect(roundTripped == original)
}

@Test func logicalPoint_flipsCursorPosition() {
    let logical = WindowPickerGeometry.logicalPoint(
        forAppKit: CGPoint(x: 250, y: 100),
        primaryScreenHeight: primaryHeight
    )
    #expect(logical == LogicalPoint(x: 250, y: 882))
}
