// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneShotLicensing",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneShotLicensing", targets: ["OneShotLicensing"]),
    ],
    dependencies: [
        .package(path: "../OneShotCore"),
    ],
    targets: [
        .target(
            name: "OneShotLicensing",
            dependencies: ["OneShotCore"]
        ),
        .testTarget(
            name: "OneShotLicensingTests",
            dependencies: ["OneShotLicensing"]
        ),
    ]
)
