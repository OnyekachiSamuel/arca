import ArcaAnalysis
import ArcaDomain
import ArcaKnowledge
import ArcaLLM
import ArcaProcess
import Foundation
import Testing
@testable import ArcaCLI

@Suite("Analyzer registry factory")
struct AnalyzerRegistryFactoryTests {
    @Test("registers SwiftLint when its executable is available")
    func registersSwiftLint() {
        let executable = URL(fileURLWithPath: "/tools/swiftlint")
        let factory = AnalyzerRegistryFactory(
            swiftLintAvailability: .available(executable),
            processRunner: RegistryFactoryProcessRunner()
        )

        let registry = factory.make(
            configuration: .defaults,
            structureProvider: RegistryFactoryStructureProvider(),
            workingDirectoryURL: URL(
                fileURLWithPath: "/project",
                isDirectory: true
            )
        )

        #expect(
            registry.supportedReviewTypes
                == [.godObject, .style, .teamConvention]
        )
        #expect(
            registry.analyzers(matching: [.style]).map(\.id)
                == ["swiftlint"]
        )
    }

    @Test("keeps style registered when SwiftLint is unavailable")
    func registersUnavailableSwiftLint() {
        let factory = AnalyzerRegistryFactory(
            swiftLintAvailability: .unavailable(.executableNotFound)
        )

        let registry = factory.make(
            configuration: .defaults,
            structureProvider: RegistryFactoryStructureProvider(),
            workingDirectoryURL: URL(
                fileURLWithPath: "/project",
                isDirectory: true
            )
        )

        #expect(
            registry.supportedReviewTypes
                == [.godObject, .style, .teamConvention]
        )
        #expect(
            registry.analyzers(matching: [.style]).map(\.id)
                == ["swiftlint"]
        )
    }

    @Test("registers one LLM analyzer for every review concern")
    func registersConfiguredLLMAnalyzer() {
        let factory = AnalyzerRegistryFactory(
            swiftLintAvailability: .available(
                URL(fileURLWithPath: "/tools/swiftlint")
            ),
            processRunner: RegistryFactoryProcessRunner()
        )
        let configuration = ArcaConfiguration(
            schemaVersion: ArcaConfiguration.currentSchemaVersion,
            godObjectThresholds: GodObjectThresholds(),
            llm: LLMConfiguration(
                providerID: "mock-provider",
                baseURL: "http://127.0.0.1:8080",
                modelID: "mock-model"
            )
        )

        let registry = factory.make(
            configuration: configuration,
            structureProvider: RegistryFactoryStructureProvider(),
            workingDirectoryURL: URL(fileURLWithPath: "/project"),
            llmProvider: RegistryFactoryLLMProvider(),
            knowledgeProvider: RegistryFactoryKnowledgeProvider()
        )

        #expect(registry.supportedReviewTypes == Set(ReviewType.allCases))
        #expect(
            registry.analyzers(matching: [.godObject]).map(\.id)
                == ["god-object", "llm-code-analysis"]
        )
        #expect(
            registry.analyzers(matching: [.style]).map(\.id)
                == ["swiftlint", "llm-code-analysis"]
        )
        #expect(
            registry.analyzers(
                matching: [.godObject, .style, .teamConvention]
            ).map(\.id) == [
                "god-object", "swiftlint", "llm-code-analysis"
            ]
        )
    }
}

private struct RegistryFactoryProcessRunner: ProcessRunning {
    func run(_ request: ProcessRequest) async throws -> ProcessResult {
        ProcessResult(
            standardOutput: Data("[]".utf8),
            standardError: Data(),
            status: .exited(code: 0),
            durationMilliseconds: 0
        )
    }
}

private struct RegistryFactoryStructureProvider: SwiftStructureProvider {
    func extractMetrics(
        from sourceFile: SourceFile
    ) throws -> [TypeStructuralMetrics] {
        []
    }
}

private struct RegistryFactoryLLMProvider: LLMProvider {
    let id = "mock-provider"

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(
            text: #"{"findings":[]}"#,
            usage: LLMUsageMetadata(),
            durationMilliseconds: 0
        )
    }
}

private struct RegistryFactoryKnowledgeProvider: RuleKnowledgeProviding {
    let allKnowledge: [RuleKnowledge] = []

    func knowledge(for ruleID: String) -> RuleKnowledge? { nil }

    func knowledge(in group: RuleKnowledgeGroup) -> [RuleKnowledge] { [] }
}
