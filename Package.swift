// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CangJieCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "CangJieCore", targets: ["CangJieCore"])
    ],
    targets: [
        .target(name: "CangJieCore", path: "Sources/CangJieCore"),
        .testTarget(
            name: "CangJieCoreTests",
            dependencies: ["CangJieCore"],
            path: "Tests/CangJieCoreTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)