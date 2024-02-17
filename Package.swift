// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyXPC",
    platforms: [
        .macOS(.v10_15),
        .macCatalyst(.v13),
    ],
    products: [
        .library(
            name: "SwiftyXPC",
            targets: ["SwiftyXPC"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftyXPC",
            dependencies: []
        ),
        .target(
            name: "TestShared",
            dependencies: ["SwiftyXPC"]
        ),
        .executableTarget(
            name: "TestHelper",
            dependencies: ["SwiftyXPC", "TestShared"]
        ),
        .testTarget(
            name: "SwiftyXPCTests",
            dependencies: ["SwiftyXPC", "TestHelper", "TestShared"]
        ),
    ]
)
