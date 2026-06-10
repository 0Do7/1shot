// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneShotDestinations",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneShotDestinations", targets: ["OneShotDestinations"]),
    ],
    dependencies: [
        .package(path: "../OneShotCore"),
    ],
    targets: [
        .target(
            name: "OneShotDestinations",
            dependencies: ["OneShotCore"]
        ),
        .testTarget(
            name: "OneShotDestinationsTests",
            dependencies: ["OneShotDestinations"]
        ),
    ]
)
