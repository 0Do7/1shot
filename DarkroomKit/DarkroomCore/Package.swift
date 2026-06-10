// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DarkroomCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DarkroomCore", targets: ["DarkroomCore"]),
    ],
    targets: [
        .target(
            name: "DarkroomCore"
        ),
        .testTarget(
            name: "DarkroomCoreTests",
            dependencies: ["DarkroomCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
