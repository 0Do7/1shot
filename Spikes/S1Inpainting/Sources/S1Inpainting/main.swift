// S1 spike (design D9): can Core Image built-ins deliver acceptable content-aware
// removal, or does MVP ship blur-fill while a custom patch-match kernel waits?
//
// Method: synthesize 5 screenshot-like fixtures where the true background is known,
// composite an "object" over each, remove it with each candidate technique, then
// score RMSE inside the hole against ground truth + write PNGs for eyeball review.
// Findings: docs/spikes/s1-inpainting.md. Outputs: Spikes/S1Inpainting/output/.

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Deterministic RNG (spike must be reproducible)

struct LCG {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 33) / Double(UInt32.max)
    }
}

// MARK: - Fixture synthesis

let width = 800, height = 600

func makeContext() -> CGContext {
    CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

struct Fixture {
    let name: String
    let background: CGImage // ground truth
    let composited: CGImage // background + object to remove
    let hole: CGRect // region to inpaint (image coordinates, origin bottom-left)
}

func fixture(
    name: String,
    hole: CGRect,
    drawBackground: (CGContext) -> Void,
    drawObject: (CGContext) -> Void
) -> Fixture {
    let bg = makeContext()
    drawBackground(bg)
    let background = bg.makeImage()!
    let comp = makeContext()
    comp.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
    drawObject(comp)
    return Fixture(name: name, background: background, composited: comp.makeImage()!, hole: hole)
}

func textRows(_ ctx: CGContext, in area: CGRect, rowHeight: CGFloat, gap: CGFloat, color: CGColor, rng: inout LCG) {
    ctx.setFillColor(color)
    var y = area.maxY - rowHeight
    while y > area.minY {
        let w = area.width * (0.5 + 0.5 * rng.next())
        ctx.fill(CGRect(x: area.minX, y: y, width: w, height: rowHeight))
        y -= rowHeight + gap
    }
}

func makeFixtures() -> [Fixture] {
    var fixtures: [Fixture] = []

    // 1. Flat window chrome — the easy case content-aware removal must nail.
    fixtures.append(fixture(name: "1-flat", hole: CGRect(x: 330, y: 240, width: 140, height: 120)) { ctx in
        ctx.setFillColor(CGColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    } drawObject: { ctx in
        ctx.setFillColor(CGColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 340, y: 250, width: 120, height: 100))
    })

    // 2. Vertical gradient (desktop/hero background).
    fixtures.append(fixture(name: "2-gradient", hole: CGRect(x: 320, y: 230, width: 160, height: 140)) { ctx in
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            colors: [
                CGColor(red: 0.1, green: 0.2, blue: 0.5, alpha: 1),
                CGColor(red: 0.5, green: 0.7, blue: 0.95, alpha: 1),
            ] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: CGFloat(height)),
            options: []
        )
    } drawObject: { ctx in
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        let pill = CGRect(x: 330, y: 250, width: 140, height: 100)
        ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 20, cornerHeight: 20, transform: nil))
        ctx.fillPath()
    })

    // 3. Code editor: dark bg + syntax-colored "lines"; object overlaps text (hard).
    fixtures.append(fixture(name: "3-code", hole: CGRect(x: 290, y: 220, width: 220, height: 160)) { ctx in
        ctx.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        var rng = LCG(state: 7)
        let palette = [
            CGColor(red: 0.8, green: 0.6, blue: 0.3, alpha: 1),
            CGColor(red: 0.4, green: 0.75, blue: 0.5, alpha: 1),
            CGColor(red: 0.5, green: 0.6, blue: 0.9, alpha: 1),
        ]
        var y: CGFloat = 560
        var i = 0
        while y > 40 {
            ctx.setFillColor(palette[i % palette.count])
            let indent = CGFloat([0, 24, 48, 24][i % 4])
            ctx.fill(CGRect(x: 40 + indent, y: y, width: 300 + 280 * rng.next(), height: 10))
            y -= 22
            i += 1
        }
    } drawObject: { ctx in
        ctx.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1))
        ctx.fill(CGRect(x: 300, y: 230, width: 200, height: 140))
        ctx.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1))
        var rng = LCG(state: 11)
        textRows(
            ctx,
            in: CGRect(x: 315, y: 245, width: 170, height: 110),
            rowHeight: 8,
            gap: 8,
            color: CGColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1),
            rng: &rng
        )
    })

    // 4. Web page: white bg, light card, dark text rows; object = avatar on card edge.
    fixtures.append(fixture(name: "4-web", hole: CGRect(x: 350, y: 260, width: 110, height: 110)) { ctx in
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1))
        ctx.fill(CGRect(x: 100, y: 100, width: 600, height: 400))
        var rng = LCG(state: 23)
        textRows(
            ctx,
            in: CGRect(x: 140, y: 140, width: 520, height: 320),
            rowHeight: 12,
            gap: 14,
            color: CGColor(gray: 0.25, alpha: 1),
            rng: &rng
        )
    } drawObject: { ctx in
        ctx.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 360, y: 270, width: 90, height: 90))
    })

    // 5. Photographic noise/texture — the known-hard case for naive fills.
    fixtures.append(fixture(name: "5-texture", hole: CGRect(x: 330, y: 240, width: 140, height: 120)) { ctx in
        var rng = LCG(state: 42)
        for x in stride(from: 0, to: width, by: 8) {
            for y in stride(from: 0, to: height, by: 8) {
                let g = 0.35 + 0.4 * rng.next()
                ctx.setFillColor(CGColor(red: g, green: g * 0.9, blue: g * 0.75, alpha: 1))
                ctx.fill(CGRect(x: x, y: y, width: 8, height: 8))
            }
        }
    } drawObject: { ctx in
        ctx.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1))
        ctx.fill(CGRect(x: 340, y: 250, width: 120, height: 100))
    })

    return fixtures
}

