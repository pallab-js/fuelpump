// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FuelStationApp",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "FuelStationCore", targets: ["FuelStationCore"]),
    ],
    targets: [
        .target(
            name: "FuelStationCore",
            path: "Sources/FuelStationCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "FuelStationApp",
            dependencies: ["FuelStationCore"],
            path: "Sources/FuelStationApp"
        ),
    ]
)
