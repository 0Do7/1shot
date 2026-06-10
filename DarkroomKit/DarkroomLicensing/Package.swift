// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DarkroomLicensing",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DarkroomLicensing", targets: ["DarkroomLicensing"]),
    ],
    dependencies: [
        .package(path: "../DarkroomCore"),
    ],
    targets: [
        .target(
            name: "DarkroomLicensing",
            dependencies: ["DarkroomCore"]
        ),
        .testTarget(
            name: "DarkroomLicensingTests",
            dependencies: ["DarkroomLicensing"]
        ),
    ]
)
