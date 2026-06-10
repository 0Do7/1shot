// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DarkroomScroll",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DarkroomScroll", targets: ["DarkroomScroll"]),
    ],
    dependencies: [
        .package(path: "../DarkroomCapture"),
        .package(path: "../DarkroomRender"),
    ],
    targets: [
        .target(
            name: "DarkroomScroll",
            dependencies: ["DarkroomCapture", "DarkroomRender"]
        ),
        .testTarget(
            name: "DarkroomScrollTests",
            dependencies: ["DarkroomScroll"]
        ),
    ]
)
