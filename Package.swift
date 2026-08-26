// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DockLocker",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DockLockerCore"),
        .executableTarget(
            name: "DockLocker",
            dependencies: ["DockLockerCore"]
        ),
        .testTarget(
            name: "DockLockerCoreTests",
            dependencies: ["DockLockerCore"]
        ),
    ]
)
