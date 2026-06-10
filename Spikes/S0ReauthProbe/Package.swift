// swift-tools-version: 6.0
// S0 spike (task 1.1) — NOT part of DarkroomKit; excluded from CI.
import PackageDescription

let package = Package(
    name: "S0ReauthProbe",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "S0ReauthProbe"),
    ]
)
