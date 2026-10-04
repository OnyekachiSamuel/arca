import ArcaDomain
import ArcaKnowledge
import ArcaLLM

public struct LLMCodeAnalyzer: Sendable {
    private let provider: any LLMProvider
    private let promptVariant: CodeAnalysisPromptVariant
    private let modelID: String
    private let timeout: Duration
    private let seed: Int?
    private let temperature: Double?
    
    public init(
        provider: any LLMProvider,
        promptVariant: CodeAnalysisPromptVariant = .guided,
        modelID: String,
        timeout: Duration,
        seed: Int? = nil,
        temperature: Double? = nil
    ) {
        self.provider = provider
        self.promptVariant = promptVariant
        self.modelID = modelID
        self.timeout = timeout
        self.seed = seed
        self.temperature = temperature
    }
    
    public func analyze(
        context: SourceFileAnalysisContext,
        rules: [RuleKnowledge] = []
    ) async -> LLMIssueDetectionResult {
        guard promptVariant == .baseline || !rules.isEmpty else {
            return result(
                candidates: [],
                diagnostics: [
                    diagnostic(
                        code: "ARCA-LLM-ANALYSIS-NO-APPLICABLE-RULES",
                        message: "No rule knowledge is available for the selected review type."
                    )
                ],
                requestCount: 0
            )
        }
        
        let prompt: String
        do {
            switch promptVariant {
            case .baseline:
                prompt = try BaselineCodeAnalysisPromptBuilder().build(context: context)
            case .guided:
                prompt = try GuidedCodeAnalysisPromptBuilder().build(
                    context: context,
                    rules: rules
                )
            }
        } catch {
            return result(
                candidates: [],
                diagnostics: [
                    diagnostic(
                        code: "ARCA-LLM-ANALYSIS-PROMPT-FAILED",
                        message: "The LLM code-analysis prompt could not be built for '\(context.filePath)'."
                    )
                ],
                requestCount: 0
            )
        }
        
        let response: LLMResponse
        do {
            let llmRequest = LLMRequest(
                modelID: modelID,
                prompt: prompt,
                timeout: timeout,
                seed: seed,
                temperature: temperature,
                responseFormat: .codeAnalysis(
                    requiresRuleID: promptVariant == .guided
                )
            )
            response = try await provider.submit(llmRequest)
        } catch {
            return result(
                candidates: [],
                diagnostics: [
                    diagnostic(
                        code: "ARCA-LLM-ANALYSIS-PROVIDER-FAILED",
                        message:
                            "LLM analysis failed for '\(context.filePath)' using provider '\(provider.id)' and model '\(modelID)'."
                    )
                ],
                requestCount: 1
            )
        }
        
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
        return result(
            candidates: parsingResult.candidates,
            diagnostics: parsingResult.diagnostics,
            requestCount: 1,
            response: response
        )
    }
    
    private func result(
        candidates: [FindingCandidate],
        diagnostics: [LLMIssueDetectionDiagnostic],
        requestCount: Int,
        response: LLMResponse? = nil
    ) -> LLMIssueDetectionResult {
        LLMIssueDetectionResult(
            candidates: candidates,
            diagnostics: diagnostics,
            executionMetadata: LLMExecutionMetadata(
                providerID: provider.id,
                modelID: modelID,
                requestCount: requestCount,
                usage: response?.usage ?? LLMTokenUsageMetadata(),
                providerDurationMilliseconds: response?.durationMilliseconds ?? 0
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
