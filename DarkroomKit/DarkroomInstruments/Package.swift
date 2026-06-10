// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DarkroomInstruments",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DarkroomInstruments", targets: ["DarkroomInstruments"]),
    ],
    targets: [
        .target(
            name: "DarkroomInstruments"
        ),
        .testTarget(
            name: "DarkroomInstrumentsTests",
            dependencies: ["DarkroomInstruments"]
        ),
    ]
)
