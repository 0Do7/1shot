// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneShotOCR",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneShotOCR", targets: ["OneShotOCR"]),
    ],
    dependencies: [
        .package(path: "../OneShotCore"),
    ],
    targets: [
        .target(
            name: "OneShotOCR",
            dependencies: ["OneShotCore"]
        ),
        .testTarget(
            name: "OneShotOCRTests",
            dependencies: ["OneShotOCR"]
        ),
    ]
)
