// swift-tools-version: 6.0
import PackageDescription

/// Adapters implementing the domain's ports: SwiftData, the file system, Apple Maps and
/// Core Location. Builds for macOS as well as iOS so most of its tests run without a simulator.
let package = Package(
    name: "FoodMapData",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "FoodMapData", targets: ["FoodMapData"])
    ],
    dependencies: [
        .package(path: "../FoodMapDomain")
    ],
    targets: [
        .target(
            name: "FoodMapData",
            dependencies: [.product(name: "FoodMapDomain", package: "FoodMapDomain")],
            // SwiftData's ModelContext is not Sendable and must be used from the context that
            // created it. Swift 5 mode avoids fighting strict concurrency over a constraint the
            // framework enforces at runtime anyway. The domain package stays on Swift 6.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "FoodMapDataTests",
            dependencies: ["FoodMapData"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
