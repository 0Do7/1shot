// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneShotCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneShotCore", targets: ["OneShotCore"]),
    ],
    targets: [
        .target(
            name: "OneShotCore"
        ),
        .testTarget(
            name: "OneShotCoreTests",
            dependencies: ["OneShotCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
