// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "tachikoma",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "tachikoma", targets: ["tachikoma"]),
        .library(name: "TachikomaCore", targets: ["TachikomaCore"])
    ],
    targets: [
        .target(name: "TachikomaCore"),
        .executableTarget(
            name: "tachikoma",
            dependencies: ["TachikomaCore"]
        )
    ]
)
