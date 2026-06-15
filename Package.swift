// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BaufiApp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BaufiCore"),
        .executableTarget(
            name: "BaufiApp",
            dependencies: ["BaufiCore"]
        ),
        .testTarget(
            name: "BaufiCoreTests",
            dependencies: ["BaufiCore"]
        ),
    ]
)
