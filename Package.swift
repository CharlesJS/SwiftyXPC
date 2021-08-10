// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyXPC",
    platforms: [
        .macOS(.v12),
        .macCatalyst(.v15)
    ],
    products: [
        .library(
            name: "SwiftyXPC",
            targets: ["SwiftyXPC"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftyXPC",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftyXPCTests",
            dependencies: ["SwiftyXPC"]
        ),
    ]
)
