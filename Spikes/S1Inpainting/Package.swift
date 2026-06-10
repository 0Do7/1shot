// swift-tools-version: 6.0
// S1 spike (task 1.2) — NOT part of OneShotKit; excluded from CI.
import PackageDescription

let package = Package(
    name: "S1Inpainting",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "S1Inpainting"),
    ]
)
