// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneShotRender",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OneShotRender", targets: ["OneShotRender"]),
    ],
    dependencies: [
        .package(path: "../OneShotCore"),
    ],
    targets: [
        .target(
            name: "OneShotRender",
            dependencies: ["OneShotCore"]
        ),
        .testTarget(
            name: "OneShotRenderTests",
            dependencies: ["OneShotRender"],
            // DRAFT golden baseline PNGs (design D13 / build-guide DoD #3): reviewed
            // product assets — pending human visual sign-off.
            resources: [.copy("Goldens")]
        ),
    ]
)
