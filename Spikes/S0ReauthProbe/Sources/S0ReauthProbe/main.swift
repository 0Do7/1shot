// S0 spike (design D5, Open Q1): does non-picker SCScreenshotManager trigger the
// Sequoia/Tahoe periodic screen-capture re-auth? Run repeatedly (and across days/
// reboots) on each target OS; findings go to docs/spikes/s0-screencapture-reauth.md.
//
// Usage: swift run S0ReauthProbe [--loop N] [--interval SECONDS]

import CoreGraphics
import Foundation
import ScreenCaptureKit

func timestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
}

func probeOnce(label: String) async {
    print("[\(timestamp())] \(label)")
    print("  CGPreflightScreenCaptureAccess: \(CGPreflightScreenCaptureAccess())")
    do {
        let clock = ContinuousClock()
        var content: SCShareableContent?
        let contentTime = try await clock.measure {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        }
        guard let content, let display = content.displays.first else {
            print("  ✗ no displays in shareable content")
            return
        }
        print("  SCShareableContent: \(content.displays.count) displays, " +
            "\(content.windows.count) windows in \(contentTime)")

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.frame.width) * 2
        config.height = Int(display.frame.height) * 2
        var image: CGImage?
        let captureTime = try await clock.measure {
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        }
        if let image {
            print("  ✓ captured \(image.width)×\(image.height) in \(captureTime) (no picker)")
        }
    } catch {
        print("  ✗ FAILED: \(error)")
        print("    (If this is a TCC denial: grant Screen & System Audio Recording to the")
        print("     terminal host in System Settings → Privacy & Security, then re-run.)")
    }
}

let args = CommandLine.arguments
let loops = args.firstIndex(of: "--loop").flatMap { i in args.indices.contains(i + 1) ? Int(args[i + 1]) : nil } ?? 1
let interval = args.firstIndex(of: "--interval")
    .flatMap { i in args.indices.contains(i + 1) ? Double(args[i + 1]) : nil } ?? 5

print("S0 re-auth probe — macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("Host binary: \(Bundle.main.bundlePath)")

for n in 1 ... loops {
    await probeOnce(label: "probe \(n)/\(loops)")
    if n < loops {
        try? await Task.sleep(for: .seconds(interval))
    }
}
