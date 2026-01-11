// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PulseNetworking",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "PulseNetworking",
            targets: ["PulseNetworking"]
        ),
    ],
    targets: [
        .target(
            name: "PulseNetworking",
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseNetworkingTests",
            dependencies: ["PulseNetworking"],
            path: "Tests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
