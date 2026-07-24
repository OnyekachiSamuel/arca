import ArcanAnalysis
import ArcanAnalyzers
import ArcanConfiguration
import ArcanDomain
import ArcanGit
import ArcanKnowledge
import ArcanLLM
import ArcanReporting
import ArcanSource
import ArcanSwiftSyntax
import Foundation

public struct CommandResult: Equatable {
    public let output: String
    public let exitStatus: ArcanExitStatus
    public let outputDestination: CommandOutputDestination
    public let reviewRequest: ReviewRequest?

    public var exitCode: Int32 {
        exitStatus.rawValue
    }

    init(
        output: String,
        exitStatus: ArcanExitStatus,
        reviewRequest: ReviewRequest? = nil
    ) {
        self.output = output
        self.exitStatus = exitStatus
        outputDestination = exitStatus.outputDestination
        self.reviewRequest = reviewRequest
    }
}

public enum ArcanCommand {
    private static let sourceContextSurroundingLineCount = 3

    static let reviewHelp = """
    OVERVIEW: Review Swift code for anti-patterns and convention violations.

    USAGE: arcan review [options]

    OPTIONS:
      --file <path>           Review an explicit Swift file.
      --changed               Review changed Swift files in the Git repository.
      --review <type>         Select a review; repeatable. Values: god-object, style, all.
      --format <format>       Select output format. Values: terminal, json.
      --debug                 Print loaded source and metadata.
      -h, --help              Show help information.

    EXIT STATUS:
      0  Review completed without findings.
      1  Review completed with findings.
      2  Invalid input or configuration.
      3  Analyzer or internal execution failure.
    """

