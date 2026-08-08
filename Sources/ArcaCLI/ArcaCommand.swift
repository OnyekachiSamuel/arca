import ArcaAnalysis
import ArcaAnalyzers
import ArcaConfiguration
import ArcaDomain
import ArcaGit
import ArcaKnowledge
import ArcaLLM
import ArcaReporting
import ArcaSource
import ArcaSwiftSyntax
import Foundation

public struct CommandResult: Equatable {
    public let output: String
    public let exitStatus: ArcaExitStatus
    public let outputDestination: CommandOutputDestination
    public let reviewRequest: ReviewRequest?

    public var exitCode: Int32 {
        exitStatus.rawValue
    }

    init(
        output: String,
        exitStatus: ArcaExitStatus,
        reviewRequest: ReviewRequest? = nil
    ) {
        self.output = output
        self.exitStatus = exitStatus
        outputDestination = exitStatus.outputDestination
        self.reviewRequest = reviewRequest
    }
}

public enum ArcaCommand {
    private static let sourceContextSurroundingLineCount = 3

    static let reviewHelp = """
    OVERVIEW: Review Swift code for anti-patterns and convention violations.

    USAGE: arca review [options]

    OPTIONS:
      --file <path>           Review an explicit Swift file.
      --changed               Review changed Swift files in the Git repository.
      --review <type>         Select a review; repeatable. Values: god-object, style, team-convention, all.
      --format <format>       Select output format. Values: terminal, json.
      --debug                 Print loaded source and metadata.
      -h, --help              Show help information.

    EXIT STATUS:
      0  Review completed without findings.
      1  Review completed with findings.
      2  Invalid input or configuration.
      3  Analyzer or internal execution failure.
    """

    static let llmHelp = """
    OVERVIEW: Analyze one Swift file using one isolated LLM prompt variant.

    USAGE: arca llm [options]

    OPTIONS:
      --file <path>           Analyze an explicit Swift file.
      --review <type>         Select one review. Values: god-object, style, team-convention.
      --prompt <variant>      Select prompt content. Values: baseline, guided.
      --format <format>       Select output format. Values: terminal, json. Default: terminal.
      -h, --help              Show help information.

    PROMPT VARIANTS:
      baseline                Source code and task instructions only.
      guided                  Includes rules and knowledge.

    EXIT STATUS:
      0  Analysis completed without findings.
      1  Analysis completed with findings.
      2  Invalid input or configuration.
      3  Provider, parser, or internal execution failure.
    """

    static let rootHelp = """
    OVERVIEW: A code review tool for Swift.

    USAGE: arca <command>

    COMMANDS:
      review                  Review Swift code.
      llm                     Run one isolated LLM code analysis.

    OPTIONS:
      -h, --help              Show help information.
    """

    public static func run(
        arguments: [String],
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        swiftLintAvailability: SwiftLintAvailability = .unavailable(
            .executableNotFound
        )
    ) async -> CommandResult {
        await execute(
            arguments: arguments,
            currentDirectory: currentDirectory,
            swiftLintAvailability: swiftLintAvailability,
            llmProvider: nil
        )
    }

