// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "arcan",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "arcan", targets: ["ArcanExecutable"]),
        .library(name: "ArcanConfiguration", targets: ["ArcanConfiguration"]),
        .library(name: "ArcanDomain", targets: ["ArcanDomain"]),
        .library(name: "ArcanGit", targets: ["ArcanGit"]),
        .library(name: "ArcanKnowledge", targets: ["ArcanKnowledge"]),
        .library(name: "ArcanLLM", targets: ["ArcanLLM"]),
        .library(name: "ArcanProcess", targets: ["ArcanProcess"]),
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
        .target(name: "ArcanConfiguration", dependencies: ["ArcanDomain"]),
        .target(name: "ArcanGit", dependencies: ["ArcanDomain"]),
        .target(
            name: "ArcanKnowledge",
            dependencies: ["ArcanDomain"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "ArcanLLM",
            dependencies: ["ArcanDomain", "ArcanKnowledge"]
        ),
        .target(name: "ArcanProcess"),
        .target(name: "ArcanAnalysis", dependencies: ["ArcanDomain"]),
        .target(
            name: "ArcanAnalyzers",
            dependencies: [
                "ArcanAnalysis",
                "ArcanDomain",
                "ArcanProcess"
            ]
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
                "ArcanConfiguration",
                "ArcanDomain",
                "ArcanGit",
                "ArcanProcess",
                "ArcanReporting",
                "ArcanSource",
                "ArcanSwiftSyntax"
            ]
        ),
        .executableTarget(
            name: "ArcanExecutable",
            dependencies: ["ArcanAnalyzers", "ArcanCLI"]
        ),
        .testTarget(
            name: "ArcanCLITests",
            dependencies: [
                "ArcanAnalysis",
                "ArcanCLI",
                "ArcanDomain",
                "ArcanProcess"
            ]
        ),
        .testTarget(
            name: "ArcanConfigurationTests",
            dependencies: ["ArcanConfiguration", "ArcanDomain"]
        ),
        .testTarget(
            name: "ArcanEndToEndTests",
            dependencies: ["ArcanDomain", "ArcanExecutable"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "ArcanDomainTests", dependencies: ["ArcanDomain"]),
        .testTarget(
            name: "ArcanGitTests",
            dependencies: ["ArcanDomain", "ArcanGit"]
        ),
        .testTarget(
            name: "ArcanKnowledgeTests",
            dependencies: ["ArcanDomain", "ArcanKnowledge"]
        ),
        .testTarget(
            name: "ArcanLLMTests",
            dependencies: ["ArcanDomain", "ArcanKnowledge", "ArcanLLM"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "ArcanProcessTests",
            dependencies: ["ArcanProcess"]
        ),
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
                "ArcanProcess",
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
