import ArcaDomain
import ArcaKnowledge
import Foundation

public struct LLMCodeAnalysisRunner: Sendable {
    private let provider: any LLMProvider
    private let knowledgeProvider: any RuleKnowledgeProviding
    private let ruleSelector: ReviewRuleSelector
    private let baselinePromptBuilder: BaselineCodeAnalysisPromptBuilder
    private let guidedPromptBuilder: GuidedCodeAnalysisPromptBuilder
    private let modelID: String
    private let timeout: Duration
    private let seed: Int?
    private let temperature: Double?

    public init(
        provider: any LLMProvider,
        knowledgeProvider: any RuleKnowledgeProviding,
        ruleSelector: ReviewRuleSelector = ReviewRuleSelector(),
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
        self.knowledgeProvider = knowledgeProvider
        self.ruleSelector = ruleSelector
        self.baselinePromptBuilder = baselinePromptBuilder
        self.guidedPromptBuilder = guidedPromptBuilder
        self.modelID = modelID
        self.timeout = timeout
        self.seed = seed
        self.temperature = temperature
    }

    public func run(
        context: SourceFileAnalysisContext,
        reviewType: ReviewType,
        promptVariant: CodeAnalysisPromptVariant,
        runID: UUID = UUID()
    ) async -> LLMCodeAnalysisRunResult {
        let rules = ruleSelector.rules(
            for: [reviewType],
            from: knowledgeProvider
        )
        if promptVariant == .guided && rules.isEmpty {
            return result(
                runID: runID,
                context: context,
                reviewType: reviewType,
                promptVariant: promptVariant,
                findings: [],
                diagnostics: [diagnostic(
                    code: "ARCA-LLM-ANALYSIS-NO-APPLICABLE-RULES",
                    message: "No analysis task is available for review type '\(reviewType.commandLineName)'."
                )],
                requestCount: 0,
                prompt: nil,
                response: nil
            )
        }

        let prompt: CodeAnalysisPrompt
        do {
            switch promptVariant {
            case .baseline:
                prompt = try baselinePromptBuilder.build(
                    context: context
                )
            case .guided:
                prompt = try guidedPromptBuilder.build(
                    context: context,
                    rules: rules
                )
            }
        } catch {
            return result(
                runID: runID,
                context: context,
                reviewType: reviewType,
                promptVariant: promptVariant,
                findings: [],
                diagnostics: [diagnostic(
                    code: "ARCA-LLM-ANALYSIS-PROMPT-FAILED",
                    message: "The LLM code-analysis prompt could not be built for '\(context.filePath)'."
                )],
                requestCount: 0,
                prompt: nil,
                response: nil
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
                runID: runID,
                context: context,
                reviewType: reviewType,
                promptVariant: promptVariant,
                findings: [],
                diagnostics: [diagnostic(
                    code: "ARCA-LLM-ANALYSIS-PROVIDER-FAILED",
                    message: "LLM analysis failed for '\(context.filePath)' using provider '\(provider.id)' and model '\(modelID)'."
                )],
                requestCount: 1,
                prompt: prompt,
                response: nil
            )
        }

        let sourceIdentifiers = [
            "llm-code-analysis",
            "llm-provider:\(provider.id)",
            "llm-model:\(modelID)"
        ]
        let metadata: [String: FindingMetadataValue] = [
            "providerID": .string(provider.id),
            "modelID": .string(modelID),
            "promptVariant": .string(promptVariant.rawValue),
            "promptTemplateID": .string(prompt.templateID),
            "promptTemplateVersion": .integer(prompt.templateVersion)
        ]

        let findings: [LLMCodeAnalysisFinding]
        let diagnostics: [AnalyzerDiagnostic]
        switch promptVariant {
        case .baseline:
            let parsingResult = BaselineCodeAnalysisResponseParser(
                sourceIdentifiers: sourceIdentifiers,
                retainsEvidenceExcerptMismatches: true
            ).parse(
                response.text,
                context: context,
                metadata: metadata
            )
            findings = parsingResult.findings
            diagnostics = parsingResult.diagnostics
        case .guided:
            let parsingResult = CodeAnalysisResponseParser(
                knowledgeProvider: knowledgeProvider,
                sourceIdentifiers: sourceIdentifiers,
                retainsEvidenceExcerptMismatches: true
            ).parse(
                response.text,
                context: context,
                analyzerMetadata: metadata
            )
            findings = parsingResult.candidates.compactMap(
                makeExperimentFinding
            )
            diagnostics = parsingResult.diagnostics
        }

        return result(
            runID: runID,
            context: context,
            reviewType: reviewType,
            promptVariant: promptVariant,
            findings: findings,
            diagnostics: diagnostics,
            requestCount: 1,
            prompt: prompt,
            response: response
        )
    }

    private func result(
        runID: UUID,
        context: SourceFileAnalysisContext,
        reviewType: ReviewType,
        promptVariant: CodeAnalysisPromptVariant,
        findings: [LLMCodeAnalysisFinding],
        diagnostics: [AnalyzerDiagnostic],
        requestCount: Int,
        prompt: CodeAnalysisPrompt?,
        response: LLMResponse?
    ) -> LLMCodeAnalysisRunResult {
        LLMCodeAnalysisRunResult(
            schemaVersion: LLMCodeAnalysisRunResult.currentSchemaVersion,
            runID: runID,
            filePath: context.filePath,
            reviewType: reviewType,
            promptVariant: promptVariant,
            promptTemplateID: prompt?.templateID
                ?? defaultPromptTemplate(for: promptVariant).id,
            promptTemplateVersion: prompt?.templateVersion
                ?? defaultPromptTemplate(for: promptVariant).version,
            findings: findings,
            diagnostics: diagnostics,
            executionMetadata: LLMExecutionMetadata(
                providerID: provider.id,
                modelID: modelID,
                requestCount: requestCount,
                usage: LLMTokenUsageMetadata(
                    inputTokens: response?.usage.inputTokens,
                    outputTokens: response?.usage.outputTokens,
                    totalTokens: response?.usage.totalTokens
                ),
                providerDurationMilliseconds:
                    response?.durationMilliseconds ?? 0
            ),
            seed: seed,
            temperature: temperature
        )
    }

    private func makeExperimentFinding(
        from candidate: FindingCandidate
    ) -> LLMCodeAnalysisFinding? {
        guard let range = candidate.range else { return nil }
        return LLMCodeAnalysisFinding(
            id: candidate.candidateID,
            canonicalRuleID: candidate.ruleID,
            title: candidate.title,
            issueType: issueType(for: candidate.proposedCategory),
            explanation: candidate.explanation,
            filePath: candidate.filePath,
            range: range,
            severity: candidate.proposedSeverity,
            evidence: candidate.evidence,
            sourceIdentifiers: candidate.sourceIdentifiers,
            metadata: candidate.analyzerMetadata
        )
    }

    private func issueType(
        for category: FindingCategory
    ) -> LLMDetectedIssueType {
        switch category {
        case .antiPattern: .antiPattern
        case .architecture: .architecture
        case .style: .style
        case .teamConvention: .teamConvention
        case .general, .uncategorized: .general
        }
    }

    private func defaultPromptTemplate(
        for variant: CodeAnalysisPromptVariant
    ) -> (id: String, version: Int) {
        switch variant {
        case .baseline:
            (
                BaselineCodeAnalysisPromptTemplateV1.id,
                BaselineCodeAnalysisPromptTemplateV1.version
            )
        case .guided:
            (
                GuidedCodeAnalysisPromptTemplateV1.id,
                GuidedCodeAnalysisPromptTemplateV1.version
            )
        }
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
