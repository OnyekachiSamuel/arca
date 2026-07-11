// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "arcan",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "arcan", targets: ["ArcanExecutable"])
    ],
    targets: [
        .target(name: "ArcanCLI"),
        .executableTarget(name: "ArcanExecutable", dependencies: ["ArcanCLI"]),
        .testTarget(name: "ArcanCLITests", dependencies: ["ArcanCLI"])
    ]
)
