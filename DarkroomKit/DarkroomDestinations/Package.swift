// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DarkroomDestinations",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DarkroomDestinations", targets: ["DarkroomDestinations"]),
    ],
    dependencies: [
        .package(path: "../DarkroomCore"),
    ],
    targets: [
        .target(
            name: "DarkroomDestinations",
            dependencies: ["DarkroomCore"]
        ),
        .testTarget(
            name: "DarkroomDestinationsTests",
            dependencies: ["DarkroomDestinations"]
        ),
    ]
)
