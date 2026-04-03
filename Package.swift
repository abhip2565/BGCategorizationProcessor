// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BGCategorizationProcessor",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BGCategorizationProcessor",
            targets: ["BGCategorizationProcessor"]
        ),
        .library(
            name: "BGCategorizationProcessorCoreML",
            targets: ["BGCategorizationProcessorCoreML"]
        )
    ],
    targets: [
        .target(
            name: "BGCategorizationProcessor",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "BGCategorizationProcessorCoreML",
            dependencies: ["BGCategorizationProcessor"],
            resources: [
                .copy("Resources/MiniLM")
            ]
        ),
        .testTarget(
            name: "BGCategorizationProcessorTests",
            dependencies: [
                "BGCategorizationProcessor",
                "BGCategorizationProcessorCoreML"
            ],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
