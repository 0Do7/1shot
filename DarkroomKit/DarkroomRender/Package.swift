// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DarkroomRender",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DarkroomRender", targets: ["DarkroomRender"]),
    ],
    dependencies: [
        .package(path: "../DarkroomCore"),
    ],
    targets: [
        .target(
            name: "DarkroomRender",
            dependencies: ["DarkroomCore"]
        ),
        .testTarget(
            name: "DarkroomRenderTests",
            dependencies: ["DarkroomRender"]
        ),
    ]
)
