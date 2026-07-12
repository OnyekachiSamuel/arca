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
        .library(name: "ArcanSource", targets: ["ArcanSource"]),
        .library(name: "ArcanSwiftSyntax", targets: ["ArcanSwiftSyntax"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "602.0.0"
        )
    ],
    targets: [
        .target(name: "ArcanDomain"),
        .target(name: "ArcanAnalysis", dependencies: ["ArcanDomain"]),
        .target(name: "ArcanSource", dependencies: ["ArcanDomain"]),
        .target(
            name: "ArcanSwiftSyntax",
            dependencies: [
                "ArcanAnalysis",
                "ArcanDomain",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ]
        ),
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
        ),
        .testTarget(
            name: "ArcanSwiftSyntaxTests",
            dependencies: [
                "ArcanAnalysis",
                "ArcanDomain",
                "ArcanSource",
                "ArcanSwiftSyntax"
            ],
            resources: [.copy("Fixtures")]
        )
    ]
)
