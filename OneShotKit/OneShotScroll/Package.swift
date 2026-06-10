// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneShotScroll",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneShotScroll", targets: ["OneShotScroll"]),
    ],
    dependencies: [
        .package(path: "../OneShotCapture"),
        .package(path: "../OneShotRender"),
    ],
    targets: [
        .target(
            name: "OneShotScroll",
            dependencies: ["OneShotCapture", "OneShotRender"]
        ),
        .testTarget(
            name: "OneShotScrollTests",
            dependencies: ["OneShotScroll"]
        ),
    ]
)
