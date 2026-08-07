// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "arca",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "arca", targets: ["ArcaExecutable"]),
        .library(name: "ArcaConfiguration", targets: ["ArcaConfiguration"]),
        .library(name: "ArcaDomain", targets: ["ArcaDomain"]),
        .library(name: "ArcaGit", targets: ["ArcaGit"]),
        .library(name: "ArcaKnowledge", targets: ["ArcaKnowledge"]),
        .library(name: "ArcaLLM", targets: ["ArcaLLM"]),
        .library(name: "ArcaProcess", targets: ["ArcaProcess"]),
        .library(name: "ArcaAnalysis", targets: ["ArcaAnalysis"]),
        .library(name: "ArcaAnalyzers", targets: ["ArcaAnalyzers"]),
        .library(name: "ArcaReporting", targets: ["ArcaReporting"]),
        .library(name: "ArcaSource", targets: ["ArcaSource"]),
        .library(name: "ArcaSwiftSyntax", targets: ["ArcaSwiftSyntax"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "602.0.0"
        )
    ],
    targets: [
        .target(name: "ArcaDomain"),
        .target(name: "ArcaConfiguration", dependencies: ["ArcaDomain"]),
        .target(name: "ArcaGit", dependencies: ["ArcaDomain"]),
        .target(
            name: "ArcaKnowledge",
            dependencies: ["ArcaDomain"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "ArcaLLM",
            dependencies: ["ArcaDomain", "ArcaKnowledge"]
        ),
        .target(name: "ArcaProcess"),
        .target(name: "ArcaAnalysis", dependencies: ["ArcaDomain"]),
        .target(
            name: "ArcaAnalyzers",
            dependencies: [
                "ArcaAnalysis",
                "ArcaDomain",
                "ArcaKnowledge",
                "ArcaLLM",
                "ArcaProcess"
            ]
        ),
        .target(name: "ArcaReporting", dependencies: ["ArcaDomain"]),
        .target(name: "ArcaSource", dependencies: ["ArcaDomain"]),
        .target(
            name: "ArcaSwiftSyntax",
            dependencies: [
                "ArcaAnalysis",
                "ArcaDomain",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ]
        ),
        .target(
            name: "ArcaCLI",
            dependencies: [
                "ArcaAnalysis",
                "ArcaAnalyzers",
                "ArcaConfiguration",
                "ArcaDomain",
                "ArcaGit",
                "ArcaKnowledge",
                "ArcaLLM",
                "ArcaProcess",
                "ArcaReporting",
                "ArcaSource",
                "ArcaSwiftSyntax"
            ]
        ),
        .executableTarget(
            name: "ArcaExecutable",
            dependencies: ["ArcaAnalyzers", "ArcaCLI"]
        ),
        .testTarget(
            name: "ArcaCLITests",
            dependencies: [
                "ArcaAnalysis",
                "ArcaCLI",
                "ArcaDomain",
                "ArcaKnowledge",
                "ArcaLLM",
                "ArcaProcess"
            ]
        ),
        .testTarget(
            name: "ArcaConfigurationTests",
            dependencies: ["ArcaConfiguration", "ArcaDomain"]
        ),
        .testTarget(
            name: "ArcaEndToEndTests",
            dependencies: [
                "ArcaAnalyzers",
                "ArcaCLI",
                "ArcaDomain",
                "ArcaExecutable",
                "ArcaLLM"
            ],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "ArcaDomainTests", dependencies: ["ArcaDomain"]),
        .testTarget(
            name: "ArcaGitTests",
            dependencies: ["ArcaDomain", "ArcaGit"]
        ),
        .testTarget(
            name: "ArcaKnowledgeTests",
            dependencies: ["ArcaDomain", "ArcaKnowledge"]
        ),
        .testTarget(
            name: "ArcaLLMTests",
            dependencies: ["ArcaDomain", "ArcaKnowledge", "ArcaLLM"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "ArcaProcessTests",
            dependencies: ["ArcaProcess"]
        ),
        .testTarget(
            name: "ArcaAnalysisTests",
            dependencies: ["ArcaAnalysis", "ArcaDomain"]
        ),
        .testTarget(
            name: "ArcaAnalyzersTests",
            dependencies: [
                "ArcaAnalysis",
                "ArcaAnalyzers",
                "ArcaDomain",
                "ArcaKnowledge",
                "ArcaLLM",
                "ArcaProcess",
                "ArcaSource",
                "ArcaSwiftSyntax"
            ],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "ArcaReportingTests",
            dependencies: ["ArcaDomain", "ArcaReporting"]
        ),
        .testTarget(
            name: "ArcaSourceTests",
            dependencies: ["ArcaSource", "ArcaDomain"]
        ),
        .testTarget(
            name: "ArcaSwiftSyntaxTests",
            dependencies: [
                "ArcaAnalysis",
                "ArcaDomain",
                "ArcaSource",
                "ArcaSwiftSyntax"
            ],
            resources: [.copy("Fixtures")]
        )
    ]
)
