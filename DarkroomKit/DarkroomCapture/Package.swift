// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DarkroomCapture",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DarkroomCapture", targets: ["DarkroomCapture"]),
    ],
    dependencies: [
        .package(path: "../DarkroomCore"),
    ],
    targets: [
        .target(
            name: "DarkroomCapture",
            dependencies: ["DarkroomCore"]
        ),
        .testTarget(
            name: "DarkroomCaptureTests",
            dependencies: ["DarkroomCapture"]
        ),
    ]
)
