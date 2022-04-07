// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "Forker",
    platforms: [.iOS(.v12), .macOS(.v10_10)],
    products: [
        .library(
            name: "Forker",
            targets: ["Forker"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Forker",
            dependencies: []
        ),
        .testTarget(
            name: "ForkerTests",
            dependencies: ["Forker"]
        )
    ]
)
