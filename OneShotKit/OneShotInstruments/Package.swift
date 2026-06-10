// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneShotInstruments",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneShotInstruments", targets: ["OneShotInstruments"]),
    ],
    targets: [
        .target(
            name: "OneShotInstruments"
        ),
        .testTarget(
            name: "OneShotInstrumentsTests",
            dependencies: ["OneShotInstruments"]
        ),
    ]
)
