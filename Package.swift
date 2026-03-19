// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "cog-swift",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "cog-swift", targets: ["CogSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1"),
    ],
    targets: [
        .target(
            name: "CogSwiftLib",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "CogSwift",
            dependencies: ["CogSwiftLib"]
        ),
        .testTarget(
            name: "CogSwiftTests",
            dependencies: ["CogSwiftLib"]
        ),
    ]
)
