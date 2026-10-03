import ArcaAnalyzers
import ArcaConfiguration
import ArcaDomain
import ArcaGit
import ArcaKnowledge
import ArcaLLM
import ArcaReporting
import ArcaSource
import Foundation

public struct CommandResult: Equatable {
    public let output: String
    public let exitStatus: ArcaExitStatus
    public let outputDestination: CommandOutputDestination
    
    public var exitCode: Int32 { exitStatus.rawValue }
    
    init(
        output: String,
        exitStatus: ArcaExitStatus
    ) {
        self.output = output
        self.exitStatus = exitStatus
        outputDestination = exitStatus.outputDestination
    }
}

public enum ArcaCommand {
    static let help = """
    OVERVIEW: Detect Swift code issues using one LLM prompt variant.
    
    USAGE: arca --file <path> --prompt <variant> [options]
    
    OPTIONS:
      --file <path>           Analyze an explicit Swift file.
      --review <type>         Guided only. Values: swift, swiftui, tca, security, god-object, all.
      --prompt <variant>      Select prompt content. Values: baseline, guided.
      --provider <id>         Select a configured provider. Default: llm.defaultProvider.
      --format <format>       Show terminal output or save JSON. Values: terminal, json. Default: terminal.
      --show-prompt           Display the exact prompt sent to the LLM.
      -h, --help              Show help information.
    
    PROMPT VARIANTS:
      baseline                Source and broad instructions only; omit --review.
      guided                  Includes the selected rules and supporting knowledge.
    
    ALL RULE SETS:
      Guided analysis runs each rule set separately and aggregates the findings.
      The all selection is available only for guided analysis.
    
    EXIT STATUS:
      0  Analysis completed without findings.
      1  Analysis completed with findings.
      2  Invalid input or configuration.
      3  Provider, parser, or internal execution failure.
    """
    
    public static func run(
        arguments: [String],
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        progress: (@Sendable (String) -> Void)? = nil
    ) async -> CommandResult {
        await execute(
            arguments: arguments,
            currentDirectory: currentDirectory,
            llmProvider: nil,
            progress: progress
        )
    }
    
    static func execute(
        arguments: [String],
        currentDirectory: String,
        llmProvider: (any LLMProvider)?,
        progress: (@Sendable (String) -> Void)? = nil
    ) async -> CommandResult {
        switch arguments {
        case [], ["--help"], ["-h"]:
            return CommandResult(output: help, exitStatus: .success)
        default:
            break
        }
        
        return await executeAnalysis(
            arguments: arguments,
            currentDirectory: currentDirectory,
            llmProvider: llmProvider,
            progress: progress
        )
    }
    
