import ArcaDomain
import ArcaKnowledge
import ArcaLLM

public struct LLMCodeAnalyzer: Sendable {
  private let provider: any LLMProvider
  private let promptVariant: CodeAnalysisPromptVariant
  private let baselinePromptBuilder: BaselineCodeAnalysisPromptBuilder
  private let guidedPromptBuilder: GuidedCodeAnalysisPromptBuilder
  private let modelID: String
  private let timeout: Duration
  private let seed: Int?
  private let temperature: Double?

  public init(
    provider: any LLMProvider,
    promptVariant: CodeAnalysisPromptVariant = .guided,
    baselinePromptBuilder: BaselineCodeAnalysisPromptBuilder =
      BaselineCodeAnalysisPromptBuilder(),
    guidedPromptBuilder: GuidedCodeAnalysisPromptBuilder =
      GuidedCodeAnalysisPromptBuilder(),
    modelID: String,
    timeout: Duration,
    seed: Int? = nil,
    temperature: Double? = nil
  ) {
    self.provider = provider
    self.promptVariant = promptVariant
    self.baselinePromptBuilder = baselinePromptBuilder
    self.guidedPromptBuilder = guidedPromptBuilder
    self.modelID = modelID
    self.timeout = timeout
    self.seed = seed
    self.temperature = temperature
  }

  public func analyze(
    contexts: [SourceFileAnalysisContext],
    rules: [RuleKnowledge] = []
  ) async -> LLMIssueDetectionResult {
    var diagnostics: [LLMIssueDetectionDiagnostic] = []
    guard promptVariant == .baseline || !rules.isEmpty else {
      diagnostics.append(
        diagnostic(
          code: "ARCA-LLM-ANALYSIS-NO-APPLICABLE-RULES",
          message: "No rule knowledge is available for the selected review type."
        ))
      return result(candidates: [], diagnostics: diagnostics, metrics: Metrics())
    }

    var candidates: [FindingCandidate] = []
    var metrics = Metrics()

    for context in contexts {
      let prompt: String
      do {
        switch promptVariant {
        case .baseline:
          prompt = try baselinePromptBuilder.build(context: context)
        case .guided:
          prompt = try guidedPromptBuilder.build(context: context, rules: rules)
        }
      } catch {
        diagnostics.append(
          diagnostic(
            code: "ARCA-LLM-ANALYSIS-PROMPT-FAILED",
            message: "The LLM code-analysis prompt could not be built for '\(context.filePath)'."
          ))
        continue
      }

      metrics.requestCount += 1
      let response: LLMResponse
      do {
        response = try await provider.submit(
          LLMRequest(
            modelID: modelID,
            prompt: prompt,
            timeout: timeout,
            seed: seed,
            temperature: temperature
          ))
      } catch {
        diagnostics.append(
          diagnostic(
            code: "ARCA-LLM-ANALYSIS-PROVIDER-FAILED",
            message:
              "LLM analysis failed for '\(context.filePath)' using provider '\(provider.id)' and model '\(modelID)'."
          ))
        continue
      }

      metrics.record(response)
      let parsingResult: CodeAnalysisResponseParsingResult
      switch promptVariant {
      case .baseline:
        parsingResult = BaselineCodeAnalysisResponseParser().parse(
          response.text,
          context: context
        )
      case .guided:
        parsingResult = CodeAnalysisResponseParser(rules: rules).parse(
          response.text,
          context: context
        )
      }
      candidates.append(contentsOf: parsingResult.candidates)
      diagnostics.append(contentsOf: parsingResult.diagnostics)
    }

    return result(
      candidates: candidates,
      diagnostics: diagnostics,
      metrics: metrics
    )
  }

  private func result(
    candidates: [FindingCandidate],
    diagnostics: [LLMIssueDetectionDiagnostic],
    metrics: Metrics
  ) -> LLMIssueDetectionResult {
    LLMIssueDetectionResult(
      candidates: candidates,
      diagnostics: diagnostics,
      executionMetadata: LLMExecutionMetadata(
        providerID: provider.id,
        modelID: modelID,
        requestCount: metrics.requestCount,
        usage: LLMTokenUsageMetadata(
          inputTokens: metrics.inputTokens,
          outputTokens: metrics.outputTokens,
          totalTokens: metrics.totalTokens
        ),
        providerDurationMilliseconds: metrics.providerDurationMilliseconds
      )
    )
  }

  private func diagnostic(
    code: String,
    message: String
  ) -> LLMIssueDetectionDiagnostic {
    LLMIssueDetectionDiagnostic(code: code, message: message)
  }
}

private struct Metrics {
  var requestCount = 0
  var inputTokens: Int?
  var outputTokens: Int?
  var totalTokens: Int?
  var providerDurationMilliseconds = 0

  mutating func record(_ response: LLMResponse) {
    inputTokens = adding(response.usage.inputTokens, to: inputTokens)
    outputTokens = adding(response.usage.outputTokens, to: outputTokens)
    totalTokens = adding(response.usage.totalTokens, to: totalTokens)
    providerDurationMilliseconds += response.durationMilliseconds
  }

  private func adding(_ value: Int?, to total: Int?) -> Int? {
    guard let value else { return total }
    return (total ?? 0) + value
  }
}
