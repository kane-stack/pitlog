// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PitlogCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "PitlogCore", targets: ["PitlogCore"]),
    ],
    targets: [
        .target(name: "PitlogCore"),
        .testTarget(name: "PitlogCoreTests", dependencies: ["PitlogCore"]),
    ]
)