    private static func executeAnalysis(
        arguments: [String],
        currentDirectory: String,
        llmProvider: (any LLMProvider)?,
        progress: (@Sendable (String) -> Void)?
    ) async -> CommandResult {
        do {
            let options = try LLMCommandParser().parse(arguments: arguments)
            let fileSelector = ExplicitSwiftFileSelector()
            let selectedPath = try fileSelector.select(path: options.filePath)
            let source = try SourceFileLoader().load(path: selectedPath)
            let environment = try loadReviewEnvironment(from: currentDirectory)
            let changes = try selectedFileChanges(
                filePath: source.path,
                repositoryRootURL: environment.repositoryRootURL
            )
            guard let llmConfiguration = environment.configuration.llm else {
                return CommandResult(
                    output: "Error: ARCA requires an llm configuration in .arca.json.",
                    exitStatus: .invalidInput
                )
            }
            guard
                let configuration = llmConfiguration.provider(id: options.providerID)
            else {
                let requestedProvider =
                options.providerID ?? llmConfiguration.defaultProvider
                return CommandResult(
                    output: "Error: LLM provider '\(requestedProvider)' is not configured.",
                    exitStatus: .invalidInput
                )
            }
            let provider =
            try llmProvider
            ?? LLMProviderFactory().make(
                configuration: configuration
            )
            let analysisProvider: any LLMProvider
            let promptRecorder: PromptRecordingLLMProvider?
            if options.showPrompt {
                let recorder = PromptRecordingLLMProvider(provider: provider)
                analysisProvider = recorder
                promptRecorder = recorder
            } else {
                analysisProvider = provider
                promptRecorder = nil
            }
            let knowledgeProvider: RuleKnowledgeRegistry? =
            options.promptVariant == .guided
            ? try RuleKnowledgeRegistry.bundled()
            : nil
            let requestID = UUID()
            let sourceContext = SourceFileAnalysisContextBuilder().build(
                sourceFile: source,
                repositoryRoot: environment.repositoryRootURL?.path,
                changes: changes
            )
            
            let reviewTypesToRun: [ReviewType?]
            if options.reviewType == .all {
                reviewTypesToRun = ReviewType.analysisTypes.map(Optional.some)
            } else if let reviewType = options.reviewType {
                reviewTypesToRun = [reviewType]
            } else {
                reviewTypesToRun = [nil]
            }
            
            var results: [LLMIssueDetectionResult] = []
            progress?("Waiting for the LLM response...")
            for reviewType in reviewTypesToRun {
                let rules =
                reviewType.map {
                    knowledgeProvider?.knowledge(for: $0) ?? []
                } ?? []
                let analyzer = LLMCodeAnalyzer(
                    provider: analysisProvider,
                    promptVariant: options.promptVariant,
                    modelID: configuration.modelID,
                    timeout: .seconds(configuration.timeoutSeconds),
                    seed: configuration.seed,
                    temperature: configuration.temperature
                )
                let llmResponse = await analyzer.analyze(context: sourceContext, rules: rules)
                results.append(llmResponse)
            }
            
            let result = combinedLLMResult(
                results,
                providerID: analysisProvider.id,
                modelID: configuration.modelID
            )
            let displayedPrompts = await promptRecorder?.recordedPrompts() ?? []
            let exitStatus: ArcaExitStatus
            if !result.candidates.isEmpty {
                exitStatus = .findingsDetected
            } else if !result.diagnostics.isEmpty {
                exitStatus = .executionFailure
            } else {
                exitStatus = .success
            }
            let report = LLMIssueDetectionReport(
                requestID: requestID,
                filePath: sourceContext.filePath,
                reviewType: options.reviewType,
                promptVariant: options.promptVariant,
                analysis: result,
                seed: configuration.seed,
                temperature: configuration.temperature
            )
            if options.outputFormat == .json {
                let json = try JSONReporter().render(detectionReport: report)
                let destination = try JSONReportWriter().write(
                    json,
                    report: report,
                    resultsRoot: environment.outputRootURL
                )
                return CommandResult(
                    output: output(
                        including: displayedPrompts,
                        result: "JSON report written to: \(destination.path)"
                    ),
                    exitStatus: exitStatus
                )
            }
            return CommandResult(
                output: output(
                    including: displayedPrompts,
                    result: try TerminalReporter().render(
                        detectionReport: report
                    )
                ),
                exitStatus: exitStatus
            )
        } catch let error as LLMCommandParsingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .invalidInput
            )
        } catch let error as SourceSelectionError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .invalidInput
            )
        } catch let error as SourceLoadingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .invalidInput
            )
        } catch let error as ConfigurationLoadingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .invalidInput
            )
        } catch let error as JSONReportWritingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .executionFailure
            )
        } catch {
            return CommandResult(
                output: "Error: LLM code analysis failed unexpectedly.",
                exitStatus: .executionFailure
            )
        }
    }
    
    private static func output(
        including prompts: [String],
        result: String
    ) -> String {
        guard !prompts.isEmpty else { return result }
        
        let renderedPrompts = prompts.enumerated().map { index, prompt in
            let heading =
            prompts.count == 1
            ? "Prompt sent to LLM"
            : "Prompt \(index + 1) of \(prompts.count) sent to LLM"
            return """
        \(heading)
        \(String(repeating: "-", count: heading.count))
        \(prompt)
        """
        }
        return renderedPrompts.joined(separator: "\n\n") + "\n\n" + result
    }
    
    private static func combinedLLMResult(
        _ results: [LLMIssueDetectionResult],
        providerID: String,
        modelID: String
    ) -> LLMIssueDetectionResult {
        func sum(_ values: [Int?]) -> Int? {
            let present = values.compactMap { $0 }
            return present.isEmpty ? nil : present.reduce(0, +)
        }
        
        let metadata = results.map(\.executionMetadata)
        return LLMIssueDetectionResult(
            candidates: results.flatMap(\.candidates),
            diagnostics: results.flatMap(\.diagnostics),
            executionMetadata: LLMExecutionMetadata(
                providerID: providerID,
                modelID: modelID,
                requestCount: metadata.reduce(0) { $0 + $1.requestCount },
                usage: LLMTokenUsageMetadata(
                    inputTokens: sum(metadata.map { $0.usage.inputTokens }),
                    outputTokens: sum(metadata.map { $0.usage.outputTokens }),
                    totalTokens: sum(metadata.map { $0.usage.totalTokens })
                ),
                providerDurationMilliseconds: metadata.reduce(0) {
                    $0 + $1.providerDurationMilliseconds
                }
            )
        )
    }
    
    private static func selectedFileChanges(
        filePath: String,
        repositoryRootURL: URL?
    ) throws -> [CodeChange] {
        guard let repositoryRootURL else { return [] }
        
        let selectedPath = URL(fileURLWithPath: filePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        return try GitDiffProvider()
            .extract(from: repositoryRootURL.path)
            .filter {
                URL(fileURLWithPath: $0.filePath)
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
                    .path == selectedPath
            }
    }
    
    private static func loadReviewEnvironment(
        from currentDirectory: String
    ) throws -> ReviewEnvironment {
        let configurationDirectory: String
        let repositoryRoot: String?
        do {
            let discoveredRoot = try GitRepositoryFinder().discover(
                from: currentDirectory
            )
            configurationDirectory = discoveredRoot
            repositoryRoot = discoveredRoot
        } catch let error as GitRepositoryFinderError {
            switch error {
            case .notRepository:
                configurationDirectory = currentDirectory
                repositoryRoot = nil
            case .commandCouldNotRun, .invalidOutput:
                throw error
            }
        }
        
        let workingDirectoryURL = URL(
            fileURLWithPath: configurationDirectory,
            isDirectory: true
        ).standardizedFileURL
        return ReviewEnvironment(
            configuration: try ConfigurationLoader().load(
                from: workingDirectoryURL
            ),
            outputRootURL: workingDirectoryURL,
            repositoryRootURL: repositoryRoot.map {
                URL(fileURLWithPath: $0, isDirectory: true)
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
            }
        )
    }
}

private actor PromptRecordingLLMProvider: LLMProvider {
    nonisolated let id: String
    
    private let provider: any LLMProvider
    private var prompts: [String] = []
    
    init(provider: any LLMProvider) {
        id = provider.id
        self.provider = provider
    }
    
    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        prompts.append(request.prompt)
        return try await provider.submit(request)
    }
    
    func recordedPrompts() -> [String] {
        prompts
    }
}

private struct ReviewEnvironment {
    let configuration: ArcaConfiguration
    let outputRootURL: URL
    let repositoryRootURL: URL?
}
