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
        // TEST-ONLY: the real Vision OCR recognizer drives the redaction lane's
        // OCR-defeat assertions (task 6.1). The SHIPPING library target below does
        // NOT depend on OCR — only the test target does (no OCR in the portable
        // render library).
        .package(path: "../OneShotOCR"),
    ],
    targets: [
        .target(
            name: "OneShotRender",
            dependencies: ["OneShotCore"]
        ),
        .testTarget(
            name: "OneShotRenderTests",
            dependencies: [
                "OneShotRender",
                "OneShotOCR",
            ],
            // DRAFT golden baseline PNGs (design D13 / build-guide DoD #3): reviewed
            // product assets — pending human visual sign-off.
            resources: [.copy("Goldens")]
        ),
    ]
)