// MARK: - Candidate techniques

let ciContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

/// Hole mask as CIImage: white inside hole, black outside.
func holeMask(_ hole: CGRect) -> CIImage {
    CIImage(color: .white).cropped(to: hole)
        .composited(over: CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: width, height: height)))
}

/// Mean color of a ring around the hole (border context for seeding fills).
func ringAverage(_ image: CIImage, hole: CGRect) -> CIImage {
    let ring = hole.insetBy(dx: -12, dy: -12)
    let filter = CIFilter(name: "CIAreaAverage", parameters: [
        kCIInputImageKey: image.cropped(to: ring),
        kCIInputExtentKey: CIVector(cgRect: ring),
    ])!
    return filter.outputImage!
        .transformed(by: CGAffineTransform(scaleX: CGFloat(width), y: CGFloat(height)))
        .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
}

func blend(_ inside: CIImage, _ outside: CIImage, mask: CIImage) -> CIImage {
    let filter = CIFilter(name: "CIBlendWithMask", parameters: [
        kCIInputImageKey: inside,
        kCIInputBackgroundImageKey: outside,
        kCIInputMaskImageKey: mask,
    ])!
    return filter.outputImage!
}

/// A) Baseline: fill hole with ring-average color, then one wide blur pass.
func blurFill(_ image: CIImage, hole: CGRect) -> CIImage {
    let mask = holeMask(hole)
    let seeded = blend(ringAverage(image, hole: hole), image, mask: mask)
    let blurred = seeded.clampedToExtent()
        .applyingGaussianBlur(sigma: 25)
        .cropped(to: image.extent)
    return blend(blurred, image, mask: mask)
}

/// B) Diffusion fill: seed hole with ring average, then repeated blur-and-reblend
/// with shrinking sigma so border colors diffuse inward (Poisson-ish, CI-only).
func diffusionFill(_ image: CIImage, hole: CGRect) -> CIImage {
    let mask = holeMask(hole)
    var current = blend(ringAverage(image, hole: hole), image, mask: mask)
    for sigma in [60.0, 40.0, 25.0, 15.0, 8.0, 4.0, 2.0] {
        let blurred = current.clampedToExtent()
            .applyingGaussianBlur(sigma: sigma)
            .cropped(to: image.extent)
        current = blend(blurred, current, mask: mask)
    }
    return current
}

