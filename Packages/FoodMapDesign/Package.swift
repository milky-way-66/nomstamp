// swift-tools-version: 6.0
import PackageDescription

/// The palette and its contrast maths, kept out of the app target so WCAG conformance is a
/// unit test that runs on macOS rather than a claim in a document (NFR-6.4).
let package = Package(
    name: "FoodMapDesign",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "FoodMapDesign", targets: ["FoodMapDesign"])
    ],
    targets: [
        .target(name: "FoodMapDesign"),
        .testTarget(name: "FoodMapDesignTests", dependencies: ["FoodMapDesign"]),
    ]
)
