import ArcaAnalysis
import ArcaDomain
import Foundation
import Testing

@Suite("Categorized review report builder")
struct CategorizedReviewReportBuilderTests {
    @Test("builds categorized findings and deterministic candidate counts")
    func buildsReport() throws {
        let candidates = try makeCandidates()
        let input = ReviewCategorizationResult(
            analysis: analysis(candidates: candidates),
            categorization: FindingCategorization(
                summary: "One issue is confirmed and one needs review.",
                decisions: [
                    decision(
                        ids: [candidates[0].candidateID, candidates[1].candidateID],
                        sources: ["god-object", "llm-code-analysis"],
                        assessment: .confirmed,
                        category: .antiPattern
                    ),
                    decision(
                        ids: [candidates[2].candidateID],
                        sources: ["swiftlint"],
                        assessment: .rejected,
                        category: .style
                    ),
                    decision(
                        ids: [candidates[3].candidateID],
                        sources: ["llm-code-analysis"],
                        assessment: .uncertain,
                        category: .style
                    )
                ]
            ),
            categorizationDiagnostics: [AnalyzerDiagnostic(
                code: "CATEGORIZATION-NOTE",
                severity: .info,
                message: "Categorization completed."
            )],
            llmExecutionMetadata: metadata
        )

        let report = CategorizedReviewReportBuilder().build(from: input)

        #expect(report.schemaVersion == 1)
        #expect(report.categorizationSummary == input.categorization?.summary)
        #expect(report.confirmedFindings.count == 1)
        #expect(report.uncertainFindings.count == 1)
        #expect(report.confirmedFindings[0].candidateIDs == [
            candidates[0].candidateID,
            candidates[1].candidateID
        ])
        #expect(report.confirmedFindings[0].candidates == [
            candidates[0], candidates[1]
        ])
        #expect(report.confirmedFindings[0].sources == [
            "god-object", "llm-code-analysis"
        ])
        #expect(
            report.confirmedFindings[0].classificationRationale
                == "Grounded classification rationale."
        )
        #expect(report.candidates == candidates)
        #expect(report.categorizationDecisions.count == 3)
        #expect(report.counts.totalCandidates == 4)
        #expect(report.counts.confirmed == 2)
        #expect(report.counts.rejected == 1)
        #expect(report.counts.uncertain == 1)
        #expect(report.counts.findingsPerCategory == [
            CategoryFindingCount(category: .antiPattern, count: 1),
            CategoryFindingCount(category: .style, count: 1)
        ])
        #expect(report.diagnostics.map(\.code) == [
            "ANALYSIS-NOTE", "CATEGORIZATION-NOTE"
        ])
        #expect(report.categorizationExecutionMetadata == metadata)
        #expect(CategorizedReviewReportBuilder().build(from: input) == report)
    }

    @Test("failed categorization preserves analysis without claiming clean results")
    func buildsFailureReport() throws {
        let candidates = try makeCandidates()
        let input = ReviewCategorizationResult(
            analysis: analysis(candidates: candidates),
            categorization: nil,
            categorizationDiagnostics: [AnalyzerDiagnostic(
                code: "ARCA-LLM-CATEGORIZATION-PROVIDER-FAILED",
                severity: .warning,
                message: "Provider failed."
            )],
            llmExecutionMetadata: metadata
        )

        let report = CategorizedReviewReportBuilder().build(from: input)

        #expect(report.categorizationSummary == nil)
        #expect(report.confirmedFindings.isEmpty)
        #expect(report.uncertainFindings.isEmpty)
        #expect(report.candidates == candidates)
        #expect(report.categorizationDecisions.isEmpty)
        #expect(report.counts.totalCandidates == 4)
        #expect(report.counts.confirmed == 0)
        #expect(report.counts.rejected == 0)
        #expect(report.counts.uncertain == 0)
        #expect(report.counts.findingsPerCategory.isEmpty)
        #expect(report.diagnostics.map(\.code) == [
            "ANALYSIS-NOTE",
            "ARCA-LLM-CATEGORIZATION-PROVIDER-FAILED"
        ])
    }

    private func analysis(
        candidates: [FindingCandidate]
    ) -> ReviewAnalysisResult {
        ReviewAnalysisResult(
            schemaVersion: ReviewAnalysisResult.currentSchemaVersion,
            requestID: UUID(
                uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
            )!,
            candidates: candidates,
            analyzerResults: [],
            diagnostics: [AnalyzerDiagnostic(
                code: "ANALYSIS-NOTE",
                severity: .info,
                message: "Analysis completed."
            )]
        )
    }

    private func makeCandidates() throws -> [FindingCandidate] {
        try (1...4).map { index in
            try FindingCandidate(
                candidateID: UUID(
                    uuidString: "00000000-0000-0000-0000-00000000000\(index)"
                )!,
                ruleID: index < 3 ? "ARCA-GOD-001" : "ARCA-STYLE-001",
                title: "Candidate \(index)",
                explanation: "Candidate explanation \(index).",
                filePath: "Sources/App.swift",
                range: SourceRange(
                    startLine: index,
                    startColumn: 1,
                    endLine: index,
                    endColumn: 2
                ),
                proposedSeverity: .warning,
                proposedCategory: index < 3 ? .antiPattern : .style,
                evidence: [.metric(MetricEvidence(
                    metricName: "metric\(index)",
                    observedValue: index + 1,
                    thresholdValue: index
                ))],
                sourceIdentifiers: ["source-\(index)"]
            )
        }
    }

    private func decision(
        ids: [UUID],
        sources: [String],
        assessment: FindingAssessment,
        category: FindingCategory
    ) -> FindingCategorizationDecision {
        FindingCategorizationDecision(
            candidateIDs: ids,
            sourceIdentifiers: sources,
            assessment: assessment,
            category: category,
            severity: .warning,
            canonicalRuleID: category == .style
                ? "ARCA-STYLE-001"
                : "ARCA-GOD-001",
            title: category == .style ? "Style issue" : "God Object",
            rationale: "Grounded classification rationale."
        )
    }

    private var metadata: LLMExecutionMetadata {
        LLMExecutionMetadata(
            providerID: "ollama",
            modelID: "qwen",
            requestCount: 1,
            usage: LLMTokenUsageMetadata(totalTokens: 100),
            providerDurationMilliseconds: 20
        )
    }
}
