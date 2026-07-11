// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "arcan",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "arcan", targets: ["ArcanExecutable"]),
        .library(name: "ArcanDomain", targets: ["ArcanDomain"]),
        .library(name: "ArcanAnalysis", targets: ["ArcanAnalysis"]),
        .library(name: "ArcanSource", targets: ["ArcanSource"])
    ],
    targets: [
        .target(name: "ArcanDomain"),
        .target(name: "ArcanAnalysis", dependencies: ["ArcanDomain"]),
        .target(name: "ArcanSource", dependencies: ["ArcanDomain"]),
        .target(
            name: "ArcanCLI",
            dependencies: ["ArcanDomain", "ArcanSource"]
        ),
        .executableTarget(name: "ArcanExecutable", dependencies: ["ArcanCLI"]),
        .testTarget(name: "ArcanCLITests", dependencies: ["ArcanCLI"]),
        .testTarget(name: "ArcanDomainTests", dependencies: ["ArcanDomain"]),
        .testTarget(
            name: "ArcanAnalysisTests",
            dependencies: ["ArcanAnalysis", "ArcanDomain"]
        ),
        .testTarget(
            name: "ArcanSourceTests",
            dependencies: ["ArcanSource", "ArcanDomain"]
        )
    ]
)
