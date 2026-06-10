// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DarkroomOCR",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DarkroomOCR", targets: ["DarkroomOCR"]),
    ],
    dependencies: [
        .package(path: "../DarkroomCore"),
    ],
    targets: [
        .target(
            name: "DarkroomOCR",
            dependencies: ["DarkroomCore"]
        ),
        .testTarget(
            name: "DarkroomOCRTests",
            dependencies: ["DarkroomOCR"]
        ),
    ]
)
