// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneShotLibrary",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneShotLibrary", targets: ["OneShotLibrary"]),
    ],
    dependencies: [
        .package(path: "../OneShotCore"),
        .package(path: "../OneShotOCR"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "OneShotLibrary",
            dependencies: [
                "OneShotCore",
                "OneShotOCR",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "OneShotLibraryTests",
            dependencies: ["OneShotLibrary"]
        ),
    ]
)
