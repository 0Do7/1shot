// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneShotCapture",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneShotCapture", targets: ["OneShotCapture"]),
    ],
    dependencies: [
        .package(path: "../OneShotCore"),
    ],
    targets: [
        .target(
            name: "OneShotCapture",
            dependencies: ["OneShotCore"]
        ),
        .testTarget(
            name: "OneShotCaptureTests",
            dependencies: ["OneShotCapture"]
        ),
    ]
)
