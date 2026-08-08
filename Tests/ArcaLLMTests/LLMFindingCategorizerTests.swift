import ArcaDomain
import ArcaKnowledge
import ArcaLLM
import Foundation
import Testing

@Suite("LLM finding categorizer")
struct LLMFindingCategorizerTests {
    @Test("confirmed categorization records one request, usage, and duration")
    func confirmsCandidates() async throws {
        let provider = RecordingCategorizationProvider(
            result: .success(response(assessment: .confirmed))
        )
        let analysis = try analysisResult()

        let result = await categorizer(provider: provider).categorize(
            analysis: analysis,
            ruleKnowledge: [knowledge]
        )

        #expect(result.analysis == analysis)
        #expect(result.categorizationDiagnostics.isEmpty)
        #expect(result.categorization?.decisions.first?.assessment == .confirmed)
        #expect(await provider.requests.count == 1)
        #expect(result.llmExecutionMetadata == LLMExecutionMetadata(
            providerID: "mock-categorizer",
            modelID: "mock-model",
            requestCount: 1,
            usage: LLMTokenUsageMetadata(
                inputTokens: 80,
                outputTokens: 30,
                totalTokens: 110
            ),
            providerDurationMilliseconds: 19
        ))
        let request = try #require(await provider.requests.first)
        #expect(request.modelID == "mock-model")
        #expect(request.prompt.contains(candidateIDs[0].uuidString))
        #expect(request.prompt.contains(candidateIDs[1].uuidString))
    }

    @Test("rejected candidates remain in the original analysis")
    func retainsRejectedCandidates() async throws {
        let provider = RecordingCategorizationProvider(
            result: .success(response(assessment: .rejected))
        )
        let analysis = try analysisResult()

        let result = await categorizer(provider: provider).categorize(
            analysis: analysis,
            ruleKnowledge: [knowledge]
        )

        #expect(result.categorization?.decisions.first?.assessment == .rejected)
        #expect(result.analysis.candidates == analysis.candidates)
        #expect(result.analysis.candidates.count == 2)
    }

    @Test("uncertain assessment and rationale are retained")
    func retainsUncertainty() async throws {
        let provider = RecordingCategorizationProvider(
            result: .success(response(
                assessment: .uncertain,
                rationale: "The analyzers agree, but the evidence is incomplete."
            ))
        )

        let result = await categorizer(provider: provider).categorize(
            analysis: try analysisResult(),
            ruleKnowledge: [knowledge]
        )

        let decision = try #require(result.categorization?.decisions.first)
        #expect(decision.assessment == .uncertain)
        #expect(
            decision.rationale
                == "The analyzers agree, but the evidence is incomplete."
        )
    }

    @Test("grouping preserves candidate order and every analyzer source")
    func preservesGroupedSources() async throws {
        let provider = RecordingCategorizationProvider(
            result: .success(response(assessment: .confirmed))
        )

        let result = await categorizer(provider: provider).categorize(
            analysis: try analysisResult(),
            ruleKnowledge: [knowledge]
        )

        let decision = try #require(result.categorization?.decisions.first)
        #expect(decision.candidateIDs == candidateIDs)
        #expect(decision.sourceIdentifiers == [
            "god-object",
            "shared-source",
            "llm-code-analysis",
            "llm-provider:mock"
        ])
        #expect(result.analysis.candidates.count == 2)
    }

    @Test("provider failure becomes a diagnostic and preserves analysis")
    func handlesProviderFailure() async throws {
        let provider = RecordingCategorizationProvider(
            result: .failure(.failed)
        )
        let analysis = try analysisResult()

        let result = await categorizer(provider: provider).categorize(
            analysis: analysis,
            ruleKnowledge: [knowledge]
        )

        #expect(result.analysis == analysis)
        #expect(result.categorization == nil)
        #expect(result.categorizationDiagnostics.map(\.code) == [
            "ARCA-LLM-CATEGORIZATION-PROVIDER-FAILED"
        ])
        #expect(result.llmExecutionMetadata.requestCount == 1)
        #expect(result.llmExecutionMetadata.usage == LLMTokenUsageMetadata())
        #expect(
            result.llmExecutionMetadata.providerDurationMilliseconds == 0
        )
        #expect(await provider.requests.count == 1)
    }

    @Test("parser failure preserves candidates and provider metrics")
    func handlesParserFailure() async throws {
        let provider = RecordingCategorizationProvider(
            result: .success(LLMResponse(
                text: "not JSON",
                usage: LLMTokenUsageMetadata(
                    inputTokens: 12,
                    outputTokens: 2,
                    totalTokens: 14
                ),
                durationMilliseconds: 5
            ))
        )
        let analysis = try analysisResult()

        let result = await categorizer(provider: provider).categorize(
            analysis: analysis,
            ruleKnowledge: [knowledge]
        )

        #expect(result.analysis == analysis)
        #expect(result.categorization == nil)
        #expect(result.categorizationDiagnostics.map(\.code) == [
            "ARCA-LLM-CATEGORIZATION-INVALID-JSON"
        ])
        #expect(result.llmExecutionMetadata.usage.totalTokens == 14)
        #expect(
            result.llmExecutionMetadata.providerDurationMilliseconds == 5
        )
    }

    @Test("prompt failure and empty analysis do not call the provider")
    func skipsProviderWhenNoRequestCanBeBuilt() async throws {
        let provider = RecordingCategorizationProvider(
            result: .failure(.failed)
        )
        let categorizer = categorizer(provider: provider)
        let failed = await categorizer.categorize(
            analysis: try analysisResult(),
            ruleKnowledge: []
        )
        let emptyAnalysis = ReviewAnalysisResult(
            schemaVersion: ReviewAnalysisResult.currentSchemaVersion,
            requestID: UUID(),
            candidates: [],
            analyzerResults: [],
            diagnostics: []
        )
        let empty = await categorizer.categorize(
            analysis: emptyAnalysis,
            ruleKnowledge: []
        )

        #expect(failed.analysis.candidates.count == 2)
        #expect(failed.categorizationDiagnostics.map(\.code) == [
            "ARCA-LLM-CATEGORIZATION-PROMPT-FAILED"
        ])
        #expect(failed.llmExecutionMetadata.requestCount == 0)
        #expect(empty.analysis == emptyAnalysis)
        #expect(empty.categorization == nil)
        #expect(empty.categorizationDiagnostics.isEmpty)
        #expect(empty.llmExecutionMetadata.requestCount == 0)
        #expect(await provider.requests.isEmpty)
    }

    private func categorizer(
        provider: RecordingCategorizationProvider
    ) -> LLMFindingCategorizer {
        LLMFindingCategorizer(
            provider: provider,
            modelID: "mock-model",
            timeout: .seconds(20),
            seed: 7,
            temperature: 0
        )
    }

    private func analysisResult() throws -> ReviewAnalysisResult {
        let candidates = try [
            candidate(
                id: candidateIDs[0],
                sources: ["god-object", "shared-source"]
            ),
            candidate(
                id: candidateIDs[1],
                sources: [
                    "llm-code-analysis",
                    "shared-source",
                    "llm-provider:mock"
                ]
            )
        ]
        return ReviewAnalysisResult(
            schemaVersion: ReviewAnalysisResult.currentSchemaVersion,
            requestID: UUID(
                uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
            )!,
            candidates: candidates,
            analyzerResults: [],
            diagnostics: [AnalyzerDiagnostic(
                code: "EXISTING-ANALYSIS-DIAGNOSTIC",
                severity: .warning,
                message: "Preserve me."
            )]
        )
    }

    private func candidate(
        id: UUID,
        sources: [String]
    ) throws -> FindingCandidate {
        try FindingCandidate(
            candidateID: id,
            ruleID: "ARCA-GOD-001",
            title: "God Object candidate",
            explanation: "The type owns unrelated responsibilities.",
            filePath: "Sources/Checkout.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 20,
                endColumn: 2
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [.metric(MetricEvidence(
                metricName: "methodCount",
                observedValue: 40,
                thresholdValue: 30
            ))],
            sourceIdentifiers: sources
        )
    }

    private var candidateIDs: [UUID] {
        [
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        ]
    }

    private var knowledge: RuleKnowledge {
        RuleKnowledge(
            ruleID: "ARCA-GOD-001",
            title: "God Object",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern,
            defaultSeverity: .warning,
            definition: "A type owns multiple unrelated responsibilities.",
            evidenceCriteria: ["Several responsibility signals are present."],
            classificationGuidance: ["Do not rely on size alone."],
            severityGuidance: ["Use warning for coupled responsibilities."],
            refactoringGuardrails: []
        )
    }

    private func response(
        assessment: FindingAssessment,
        rationale: String = "Both candidates describe the same issue."
    ) -> LLMResponse {
        let ids = candidateIDs.map { "\"\($0.uuidString)\"" }
            .joined(separator: ",")
        return LLMResponse(
            text: """
            {"summary":"One grouped issue.","decisions":[{"candidateIDs":[\(ids)],"assessment":"\(assessment.rawValue)","category":"antiPattern","severity":"warning","canonicalRuleID":"ARCA-GOD-001","title":"God Object","rationale":"\(rationale)"}]}
            """,
            usage: LLMTokenUsageMetadata(
                inputTokens: 80,
                outputTokens: 30,
                totalTokens: 110
            ),
            durationMilliseconds: 19
        )
    }
}

private actor RecordingCategorizationProvider: LLMProvider {
    nonisolated let id = "mock-categorizer"
    private let result: Result<LLMResponse, CategorizationProviderError>
    private(set) var requests: [LLMRequest] = []

    init(result: Result<LLMResponse, CategorizationProviderError>) {
        self.result = result
    }

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        requests.append(request)
        return try result.get()
    }
}

private enum CategorizationProviderError: Error, Sendable {
    case failed
}
