import CoreGraphics
import OneShotCore

/// Pure geometry for anchoring the chip stack in a screen corner (task 4.1,
/// spec:post-capture-chip "configurable corner" + "stack vertically"). Kept
/// separate from AppKit so multi-display + corner math is unit-testable.
///
/// Coordinates are AppKit screen space (origin bottom-left, y up) — the same
/// space `NSScreen.frame` and `NSWindow.setFrameOrigin` use.
enum ChipLayout {
    /// Gap between a chip and the screen edges.
    static let margin: CGFloat = 16
    /// Vertical gap between stacked chips.
    static let spacing: CGFloat = 10

    /// Frame for the chip at `stackIndex` (0 = newest, anchored at the corner;
    /// higher indices stack inward, away from the corner) within `displayFrame`.
    static func frame(
        for corner: ScreenCorner,
        displayFrame: CGRect,
        chipSize: CGSize,
        stackIndex: Int
    ) -> CGRect {
        let offset = CGFloat(stackIndex) * (chipSize.height + spacing)

        let x: CGFloat = switch corner {
        case .topLeading, .bottomLeading:
            displayFrame.minX + margin
        case .topTrailing, .bottomTrailing:
            displayFrame.maxX - margin - chipSize.width
        }

        let y: CGFloat = switch corner {
        case .topLeading, .topTrailing:
            // Top corners stack downward: newest hugs the top edge.
            displayFrame.maxY - margin - chipSize.height - offset
        case .bottomLeading, .bottomTrailing:
            // Bottom corners stack upward: newest hugs the bottom edge.
            displayFrame.minY + margin + offset
        }

        return CGRect(x: x, y: y, width: chipSize.width, height: chipSize.height)
    }
}
