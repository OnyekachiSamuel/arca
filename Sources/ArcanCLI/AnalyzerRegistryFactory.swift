import ArcanAnalysis
import ArcanAnalyzers
import ArcanDomain
import ArcanKnowledge
import ArcanLLM
import ArcanProcess
import Foundation

struct AnalyzerRegistryFactory: Sendable {
    private let swiftLintAvailability: SwiftLintAvailability
    private let processRunner: (any ProcessRunning)?

    init(
        swiftLintAvailability: SwiftLintAvailability,
        processRunner: (any ProcessRunning)? = nil
    ) {
        self.swiftLintAvailability = swiftLintAvailability
        self.processRunner = processRunner
    }

    func make(
        configuration: ArcanConfiguration,
        structureProvider: any SwiftStructureProvider,
        workingDirectoryURL: URL,
        llmProvider: (any LLMProvider)? = nil,
        knowledgeProvider: (any RuleKnowledgeProviding)? = nil
    ) -> AnalyzerRegistry {
        var analyzers: [any Analyzer] = [
            GodObjectAnalyzer(
                thresholds: configuration.godObjectThresholds,
                structureProvider: structureProvider
            )
        ]

        switch swiftLintAvailability {
        case .available(let swiftLintExecutableURL):
            let runner: any ProcessRunning
            if let processRunner {
                runner = processRunner
            } else {
                runner = ProcessRunner(
                    approvedExecutableURLs: [swiftLintExecutableURL]
                )
            }
            analyzers.append(SwiftLintAnalyzer(
                executableURL: swiftLintExecutableURL,
                workingDirectoryURL: workingDirectoryURL,
                availabilityPolicy: configuration.swiftLint.availability,
                processRunner: runner
            ))
        case .unavailable(let reason):
            analyzers.append(UnavailableSwiftLintAnalyzer(
                reason: reason,
                policy: configuration.swiftLint.availability
            ))
        }

        if let llmConfiguration = configuration.llm,
           let llmProvider,
           let knowledgeProvider {
            analyzers.append(LLMCodeAnalyzer(
                provider: llmProvider,
                knowledgeProvider: knowledgeProvider,
                modelID: llmConfiguration.modelID,
                timeout: .seconds(llmConfiguration.timeoutSeconds),
                seed: llmConfiguration.seed,
                temperature: llmConfiguration.temperature
            ))
        }

        return AnalyzerRegistry(analyzers: analyzers)
    }
}
