import ArcanAnalysis
import ArcanDomain
import ArcanKnowledge
import ArcanLLM

public struct LLMCodeAnalyzer: Analyzer {
    public let id = "llm-code-analysis"
    public let supportedReviewTypes = Set(ReviewType.allCases)

    private let provider: any LLMProvider
    private let knowledgeProvider: any RuleKnowledgeProviding
    private let ruleSelector: ReviewRuleSelector
    private let contextBuilder: SourceFileAnalysisContextBuilder
    private let promptBuilder: CodeAnalysisPromptBuilder
    private let modelID: String
    private let timeout: Duration
    private let seed: Int?
    private let temperature: Double?

    public init(
        provider: any LLMProvider,
        knowledgeProvider: any RuleKnowledgeProviding,
        ruleSelector: ReviewRuleSelector = ReviewRuleSelector(),
        contextBuilder: SourceFileAnalysisContextBuilder =
            SourceFileAnalysisContextBuilder(),
        promptBuilder: CodeAnalysisPromptBuilder = CodeAnalysisPromptBuilder(),
        modelID: String,
        timeout: Duration,
        seed: Int? = nil,
        temperature: Double? = nil
    ) {
        self.provider = provider
        self.knowledgeProvider = knowledgeProvider
        self.ruleSelector = ruleSelector
        self.contextBuilder = contextBuilder
        self.promptBuilder = promptBuilder
        self.modelID = modelID
        self.timeout = timeout
        self.seed = seed
        self.temperature = temperature
    }

    public func analyze(
        context: AnalysisContext
    ) async throws -> AnalyzerResult {
        let builtContexts = contextBuilder.build(from: context)
        var diagnostics = builtContexts.diagnostics
        let rules = ruleSelector.rules(
            for: context.request.selectedReviewTypes,
            from: knowledgeProvider
        )

        guard !rules.isEmpty else {
            diagnostics.append(diagnostic(
                code: "ARCAN-LLM-ANALYSIS-NO-APPLICABLE-RULES",
                message: "No rule knowledge is available for the selected review types."
            ))
            return result(
                candidates: [],
                diagnostics: diagnostics,
                executionStatus: .skipped,
                metrics: Metrics()
            )
        }

        let parser = CodeAnalysisResponseParser(
            knowledgeProvider: knowledgeProvider,
            sourceIdentifiers: [
                id,
                "llm-provider:\(provider.id)",
                "llm-model:\(modelID)"
            ]
        )
        var candidates: [FindingCandidate] = []
        var metrics = Metrics()

        for sourceContext in builtContexts.contexts {
            let prompt: CodeAnalysisPrompt
            do {
                prompt = try promptBuilder.build(
                    context: sourceContext,
                    rules: rules
                )
            } catch {
                diagnostics.append(diagnostic(
                    code: "ARCAN-LLM-ANALYSIS-PROMPT-FAILED",
                    message: "The LLM code-analysis prompt could not be built for '\(sourceContext.filePath)'."
                ))
                continue
            }

            metrics.requestCount += 1
            let response: LLMResponse
            do {
                response = try await provider.submit(LLMRequest(
                    modelID: modelID,
                    prompt: prompt.text,
                    timeout: timeout,
                    seed: seed,
                    temperature: temperature
                ))
            } catch {
                diagnostics.append(diagnostic(
                    code: "ARCAN-LLM-ANALYSIS-PROVIDER-FAILED",
                    message: "LLM analysis failed for '\(sourceContext.filePath)' using provider '\(provider.id)' and model '\(modelID)'."
                ))
                continue
            }

            metrics.record(response)
            let parsingResult = parser.parse(
                response.text,
                context: sourceContext,
                analyzerMetadata: [
                    "providerID": .string(provider.id),
                    "modelID": .string(modelID),
                    "promptTemplateID": .string(prompt.templateID),
                    "promptTemplateVersion": .integer(
                        prompt.templateVersion
                    )
                ]
            )
            candidates.append(contentsOf: parsingResult.candidates)
            diagnostics.append(contentsOf: parsingResult.diagnostics)
        }

        return result(
            candidates: candidates,
            diagnostics: diagnostics,
            executionStatus: builtContexts.contexts.isEmpty
                ? .skipped
                : .completed,
            metrics: metrics
        )
    }

    private func result(
        candidates: [FindingCandidate],
        diagnostics: [AnalyzerDiagnostic],
        executionStatus: AnalyzerExecutionStatus,
        metrics: Metrics
    ) -> AnalyzerResult {
        AnalyzerResult(
            analyzerID: id,
            candidates: candidates,
            tool: ToolMetadata(name: provider.id, version: modelID),
            executionStatus: executionStatus,
            diagnostics: diagnostics,
            llmExecutionMetadata: LLMExecutionMetadata(
                providerID: provider.id,
                modelID: modelID,
                requestCount: metrics.requestCount,
                usage: LLMTokenUsageMetadata(
                    inputTokens: metrics.inputTokens,
                    outputTokens: metrics.outputTokens,
                    totalTokens: metrics.totalTokens
                ),
                providerDurationMilliseconds:
                    metrics.providerDurationMilliseconds
            )
        )
    }

    private func diagnostic(
        code: String,
        message: String
    ) -> AnalyzerDiagnostic {
        AnalyzerDiagnostic(
            code: code,
            severity: .warning,
            message: message
        )
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
