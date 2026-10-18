// swift-tools-version: 6.2
// Swift Package Manager manifest for ShotShifter, a macOS command-line tool that
// shifts the time labels on the X-axis of dashboard screenshots to another time zone.
// It declares one executable target, its test target, and the single third-party
// dependency, Apple's swift-argument-parser.

import PackageDescription

let package = Package(
    name: "ShotShifter",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "shotshifter", targets: ["ShotShifter"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.5.0"))
    ],
    targets: [
        .executableTarget(
            name: "ShotShifter",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "ShotShifterTests",
            dependencies: ["ShotShifter"]
        )
    ],
    swiftLanguageModes: [.v6]
)
