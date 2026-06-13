/// Rendering and export of annotation documents via CoreGraphics/CoreText/ImageIO.
/// Portable layer — never AppKit/SwiftUI/UIKit (CI-enforced, design D2).
///
/// Public entry points (task 5.1): `AnnotationRasterizer.render(document:images:scale:)`
/// and `AnnotationRasterizer.flattenedPNGData(document:images:scale:)`.
public enum OneShotRenderInfo {
    public static let packageName = "OneShotRender"
}
