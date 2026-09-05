import ArcaAnalysis
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
  public let reviewRequest: ReviewRequest?

  public var exitCode: Int32 { exitStatus.rawValue }

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
  static let llmHelp = """
    OVERVIEW: Detect Swift code issues using one LLM prompt variant.

    USAGE: arca llm [options]

    OPTIONS:
      --file <path>           Analyze an explicit Swift file.
      --review <type>         Guided only. Values: swift, swiftui, tca, security, god-object, all.
      --prompt <variant>      Select prompt content. Values: baseline, guided.
      --format <format>       Select output format. Values: terminal, json. Default: terminal.
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

  static let rootHelp = """
    OVERVIEW: LLM-based code-issue detection for Swift.

    USAGE: arca <command>

    COMMANDS:
      llm                     Run an LLM code-issue detection experiment.

    OPTIONS:
      -h, --help              Show help information.
    """

  public static func run(
    arguments: [String],
    currentDirectory: String = FileManager.default.currentDirectoryPath
  ) async -> CommandResult {
    await execute(
      arguments: arguments,
      currentDirectory: currentDirectory,
      llmProvider: nil
    )
  }

  static func execute(
    arguments: [String],
    currentDirectory: String,
    llmProvider: (any LLMProvider)?
  ) async -> CommandResult {
    switch arguments {
    case [], ["--help"], ["-h"]:
      return CommandResult(output: rootHelp, exitStatus: .success)
    case ["llm", "--help"], ["llm", "-h"]:
      return CommandResult(output: llmHelp, exitStatus: .success)
    default:
      break
    }

    guard arguments.first == "llm" else {
      return CommandResult(
        output: "Error: unknown command or option. Run 'arca --help' for usage.",
        exitStatus: .invalidInput
      )
    }

    return await executeLLM(
      arguments: Array(arguments.dropFirst()),
      currentDirectory: currentDirectory,
      llmProvider: llmProvider
    )
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
      let environment = try loadReviewEnvironment(from: currentDirectory)
      guard let configuration = environment.configuration.llm else {
        return CommandResult(
          output: "Error: The llm command requires an llm configuration in .arca.json.",
          exitStatus: .invalidInput
        )
      }
      let provider =
        try llmProvider
        ?? LLMProviderFactory().make(
          configuration: configuration
        )
      let knowledgeProvider: RuleKnowledgeRegistry? =
        options.promptVariant == .guided
        ? try RuleKnowledgeRegistry.bundled()
        : nil
      let selectedReviewTypes: Set<ReviewType>
      if options.reviewType == .all {
        selectedReviewTypes = Set(ReviewType.analysisTypes)
      } else if let reviewType = options.reviewType {
        selectedReviewTypes = [reviewType]
      } else {
        selectedReviewTypes = []
      }
      let request = ReviewRequest(
        id: UUID(),
        repositoryRoot: environment.repositoryRootURL?.path,
        selectedFiles: [source.path],
        selectedReviewTypes: selectedReviewTypes,
        configuration: environment.configuration
      )

      let reviewTypesToRun: [ReviewType?]
      if options.reviewType == .all {
        reviewTypesToRun = ReviewType.analysisTypes.map(Optional.some)
      } else if let reviewType = options.reviewType {
        reviewTypesToRun = [reviewType]
      } else {
        reviewTypesToRun = [nil]
      }

      var results: [AnalyzerResult] = []
      for reviewType in reviewTypesToRun {
        let runRequest = ReviewRequest(
          id: request.id,
          repositoryRoot: request.repositoryRoot,
          selectedFiles: request.selectedFiles,
          changes: request.changes,
          selectedReviewTypes: reviewType.map { [$0] } ?? [],
          configuration: request.configuration
        )
        results.append(
          try await LLMCodeAnalyzer(
            provider: provider,
            knowledgeProvider: knowledgeProvider,
            promptVariant: options.promptVariant,
            modelID: configuration.modelID,
            timeout: .seconds(configuration.timeoutSeconds),
            seed: configuration.seed,
            temperature: configuration.temperature
          ).analyze(
            context: AnalysisContext(
              request: runRequest,
              sourceFiles: [source]
            )))
      }

      let result = combinedLLMResult(
        results,
        providerID: provider.id,
        modelID: configuration.modelID
      )
      let exitStatus: ArcaExitStatus
      if !result.candidates.isEmpty {
        exitStatus = .findingsDetected
      } else if !result.diagnostics.isEmpty {
        exitStatus = .executionFailure
      } else {
        exitStatus = .success
      }
      let report = LLMIssueDetectionReport(
        requestID: request.id,
        filePath: SourceFileAnalysisContextBuilder().contextPath(
          for: source.path,
          repositoryRoot: environment.repositoryRootURL?.path
        ),
        reviewType: options.reviewType,
        promptVariant: options.promptVariant,
        analysis: result,
        seed: configuration.seed,
        temperature: configuration.temperature
      )
      return CommandResult(
        output: try reporter(for: options.outputFormat).render(
          detectionReport: report
        ),
        exitStatus: exitStatus,
        reviewRequest: request
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

  private static func combinedLLMResult(
    _ results: [AnalyzerResult],
    providerID: String,
    modelID: String
  ) -> AnalyzerResult {
    func sum(_ values: [Int?]) -> Int? {
      let present = values.compactMap { $0 }
      return present.isEmpty ? nil : present.reduce(0, +)
    }

    let metadata = results.compactMap(\.llmExecutionMetadata)
    return AnalyzerResult(
      analyzerID: "llm-code-analysis",
      candidates: results.flatMap(\.candidates),
      executionStatus: results.allSatisfy {
        $0.executionStatus == .skipped
      } ? .skipped : .completed,
      diagnostics: results.flatMap(\.diagnostics),
      llmExecutionMetadata: LLMExecutionMetadata(
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

  private static func reporter(
    for outputFormat: ReviewOutputFormat
  ) -> any Reporter {
    switch outputFormat {
    case .terminal: TerminalReporter()
    case .json: JSONReporter()
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
      }
    )
  }
}

private struct ReviewEnvironment {
  let configuration: ArcaConfiguration
  let repositoryRootURL: URL?
}
