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
            dependencies: ["TachikomaCore"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker",
                    "-sectcreate",
                    "-Xlinker",
                    "__TEXT",
                    "-Xlinker",
                    "__info_plist",
                    "-Xlinker",
                    "Sources/tachikoma/Info.plist"
                ])
            ]
        ),
        .executableTarget(
            name: "tachikoma-core-tests",
            dependencies: ["TachikomaCore"],
            path: "Tests/TachikomaCoreExecutableTests"
        ),
        .testTarget(
            name: "TachikomaCoreTests",
            dependencies: ["TachikomaCore"],
            swiftSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
