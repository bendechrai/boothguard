// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BoothGuard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BoothGuard", targets: ["BoothGuardApp"]),
        .library(name: "BoothGuardCore", targets: ["BoothGuardCore"])
    ],
    targets: [
        .executableTarget(
            name: "BoothGuardApp",
            dependencies: ["BoothGuardCore"],
            path: "Sources/BoothGuardApp"
        ),
        .target(
            name: "BoothGuardCore",
            path: "Sources/BoothGuardCore"
        ),
        .testTarget(
            name: "BoothGuardCoreTests",
            dependencies: ["BoothGuardCore"],
            path: "Tests/BoothGuardCoreTests"
        )
    ]
)
