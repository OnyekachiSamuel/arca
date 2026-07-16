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
        .library(name: "ArcanGit", targets: ["ArcanGit"]),
        .library(name: "ArcanAnalysis", targets: ["ArcanAnalysis"]),
        .library(name: "ArcanAnalyzers", targets: ["ArcanAnalyzers"]),
        .library(name: "ArcanReporting", targets: ["ArcanReporting"]),
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
        .target(name: "ArcanGit"),
        .target(name: "ArcanAnalysis", dependencies: ["ArcanDomain"]),
        .target(
            name: "ArcanAnalyzers",
            dependencies: ["ArcanAnalysis", "ArcanDomain"]
        ),
        .target(name: "ArcanReporting", dependencies: ["ArcanDomain"]),
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
            dependencies: [
                "ArcanAnalysis",
                "ArcanAnalyzers",
                "ArcanDomain",
                "ArcanReporting",
                "ArcanSource",
                "ArcanSwiftSyntax"
            ]
        ),
        .executableTarget(name: "ArcanExecutable", dependencies: ["ArcanCLI"]),
        .testTarget(name: "ArcanCLITests", dependencies: ["ArcanCLI"]),
        .testTarget(
            name: "ArcanEndToEndTests",
            dependencies: ["ArcanExecutable"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "ArcanDomainTests", dependencies: ["ArcanDomain"]),
        .testTarget(name: "ArcanGitTests", dependencies: ["ArcanGit"]),
        .testTarget(
            name: "ArcanAnalysisTests",
            dependencies: ["ArcanAnalysis", "ArcanDomain"]
        ),
        .testTarget(
            name: "ArcanAnalyzersTests",
            dependencies: [
                "ArcanAnalysis",
                "ArcanAnalyzers",
                "ArcanDomain",
                "ArcanSource",
                "ArcanSwiftSyntax"
            ],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "ArcanReportingTests",
            dependencies: ["ArcanDomain", "ArcanReporting"]
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
