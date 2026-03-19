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
        .executableTarget(
            name: "CogSwift",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "CogSwiftTests",
            dependencies: ["CogSwift"]
        ),
    ]
)
