import ArcanAnalysis
import ArcanAnalyzers
import ArcanConfiguration
import ArcanDomain
import ArcanGit
import ArcanReporting
import ArcanSource
import ArcanSwiftSyntax
import Foundation

public struct CommandResult: Equatable {
    public let output: String
    public let exitCode: Int32
    public let reviewRequest: ReviewRequest?

    init(
        output: String,
        exitCode: Int32,
        reviewRequest: ReviewRequest? = nil
    ) {
        self.output = output
        self.exitCode = exitCode
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
      --review <type>         Select a review; repeatable. Values: god-object, all.
      --format <format>       Select output format. Values: terminal, json.
      --debug                 Print loaded source and metadata.
      -h, --help              Show help information.
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
        currentDirectory: String = FileManager.default.currentDirectoryPath
    ) async -> CommandResult {
        switch arguments {
        case [], ["--help"], ["-h"]:
            return CommandResult(output: rootHelp, exitCode: 0)
        case ["review", "--help"], ["review", "-h"]:
            return CommandResult(output: reviewHelp, exitCode: 0)
        default:
            break
        }

        guard arguments.first == "review" else {
            return CommandResult(
                output: "Error: unknown command or option. Run 'arcan --help' for usage.",
                exitCode: 64
            )
        }

        do {
            let options = try ReviewCommandParser().parse(
                arguments: Array(arguments.dropFirst())
            )
            guard let source = options.source else {
                return CommandResult(
                    output: "No Swift file selected. Run 'arcan review --help' for usage.",
                    exitCode: 0
                )
            }

            switch source {
            case .file(let path):
                return await reviewFile(
                    at: path,
                    debug: options.debug,
                    currentDirectory: currentDirectory,
                    reviewSelection: options.reviewSelection,
                    outputFormat: options.outputFormat
                )
            case .changed:
                return await reviewChanged(
                    from: currentDirectory,
                    reviewSelection: options.reviewSelection,
                    outputFormat: options.outputFormat
                )
            }
        } catch let error as ReviewCommandParsingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitCode: 64
            )
        } catch {
            return CommandResult(
                output: "Error: unknown command or option. Run 'arcan --help' for usage.",
                exitCode: 64
            )
        }
    }

    private static func reviewFile(
        at path: String,
        debug: Bool,
        currentDirectory: String,
        reviewSelection: ReviewSelection,
        outputFormat: ReviewOutputFormat
    ) async -> CommandResult {
        do {
            let selectedFile = try ExplicitSwiftFileSelector().select(path: path)
            return await reviewFiles(
                at: [selectedFile],
                debug: debug,
                failureDescription: "Swift file: \(path)",
                currentDirectory: currentDirectory,
                reviewSelection: reviewSelection,
                outputFormat: outputFormat
            )
        } catch let error as SourceSelectionError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitCode: 64
            )
        } catch {
            return CommandResult(
                output: "Error: Review failed for Swift file: \(path)",
                exitCode: 64
            )
        }
    }

    private static func reviewChanged(
        from currentDirectory: String,
        reviewSelection: ReviewSelection,
        outputFormat: ReviewOutputFormat
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
                changes: changes
            )
        } catch let error as GitRepositoryFinderError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitCode: 64
            )
        } catch let error as GitChangedSwiftFileFinderError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitCode: 64
            )
        } catch {
            return CommandResult(
                output: "Error: Could not select changed Swift files.",
                exitCode: 64
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
        changes: [CodeChange] = []
    ) async -> CommandResult {
        do {
            let configuration = try loadConfiguration(
                from: currentDirectory
            )
            let sources = try paths.map { path in
                try SourceFileLoader().load(path: path)
            }
            let structureProvider = SwiftSyntaxStructureProvider()
            let registry = AnalyzerRegistry(analyzers: [
                GodObjectAnalyzer(
                    thresholds: configuration.godObjectThresholds,
                    structureProvider: structureProvider
                )
            ])
            let selectedReviewTypes = try resolveReviewTypes(
                reviewSelection,
                using: registry
            )
            let selectedAnalyzers = registry.analyzers(
                matching: selectedReviewTypes
            )
            let request = ReviewRequest(
                id: UUID(),
                selectedFiles: paths,
                changes: changes,
                selectedReviewTypes: selectedReviewTypes,
                configuration: configuration
            )

            if debug, let source = sources.first {
                let output = """
                Source: \(source.path)
                Lines: \(source.lineCount)

                \(source.content)
                """
                return CommandResult(
                    output: output,
                    exitCode: 0,
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
            let report = try await ReviewEngine().review(
                analyzers: selectedAnalyzers,
                context: context
            )
            let reporter = reporter(for: outputFormat)
            return CommandResult(
                output: try reporter.render(report: report),
                exitCode: 0,
                reviewRequest: request
            )
        } catch let error as ReviewCommandParsingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitCode: 64
            )
        } catch let error as ConfigurationLoadingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitCode: 64
            )
        } catch let error as SourceLoadingError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitCode: 64
            )
        } catch {
            return CommandResult(
                output: "Error: Review failed for \(failureDescription)",
                exitCode: 64
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

    private static func loadConfiguration(
        from currentDirectory: String
    ) throws -> ArcanConfiguration {
        let configurationDirectory: String
        do {
            configurationDirectory = try GitRepositoryFinder().discover(
                from: currentDirectory
            )
        } catch let error as GitRepositoryFinderError {
            switch error {
            case .notRepository:
                configurationDirectory = currentDirectory
            case .commandCouldNotRun, .invalidOutput:
                throw error
            }
        }

        return try ConfigurationLoader().load(
            from: URL(
                fileURLWithPath: configurationDirectory,
                isDirectory: true
            )
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
}
