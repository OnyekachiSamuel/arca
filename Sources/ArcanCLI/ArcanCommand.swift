import ArcanAnalysis
import ArcanAnalyzers
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
        if arguments.count == 4,
           arguments[0] == "review",
           arguments[1] == "--file",
           arguments[3] == "--debug" {
            return await reviewFile(at: arguments[2], debug: true)
        }

        if arguments.count == 3,
           arguments[0] == "review",
           arguments[1] == "--file" {
            return await reviewFile(at: arguments[2], debug: false)
        }

        if arguments == ["review", "--changed"] {
            return await reviewChanged(from: currentDirectory)
        }

        switch arguments {
        case [], ["--help"], ["-h"]:
            return CommandResult(output: rootHelp, exitCode: 0)
        case ["review", "--help"], ["review", "-h"]:
            return CommandResult(output: reviewHelp, exitCode: 0)
        case ["review"]:
            return CommandResult(
                output: "No Swift file selected. Run 'arcan review --help' for usage.",
                exitCode: 0
            )
        default:
            return CommandResult(
                output: "Error: unknown command or option. Run 'arcan --help' for usage.",
                exitCode: 64
            )
        }
    }

    private static func reviewFile(
        at path: String,
        debug: Bool
    ) async -> CommandResult {
        do {
            let selectedFile = try ExplicitSwiftFileSelector().select(path: path)
            return await reviewFiles(
                at: [selectedFile],
                debug: debug,
                failureDescription: "Swift file: \(path)"
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
        from currentDirectory: String
    ) async -> CommandResult {
        do {
            let changes = try GitDiffProvider().extract(from: currentDirectory)
            let selectedFiles = changes.map(\.filePath)
            return await reviewFiles(
                at: selectedFiles,
                debug: false,
                failureDescription: "changed Swift files",
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
        changes: [CodeChange] = []
    ) async -> CommandResult {
        do {
            let sources = try paths.map { path in
                try SourceFileLoader().load(path: path)
            }
            let request = ReviewRequest(
                id: UUID(),
                selectedFiles: paths,
                changes: changes
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

            let structureProvider = SwiftSyntaxStructureProvider()
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
            let analyzer = GodObjectAnalyzer(
                structureProvider: structureProvider
            )
            let analyzerResult = try await AnalyzerRunner().run(
                analyzer,
                context: context
            )
            let report = ReviewReport(
                schemaVersion: 1,
                requestID: request.id,
                findings: analyzerResult.findings,
                analyzerResults: [analyzerResult]
            )
            return CommandResult(
                output: TerminalReporter().render(report: report),
                exitCode: 0,
                reviewRequest: request
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
