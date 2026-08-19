// swift-tools-version: 6.0
import PackageDescription

/// Pure business logic. Imports no Apple UI or persistence framework, so its tests run
/// natively on macOS in milliseconds instead of booting a simulator (ADR-002 §3).
let package = Package(
    name: "FoodMapDomain",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "FoodMapDomain", targets: ["FoodMapDomain"])
    ],
    targets: [
        .target(name: "FoodMapDomain"),
        .testTarget(name: "FoodMapDomainTests", dependencies: ["FoodMapDomain"])
    ]
)
