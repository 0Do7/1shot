// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DarkroomLibrary",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DarkroomLibrary", targets: ["DarkroomLibrary"]),
    ],
    dependencies: [
        .package(path: "../DarkroomCore"),
        .package(path: "../DarkroomOCR"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "DarkroomLibrary",
            dependencies: [
                "DarkroomCore",
                "DarkroomOCR",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "DarkroomLibraryTests",
            dependencies: ["DarkroomLibrary"]
        ),
    ]
)
