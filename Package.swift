// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ShakeThat",
    platforms: [.macOS(.v13)],
    targets: [
        // Logic without AppKit (shake detection, settings, file naming, formatting), kept separate so it can be unit tested.
        .target(name: "ShakeCore"),
        .executableTarget(name: "ShakeThat", dependencies: ["ShakeCore"]),
        .testTarget(name: "ShakeCoreTests", dependencies: ["ShakeCore"]),
    ]
)
