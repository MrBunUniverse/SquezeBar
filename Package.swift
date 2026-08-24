// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SqueezeBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SqueezeBar",
            targets: ["SqueezeBar"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SqueezeBar",
            dependencies: [],
            path: "Sources/SqueezeBar",
            swiftSettings: []
        ),
        .testTarget(
            name: "SqueezeBarTests",
            dependencies: ["SqueezeBar"],
            path: "Tests/SqueezeBarTests"
        )
    ]
)
