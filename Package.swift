// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "arca",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "arca", targets: ["ArcaExecutable"]),
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
    .target(
      name: "ArcaAnalyzers",
      dependencies: [
        "ArcaDomain",
        "ArcaKnowledge",
        "ArcaLLM",
      ]
    ),
    .target(name: "ArcaReporting", dependencies: ["ArcaDomain"]),
    .target(name: "ArcaSource", dependencies: ["ArcaDomain"]),
    .target(
      name: "ArcaCLI",
      dependencies: [
        "ArcaAnalyzers",
        "ArcaConfiguration",
        "ArcaDomain",
        "ArcaGit",
        "ArcaKnowledge",
        "ArcaLLM",
        "ArcaReporting",
        "ArcaSource",
      ]
    ),
    .executableTarget(
      name: "ArcaExecutable",
      dependencies: ["ArcaCLI"]
    ),
    .testTarget(
      name: "ArcaCLITests",
      dependencies: [
        "ArcaCLI",
        "ArcaDomain",
        "ArcaLLM",
      ]
    ),
    .testTarget(
      name: "ArcaConfigurationTests",
      dependencies: ["ArcaConfiguration", "ArcaDomain"]
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
      dependencies: ["ArcaDomain", "ArcaKnowledge", "ArcaLLM"]
    ),
    .testTarget(
      name: "ArcaAnalyzersTests",
      dependencies: [
        "ArcaAnalyzers",
        "ArcaDomain",
        "ArcaKnowledge",
        "ArcaLLM",
      ]
    ),
    .testTarget(
      name: "ArcaReportingTests",
      dependencies: ["ArcaDomain", "ArcaReporting"]
    ),
    .testTarget(
      name: "ArcaSourceTests",
      dependencies: ["ArcaSource", "ArcaDomain"]
    ),
  ]
)
