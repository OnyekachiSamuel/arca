import ArcaDomain
import ArcaKnowledge

public struct LLMFindingCategorizer: Sendable {
    private let provider: any LLMProvider
    private let promptBuilder: IssueCategorizationPromptBuilder
    private let responseParser: IssueCategorizationResponseParser
    private let modelID: String
    private let timeout: Duration
    private let seed: Int?
    private let temperature: Double?

    public init(
        provider: any LLMProvider,
        promptBuilder: IssueCategorizationPromptBuilder =
            IssueCategorizationPromptBuilder(),
        responseParser: IssueCategorizationResponseParser =
            IssueCategorizationResponseParser(),
        modelID: String,
        timeout: Duration,
        seed: Int? = nil,
        temperature: Double? = nil
    ) {
        self.provider = provider
        self.promptBuilder = promptBuilder
        self.responseParser = responseParser
        self.modelID = modelID
        self.timeout = timeout
        self.seed = seed
        self.temperature = temperature
    }

    public func categorize(
        analysis: ReviewAnalysisResult,
        ruleKnowledge: [RuleKnowledge]
    ) async -> ReviewCategorizationResult {
        guard !analysis.candidates.isEmpty else {
            return result(
                analysis: analysis,
                categorization: nil,
                diagnostics: [],
                requestCount: 0
            )
        }

        let prompt: IssueCategorizationPrompt
        do {
            prompt = try promptBuilder.build(
                candidates: analysis.candidates,
                ruleKnowledge: ruleKnowledge
            )
        } catch {
            return result(
                analysis: analysis,
                categorization: nil,
                diagnostics: [diagnostic(
                    code: "ARCA-LLM-CATEGORIZATION-PROMPT-FAILED",
                    message: "The issue-categorization prompt could not be built."
                )],
                requestCount: 0
            )
        }

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
            return result(
                analysis: analysis,
                categorization: nil,
                diagnostics: [diagnostic(
                    code: "ARCA-LLM-CATEGORIZATION-PROVIDER-FAILED",
                    message: "LLM categorization failed using provider '\(provider.id)' and model '\(modelID)'."
                )],
                requestCount: 1
            )
        }

        let parsing = responseParser.parse(
            response.text,
            candidates: analysis.candidates,
            allowedRuleIDs: Set(ruleKnowledge.map(\.ruleID))
        )
        return result(
            analysis: analysis,
            categorization: parsing.categorization,
            diagnostics: parsing.diagnostics,
            requestCount: 1,
            response: response
        )
    }

    private func result(
        analysis: ReviewAnalysisResult,
        categorization: FindingCategorization?,
        diagnostics: [AnalyzerDiagnostic],
        requestCount: Int,
        response: LLMResponse? = nil
    ) -> ReviewCategorizationResult {
        ReviewCategorizationResult(
            analysis: analysis,
            categorization: categorization,
            categorizationDiagnostics: diagnostics,
            llmExecutionMetadata: LLMExecutionMetadata(
                providerID: provider.id,
                modelID: modelID,
                requestCount: requestCount,
                usage: response?.usage ?? LLMTokenUsageMetadata(),
                providerDurationMilliseconds:
                    response?.durationMilliseconds ?? 0
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