    static func execute(
        arguments: [String],
        currentDirectory: String,
        swiftLintAvailability: SwiftLintAvailability,
        llmProvider: (any LLMProvider)?
    ) async -> CommandResult {
        switch arguments {
        case [], ["--help"], ["-h"]:
            return CommandResult(output: rootHelp, exitStatus: .success)
        case ["review", "--help"], ["review", "-h"]:
            return CommandResult(output: reviewHelp, exitStatus: .success)
        case ["llm", "--help"], ["llm", "-h"]:
            return CommandResult(output: llmHelp, exitStatus: .success)
        default:
            break
        }

        if arguments.first == "llm" {
            return await executeLLM(
                arguments: Array(arguments.dropFirst()),
                currentDirectory: currentDirectory,
                llmProvider: llmProvider
            )
        }

        guard arguments.first == "review" else {
            return CommandResult(
                output: "Error: unknown command or option. Run 'arca --help' for usage.",
                exitStatus: .invalidInput
            )
        }

        do {
            let options = try ReviewCommandParser().parse(
                arguments: Array(arguments.dropFirst())
            )
            guard let source = options.source else {
                return CommandResult(
                    output: "Error: No review source selected. Use --file or --changed.",
                    exitStatus: .invalidInput
                )
            }

            switch source {
            case .file(let path):
                return await reviewFile(
                    at: path,
                    debug: options.debug,
                    currentDirectory: currentDirectory,
                    reviewSelection: options.reviewSelection,
                    outputFormat: options.outputFormat,
                    swiftLintAvailability: swiftLintAvailability,
                    llmProvider: llmProvider
                )
            case .changed:
                return await reviewChanged(
                    from: currentDirectory,
                    reviewSelection: options.reviewSelection,
                    outputFormat: options.outputFormat,
                    swiftLintAvailability: swiftLintAvailability,
                    llmProvider: llmProvider
                )
            }
        } catch let error as ReviewCommandParsingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .invalidInput
            )
        } catch {
            return CommandResult(
                output: "Error: Review command failed unexpectedly.",
                exitStatus: .executionFailure
            )
        }
    }

    private static func executeLLM(
        arguments: [String],
        currentDirectory: String,
        llmProvider: (any LLMProvider)?
    ) async -> CommandResult {
        do {
            let options = try LLMCommandParser().parse(arguments: arguments)
            let selectedPath = try ExplicitSwiftFileSelector().select(
                path: options.filePath
            )
            let source = try SourceFileLoader().load(path: selectedPath)
            let environment = try loadReviewEnvironment(
                from: currentDirectory
            )
            guard let configuration = environment.configuration.llm else {
                return CommandResult(
                    output: "Error: The llm command requires an llm configuration in .arca.json.",
                    exitStatus: .invalidInput
                )
            }
            let provider = try llmProvider ?? LLMProviderFactory().make(
                configuration: configuration
            )
            let result = await LLMCodeAnalysisRunner(
                provider: provider,
                knowledgeProvider: try RuleKnowledgeRegistry.bundled(),
                modelID: configuration.modelID,
                timeout: .seconds(configuration.timeoutSeconds),
                seed: configuration.seed,
                temperature: configuration.temperature
            ).run(
                context: SourceFileAnalysisContext(
                    filePath: llmContextPath(
                        for: source.path,
                        repositoryRoot: environment.repositoryRootURL
                    ),
                    sourceContent: source.content,
                    lineCount: source.lineCount
                ),
                reviewType: options.reviewType,
                promptVariant: options.promptVariant
            )
            let exitStatus: ArcaExitStatus
            if !result.findings.isEmpty {
                exitStatus = .findingsDetected
            } else if !result.diagnostics.isEmpty {
                exitStatus = .executionFailure
            } else {
                exitStatus = .success
            }
            return CommandResult(
                output: try reporter(for: options.outputFormat).render(
                    llmRun: result
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
        } catch {
            return CommandResult(
                output: "Error: LLM code analysis failed unexpectedly.",
                exitStatus: .executionFailure
            )
        }
    }

    private static func reviewFile(
        at path: String,
        debug: Bool,
        currentDirectory: String,
        reviewSelection: ReviewSelection,
        outputFormat: ReviewOutputFormat,
        swiftLintAvailability: SwiftLintAvailability,
        llmProvider: (any LLMProvider)?
    ) async -> CommandResult {
        do {
            let selectedFile = try ExplicitSwiftFileSelector().select(path: path)
            return await reviewFiles(
                at: [selectedFile],
                debug: debug,
                failureDescription: "Swift file: \(path)",
                currentDirectory: currentDirectory,
                reviewSelection: reviewSelection,
                outputFormat: outputFormat,
                swiftLintAvailability: swiftLintAvailability,
                llmProvider: llmProvider
            )
        } catch let error as SourceSelectionError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .invalidInput
            )
        } catch {
            return CommandResult(
                output: "Error: Review failed for Swift file: \(path)",
                exitStatus: .executionFailure
            )
        }
    }

    private static func reviewChanged(
        from currentDirectory: String,
        reviewSelection: ReviewSelection,
        outputFormat: ReviewOutputFormat,
        swiftLintAvailability: SwiftLintAvailability,
        llmProvider: (any LLMProvider)?
    ) async -> CommandResult {
        do {
            let changes = try GitDiffProvider().extract(from: currentDirectory)
            let selectedFiles = changes.map(\.filePath)
            return await reviewFiles(
                at: selectedFiles,
                debug: false,
                failureDescription: "changed Swift files",
                currentDirectory: currentDirectory,
                reviewSelection: reviewSelection,
                outputFormat: outputFormat,
                swiftLintAvailability: swiftLintAvailability,
                llmProvider: llmProvider,
                changes: changes
            )
        } catch let error as GitRepositoryFinderError {
            let exitStatus: ArcaExitStatus
            switch error {
            case .notRepository:
                exitStatus = .invalidInput
            case .commandCouldNotRun, .invalidOutput:
                exitStatus = .executionFailure
            }
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: exitStatus
            )
        } catch let error as GitChangedSwiftFileFinderError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .executionFailure
            )
        } catch {
            return CommandResult(
                output: "Error: Could not select changed Swift files.",
                exitStatus: .executionFailure
            )
        }
    }

    private static func reviewFiles(
        at paths: [String],
        debug: Bool,
        failureDescription: String,
        currentDirectory: String,
        reviewSelection: ReviewSelection,
        outputFormat: ReviewOutputFormat,
        swiftLintAvailability: SwiftLintAvailability,
        llmProvider: (any LLMProvider)?,
        changes: [CodeChange] = []
    ) async -> CommandResult {
        do {
            let environment = try loadReviewEnvironment(
                from: currentDirectory
            )
            let sources = try paths.map { path in
                try SourceFileLoader().load(path: path)
            }
            let llmConfiguration = environment.configuration.llm
            let resolvedLLMProvider: (any LLMProvider)?
            let knowledgeProvider: RuleKnowledgeRegistry?
            if let llmConfiguration {
                resolvedLLMProvider = try llmProvider
                    ?? LLMProviderFactory().make(
                        configuration: llmConfiguration
                    )
                knowledgeProvider = try RuleKnowledgeRegistry.bundled()
            } else {
                resolvedLLMProvider = nil
                knowledgeProvider = nil
            }
            let structureProvider = SwiftSyntaxStructureProvider()
            let registry = AnalyzerRegistryFactory(
                swiftLintAvailability: swiftLintAvailability
            ).make(
                configuration: environment.configuration,
                structureProvider: structureProvider,
                workingDirectoryURL: environment.workingDirectoryURL,
                llmProvider: resolvedLLMProvider,
                knowledgeProvider: knowledgeProvider
            )
            let selectedReviewTypes = try resolveReviewTypes(
                reviewSelection,
                using: registry
            )
            let selectedAnalyzers = registry.analyzers(
                matching: selectedReviewTypes
            )
            let request = ReviewRequest(
                id: UUID(),
                repositoryRoot: environment.repositoryRootURL?.path,
                selectedFiles: paths,
                changes: changes,
                selectedReviewTypes: selectedReviewTypes,
                configuration: environment.configuration
            )

            if debug, let source = sources.first {
                let output = """
                Source: \(source.path)
                Lines: \(source.lineCount)

                \(source.content)
                """
                return CommandResult(
                    output: output,
                    exitStatus: .success,
                    reviewRequest: request
                )
            }

            let sourceContexts = try makeSourceContexts(
                sourceFiles: sources,
                changes: changes,
                provider: SwiftSyntaxSourceContextProvider(
                    structureProvider: structureProvider
                )
            )
            let context = AnalysisContext(
                request: request,
                sourceFiles: sources,
                sourceContexts: sourceContexts
            )
            let analysis = try await ReviewEngine().review(
                analyzers: selectedAnalyzers,
                context: context
            )
            let reporter = reporter(for: outputFormat)

            guard let llmConfiguration,
                  let resolvedLLMProvider,
                  let knowledgeProvider else {
                return CommandResult(
                    output: try reporter.render(analysis: analysis),
                    exitStatus: analysis.candidates.isEmpty
                        ? .success
                        : .findingsDetected,
                    reviewRequest: request
                )
            }

            guard !analysis.candidates.isEmpty else {
                let report = CategorizedReviewReportBuilder().build(
                    from: ReviewCategorizationResult(
                        analysis: analysis,
                        categorization: FindingCategorization(
                            summary: "No candidate findings were detected.",
                            decisions: []
                        ),
                        categorizationDiagnostics: [],
                        llmExecutionMetadata: LLMExecutionMetadata(
                            providerID: llmConfiguration.providerID,
                            modelID: llmConfiguration.modelID,
                            requestCount: 0,
                            providerDurationMilliseconds: 0
                        )
                    )
                )
                return CommandResult(
                    output: try reporter.render(report: report),
                    exitStatus: containsProviderFailure(
                        analysis.diagnostics
                    ) ? .executionFailure : .success,
                    reviewRequest: request
                )
            }

            let selectedRules = ReviewRuleSelector().rules(
                for: selectedReviewTypes,
                from: knowledgeProvider
            )
            let categorization = await LLMFindingCategorizer(
                provider: resolvedLLMProvider,
                modelID: llmConfiguration.modelID,
                timeout: .seconds(llmConfiguration.timeoutSeconds),
                seed: llmConfiguration.seed,
                temperature: llmConfiguration.temperature
            ).categorize(
                analysis: analysis,
                ruleKnowledge: selectedRules
            )
            let report = CategorizedReviewReportBuilder().build(
                from: categorization
            )
            return CommandResult(
                output: try reporter.render(report: report),
                exitStatus: exitStatus(for: report),
                reviewRequest: request
            )
        } catch let error as ReviewCommandParsingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .invalidInput
            )
        } catch let error as ConfigurationLoadingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .invalidInput
            )
        } catch let error as SourceLoadingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .invalidInput
            )
        } catch let error as SwiftLintAvailabilityError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitStatus: .executionFailure
            )
        } catch {
            return CommandResult(
                output: "Error: Review failed for \(failureDescription)",
                exitStatus: .executionFailure
            )
        }
    }

    private static func exitStatus(
        for report: CategorizedReviewReport
    ) -> ArcaExitStatus {
        if containsProviderFailure(report.diagnostics)
            || (report.counts.totalCandidates > 0
                && report.categorizationSummary == nil) {
            return .executionFailure
        }
        return report.confirmedFindings.isEmpty
            && report.uncertainFindings.isEmpty
            ? .success
            : .findingsDetected
    }

    private static func containsProviderFailure(
        _ diagnostics: [AnalyzerDiagnostic]
    ) -> Bool {
        diagnostics.contains {
            $0.code == "ARCA-LLM-ANALYSIS-PROVIDER-FAILED"
                || $0.code
                    == "ARCA-LLM-CATEGORIZATION-PROVIDER-FAILED"
        }
    }

    private static func reporter(
        for outputFormat: ReviewOutputFormat
    ) -> any Reporter {
        switch outputFormat {
        case .terminal:
            TerminalReporter()
        case .json:
            JSONReporter()
        }
    }

    private static func resolveReviewTypes(
        _ selection: ReviewSelection,
        using registry: AnalyzerRegistry
    ) throws -> Set<ReviewType> {
        switch selection {
        case .all:
            return registry.supportedReviewTypes
        case .types(let requestedReviewTypes):
            let unavailableReviewTypes = requestedReviewTypes.subtracting(
                registry.supportedReviewTypes
            )
            guard let unavailableReviewType = unavailableReviewTypes.sorted(
                by: { $0.commandLineName < $1.commandLineName }
            ).first else {
                return requestedReviewTypes
            }

            let availableValues = registry.supportedReviewTypes
                .map(\.commandLineName)
                .sorted() + ["all"]
            throw ReviewCommandParsingError.unavailableReviewType(
                unavailableReviewType.commandLineName,
                availableValues: availableValues
            )
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
            repositoryRootURL: repositoryRoot.map {
                URL(fileURLWithPath: $0, isDirectory: true)
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
            },
            workingDirectoryURL: workingDirectoryURL
        )
    }

    private static func llmContextPath(
        for path: String,
        repositoryRoot: URL?
    ) -> String {
        let fileURL = URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard let repositoryRoot,
              fileURL.pathComponents.starts(
                with: repositoryRoot.pathComponents
              ) else {
            return fileURL.lastPathComponent
        }

        return fileURL.pathComponents
            .dropFirst(repositoryRoot.pathComponents.count)
            .joined(separator: "/")
    }

    private static func makeSourceContexts(
        sourceFiles: [SourceFile],
        changes: [CodeChange],
        provider: any SourceContextProvider
    ) throws -> [SourceContextWindow] {
        try sourceFiles.flatMap { sourceFile -> [SourceContextWindow] in
            guard let change = changes.first(where: {
                $0.filePath == sourceFile.path
            }) else {
                return []
            }

            return try provider.contexts(
                for: change,
                in: sourceFile,
                surroundingLineCount: sourceContextSurroundingLineCount
            )
        }
    }

}

private struct ReviewEnvironment {
    let configuration: ArcaConfiguration
    let repositoryRootURL: URL?
    let workingDirectoryURL: URL
}