    static let rootHelp = """
    OVERVIEW: A code review tool for Swift.

    USAGE: arcan <command>

    COMMANDS:
      review                  Review Swift code.

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
        default:
            break
        }

        guard arguments.first == "review" else {
            return CommandResult(
                output: "Error: unknown command or option. Run 'arcan --help' for usage.",
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
            let exitStatus: ArcanExitStatus
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
            let structureProvider = SwiftSyntaxStructureProvider()
            let registry = AnalyzerRegistryFactory(
                swiftLintAvailability: swiftLintAvailability
            ).make(
                configuration: environment.configuration,
                structureProvider: structureProvider,
                workingDirectoryURL: environment.workingDirectoryURL
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
            let baselineReport = try await ReviewEngine().review(
                analyzers: selectedAnalyzers,
                context: context
            )
            let report = try await generateTargetedSuggestions(
                in: baselineReport,
                configuration: environment.configuration.llm,
                llmProvider: llmProvider,
                sourceFiles: sources,
                sourceContexts: sourceContexts,
                repositoryRoot: request.repositoryRoot,
                contextProvider: SwiftSyntaxSourceContextProvider(
                    structureProvider: structureProvider
                )
            )
            let reporter = reporter(for: outputFormat)
            return CommandResult(
                output: try reporter.render(report: report),
                exitStatus: report.findings.isEmpty
                    ? .success
                    : .findingsDetected,
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

    private static func generateTargetedSuggestions(
        in report: ReviewReport,
        configuration: LLMConfiguration?,
        llmProvider: (any LLMProvider)?,
        sourceFiles: [SourceFile],
        sourceContexts: [SourceContextWindow],
        repositoryRoot: String?,
        contextProvider: any SourceContextProvider
    ) async throws -> ReviewReport {
        guard let configuration else { return report }

        let knowledgeRegistry = try RuleKnowledgeRegistry.bundled()
        guard let baseURL = URL(string: configuration.baseURL) else {
            throw LLMServerProviderError.invalidServerConfiguration
        }
        let provider: any LLMProvider = llmProvider
            ?? LLMServerProvider(
                configuration: LLMServerConfiguration(
                    providerID: configuration.providerID,
                    baseURL: baseURL,
                    completionPath: configuration.completionPath,
                    apiKey: ProcessInfo.processInfo.environment[
                        "ARCAN_LLM_API_KEY"
                    ]
                )
            )
        let generator = LLMSuggestionGenerator(
            provider: provider,
            promptBuilder: SuggestionPromptBuilder(
                knowledgeProvider: knowledgeRegistry
            ),
            modelID: configuration.modelID,
            timeout: .seconds(configuration.timeoutSeconds),
            seed: configuration.seed,
            temperature: configuration.temperature
        )
        var generatedResults: [AnalyzerResult] = []

        for result in report.analyzerResults {
            var findings: [Finding] = []
            var diagnostics = result.diagnostics

            for finding in result.findings {
                guard knowledgeRegistry.knowledge(for: finding.ruleID) != nil
                else {
                    findings.append(finding)
                    continue
                }
                guard let sourceContext = try sourceContext(
                    for: finding,
                    sourceFiles: sourceFiles,
                    existingContexts: sourceContexts,
                    repositoryRoot: repositoryRoot,
                    provider: contextProvider
                ) else {
                    findings.append(finding)
                    diagnostics.append(
                        AnalyzerDiagnostic(
                            code: "ARCAN-LLM-SUGGESTION-CONTEXT-UNAVAILABLE",
                            severity: .warning,
                            message: "A bounded source context was unavailable, so the deterministic suggestion was kept."
                        )
                    )
                    continue
                }

                do {
                    switch try await generator.generate(
                        for: finding,
                        sourceContext: sourceContext
                    ) {
                    case .parsed(let suggestion):
                        findings.append(finding.withSuggestion(suggestion))
                    case .rejected(let diagnostic):
                        findings.append(finding)
                        diagnostics.append(diagnostic)
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    findings.append(finding)
                    diagnostics.append(
                        AnalyzerDiagnostic(
                            code: "ARCAN-LLM-SUGGESTION-FAILED",
                            severity: .warning,
                            message: "The LLM suggestion could not be generated, so the deterministic suggestion was kept."
                        )
                    )
                }
            }

            generatedResults.append(
                AnalyzerResult(
                    analyzerID: result.analyzerID,
                    findings: findings,
                    tool: result.tool,
                    executionStatus: result.executionStatus,
                    diagnostics: diagnostics,
                    durationMilliseconds: result.durationMilliseconds
                )
            )
        }

        return ReviewReport(
            schemaVersion: report.schemaVersion,
            requestID: report.requestID,
            findings: generatedResults.flatMap(\.findings),
            analyzerResults: generatedResults
        )
    }

    private static func sourceContext(
        for finding: Finding,
        sourceFiles: [SourceFile],
        existingContexts: [SourceContextWindow],
        repositoryRoot: String?,
        provider: any SourceContextProvider
    ) throws -> SourceContextWindow? {
        guard let findingRange = finding.range,
              let sourceFile = sourceFiles.first(where: {
                  pathsReferToSameFile(
                      $0.path,
                      findingPath: finding.filePath,
                      repositoryRoot: repositoryRoot
                  )
              }) else {
            return nil
        }

        if let context = existingContexts
            .filter({ $0.filePath == sourceFile.path })
            .filter({
                rangesOverlap(
                    startLine: $0.changedLineRange.startLine,
                    endLine: $0.changedLineRange.endLine,
                    findingRange: findingRange
                )
            })
            .sorted(by: {
                $0.changedLineRange.startLine < $1.changedLineRange.startLine
            })
            .first {
            return context
        }

        let endLine = min(findingRange.endLine, sourceFile.lineCount)
        guard findingRange.startLine <= endLine else { return nil }

        return try provider.contexts(
            for: CodeChange(
                filePath: sourceFile.path,
                modifiedLineRanges: [
                    ChangedLineRange(
                        startLine: findingRange.startLine,
                        endLine: endLine
                    )
                ]
            ),
            in: sourceFile,
            surroundingLineCount: sourceContextSurroundingLineCount
        ).first
    }

    private static func pathsReferToSameFile(
        _ sourcePath: String,
        findingPath: String,
        repositoryRoot: String?
    ) -> Bool {
        let sourceURL = URL(fileURLWithPath: sourcePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let findingURL: URL

        if findingPath.hasPrefix("/") {
            findingURL = URL(fileURLWithPath: findingPath)
        } else if let repositoryRoot {
            findingURL = URL(
                fileURLWithPath: repositoryRoot,
                isDirectory: true
            ).appendingPathComponent(findingPath)
        } else {
            findingURL = URL(fileURLWithPath: findingPath)
        }

        return sourceURL.path
            == findingURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func rangesOverlap(
        startLine: Int,
        endLine: Int,
        findingRange: SourceRange
    ) -> Bool {
        startLine <= findingRange.endLine
            && endLine >= findingRange.startLine
    }
}

private struct ReviewEnvironment {
    let configuration: ArcanConfiguration
    let repositoryRootURL: URL?
    let workingDirectoryURL: URL
}
