// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "SwiftUnused",
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten", .exact("0.22.0")),
    ],
    targets: [
        .target(
            name: "SwiftUnusedFramework",
            dependencies: ["SourceKittenFramework"]
        ),
        .target(
            name: "SwiftUnused",
            dependencies: ["SwiftUnusedFramework"]
        ),
        .testTarget(
            name: "SwiftUnusedTests",
            dependencies: ["SwiftUnusedFramework"]
        ),
    ]
)