/// C) Patch shift: clone the band directly above (or below) the hole into it,
/// feathered at the edges — a one-patch proxy for patch-match.
func patchShift(_ image: CIImage, hole: CGRect) -> CIImage {
    let shiftUp = hole.maxY + hole.height <= CGFloat(height) - 8
    let dy = shiftUp ? hole.height + 4 : -(hole.height + 4)
    let donor = image
        .cropped(to: hole.offsetBy(dx: 0, dy: dy))
        .transformed(by: CGAffineTransform(translationX: 0, y: -dy))
    let feathered = holeMask(hole).clampedToExtent()
        .applyingGaussianBlur(sigma: 3)
        .cropped(to: image.extent)
    return blend(donor.composited(over: image), image, mask: feathered)
}

// MARK: - Scoring

/// RMSE (0–255 scale) between two images inside the hole only.
func rmse(_ a: CGImage, _ b: CGImage, hole: CGRect) -> Double {
    func pixels(_ img: CGImage) -> [UInt8] {
        let ctx = makeContext()
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: width, height: height))
        let buf = ctx.data!.assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: buf, count: ctx.bytesPerRow * height))
    }
    let pa = pixels(a), pb = pixels(b)
    let bytesPerRow = makeContext().bytesPerRow
    var sum = 0.0, count = 0
    // CGContext rows are top-down; hole rect is bottom-up.
    for py in Int(CGFloat(height) - hole.maxY) ..< Int(CGFloat(height) - hole.minY) {
        for px in Int(hole.minX) ..< Int(hole.maxX) {
            let i = py * bytesPerRow + px * 4
            for c in 0 ..< 3 {
                let d = Double(pa[i + c]) - Double(pb[i + c])
                sum += d * d
                count += 1
            }
        }
    }
    return (sum / Double(count)).squareRoot()
}

// MARK: - Run

let outputDir = URL(fileURLWithPath: "output", isDirectory: true)
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func writePNG(_ image: CGImage, _ name: String) {
    let url = outputDir.appendingPathComponent("\(name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

func render(_ image: CIImage) -> CGImage {
    ciContext.createCGImage(image, from: CGRect(x: 0, y: 0, width: width, height: height))!
}

// Empirical check: does this OS ship any built-in inpainting-ish CIFilter?
let allFilters = CIFilter.filterNames(inCategories: nil)
let inpaintCandidates = allFilters.filter {
    let l = $0.lowercased()
    return l.contains("inpaint") || l.contains("heal") || l.contains("fill") || l.contains("reconstruct")
}

print("CIFilter census on \(ProcessInfo.processInfo.operatingSystemVersionString): \(allFilters.count) filters")
print(
    "inpaint/heal/fill/reconstruct candidates: \(inpaintCandidates.isEmpty ? "NONE" : inpaintCandidates.joined(separator: ", "))"
)
print()

let techniques: [(String, (CIImage, CGRect) -> CIImage)] = [
    ("blurFill", blurFill),
    ("diffusionFill", diffusionFill),
    ("patchShift", patchShift),
]

let clock = ContinuousClock()
print(String(format: "%-12@", "fixture" as NSString), terminator: "")
for (name, _) in techniques {
    print(String(format: " %18@", name as NSString), terminator: "")
}

print()

for fix in makeFixtures() {
    writePNG(fix.background, "\(fix.name)-0-groundtruth")
    writePNG(fix.composited, "\(fix.name)-1-input")
    let input = CIImage(cgImage: fix.composited)
    print(String(format: "%-12@", fix.name as NSString), terminator: "")
    for (name, technique) in techniques {
        var result: CGImage?
        let elapsed = clock.measure {
            result = render(technique(input, fix.hole))
        }
        writePNG(result!, "\(fix.name)-2-\(name)")
        let score = rmse(result!, fix.background, hole: fix.hole)
        print(String(format: " %10.1f (%4.0fms)", score, elapsed.milliseconds), terminator: "")
    }
    print()
}

print("\nRMSE inside hole vs ground truth, 0–255 scale; lower is better.")
print("PNGs written to \(outputDir.path) for visual review.")

extension Duration {
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
