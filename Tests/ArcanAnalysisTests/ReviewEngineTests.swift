import ArcanDomain
import Foundation
import Testing
@testable import ArcanAnalysis

@Suite("Review engine candidate aggregation")
struct ReviewEngineTests {
    @Test("aggregates static-only candidates in analyzer order")
    func aggregatesStaticCandidates() async throws {
        let first = try candidate(
            id: "11111111-2222-3333-4444-555555555555",
            ruleID: "ARCAN-GOD-001",
            path: "/project/Sources/App.swift",
            source: "god-object"
        )
        let second = try candidate(
            id: "66666666-7777-8888-9999-AAAAAAAAAAAA",
            ruleID: "swiftlint.force_cast",
            path: "/project/Sources/App.swift",
            source: "swiftlint"
        )

        let result = try await review(results: [
            AnalyzerResult(analyzerID: "god-object", candidates: [first]),
            AnalyzerResult(analyzerID: "swiftlint", candidates: [second])
        ])

        #expect(result.candidates.map(\.candidateID) == [
            first.candidateID, second.candidateID
        ])
        #expect(result.candidates.map(\.filePath) == [
            "Sources/App.swift", "Sources/App.swift"
        ])
        #expect(result.candidates.map(\.sourceIdentifiers) == [
            ["god-object"], ["swiftlint"]
        ])
    }

    @Test("retains LLM candidate provenance and metadata")
    func aggregatesLLMCandidates() async throws {
        let llm = try candidate(
            id: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            ruleID: "ARCAN-GOD-001",
            path: "/project/Sources/App.swift",
            source: "llm-code-analysis",
            additionalSources: [
                "llm-provider:ollama",
                "llm-model:qwen"
            ],
            metadata: ["providerID": .string("ollama")]
        )

        let result = try await review(results: [
            AnalyzerResult(
                analyzerID: "llm-code-analysis",
                candidates: [llm]
            )
        ])

        #expect(result.candidates == result.analyzerResults[0].candidates)
        #expect(result.candidates[0].sourceIdentifiers == [
            "llm-code-analysis",
            "llm-provider:ollama",
            "llm-model:qwen"
        ])
        #expect(
            result.candidates[0].analyzerMetadata
                == ["providerID": .string("ollama")]
        )
    }

    @Test("mixed aggregation preserves every candidate and diagnostics")
    func aggregatesMixedCandidates() async throws {
        let godObject = try candidate(
            id: "11111111-2222-3333-4444-555555555555",
            ruleID: "ARCAN-GOD-001",
            source: "god-object"
        )
        let swiftLint = try candidate(
            id: "22222222-3333-4444-5555-666666666666",
            ruleID: "swiftlint.force_cast",
            source: "swiftlint"
        )
        let llm = try candidate(
            id: "33333333-4444-5555-6666-777777777777",
            ruleID: "ARCAN-GOD-001",
            source: "llm-code-analysis"
        )
        let diagnostic = AnalyzerDiagnostic(
            code: "ARCAN-LLM-WARNING",
            severity: .warning,
            message: "Partial model output."
        )

        let result = try await review(results: [
            AnalyzerResult(analyzerID: "god-object", candidates: [godObject]),
            AnalyzerResult(analyzerID: "swiftlint", candidates: [swiftLint]),
            AnalyzerResult(
                analyzerID: "llm-code-analysis",
                candidates: [llm],
                diagnostics: [diagnostic]
            )
        ])

        #expect(result.candidates.map(\.candidateID) == [
            godObject.candidateID,
            swiftLint.candidateID,
            llm.candidateID
        ])
        #expect(result.diagnostics == [diagnostic])
    }

    @Test("duplicate-looking candidates are never deduplicated or merged")
    func retainsDuplicateLookingCandidates() async throws {
        let staticCandidate = try candidate(
            id: "11111111-2222-3333-4444-555555555555",
            ruleID: "ARCAN-GOD-001",
            source: "god-object"
        )
        let llmCandidate = try candidate(
            id: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            ruleID: "ARCAN-GOD-001",
            source: "llm-code-analysis"
        )

        let result = try await review(results: [
            AnalyzerResult(
                analyzerID: "god-object",
                candidates: [staticCandidate]
            ),
            AnalyzerResult(
                analyzerID: "llm-code-analysis",
                candidates: [llmCandidate]
            )
        ])

        #expect(result.candidates.count == 2)
        #expect(result.candidates.map(\.candidateID) == [
            staticCandidate.candidateID,
            llmCandidate.candidateID
        ])
        #expect(result.candidates.map(\.sourceIdentifiers) == [
            ["god-object"], ["llm-code-analysis"]
        ])
    }

    @Test("empty analyzer selection produces an empty analysis result")
    func emptySelection() async throws {
        let result = try await review(results: [])

        #expect(result.candidates.isEmpty)
        #expect(result.analyzerResults.isEmpty)
        #expect(result.diagnostics.isEmpty)
    }

    private func review(
        results: [AnalyzerResult]
    ) async throws -> ReviewAnalysisResult {
        let analyzers = results.map(ResultAnalyzer.init(result:))
        let runner = AnalyzerRunner(
            clock: TestAnalyzerClock.make(
                milliseconds: Array(repeating: 0, count: results.count * 2)
            )
        )
        return try await ReviewEngine(runner: runner).review(
            analyzers: analyzers,
            context: AnalysisContext(request: ReviewRequest(
                id: UUID(),
                repositoryRoot: "/project",
                selectedFiles: ["/project/Sources/App.swift"]
            ))
        )
    }

    private func candidate(
        id: String,
        ruleID: String,
        path: String = "/project/Sources/App.swift",
        source: String,
        additionalSources: [String] = [],
        metadata: [String: FindingMetadataValue] = [:]
    ) throws -> FindingCandidate {
        try FindingCandidate(
            candidateID: UUID(uuidString: id)!,
            ruleID: ruleID,
            title: "Candidate",
            explanation: "Same issue explanation.",
            filePath: path,
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 10,
                endColumn: 2
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [
                .analyzer(AnalyzerEvidence(description: "Evidence"))
            ],
            sourceIdentifiers: [source] + additionalSources,
            analyzerMetadata: metadata
        )
    }
}

private struct ResultAnalyzer: Analyzer {
    let id: String
    let supportedReviewTypes: Set<ReviewType> = [.godObject]
    let result: AnalyzerResult

    init(result: AnalyzerResult) {
        id = result.analyzerID
        self.result = result
    }

    func analyze(context: AnalysisContext) async throws -> AnalyzerResult {
        result
    }
}
