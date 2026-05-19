// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HengqinTrackerNative",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "HengqinCore", targets: ["HengqinCore"]),
        .executable(name: "HengqinTracker", targets: ["HengqinTracker"])
    ],
    targets: [
        .target(name: "HengqinCore"),
        .executableTarget(
            name: "HengqinTracker",
            dependencies: ["HengqinCore"]
        ),
        .testTarget(
            name: "HengqinCoreTests",
            dependencies: ["HengqinCore"]
        )
    ]
)
