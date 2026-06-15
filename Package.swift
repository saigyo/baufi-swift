// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BaufiSwift",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BaufiCore"),
        .executableTarget(
            name: "BaufiSwift",
            dependencies: ["BaufiCore"]
        ),
        .testTarget(
            name: "BaufiCoreTests",
            dependencies: ["BaufiCore"]
        ),
    ]
)
