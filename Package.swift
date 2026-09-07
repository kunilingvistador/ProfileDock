// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProfileDock",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ProfileDock", targets: ["ProfileDock"]),
        .executable(name: "ProfileDockLauncher", targets: ["ProfileDockLauncher"]),
        .library(name: "ProfileDockCore", targets: ["ProfileDockCore"]),
    ],
    targets: [
        .target(name: "ProfileDockCore"),
        .executableTarget(name: "ProfileDock", dependencies: ["ProfileDockCore"]),
        .executableTarget(name: "ProfileDockLauncher"),
        .testTarget(name: "ProfileDockCoreTests", dependencies: ["ProfileDockCore"]),
    ]
)
