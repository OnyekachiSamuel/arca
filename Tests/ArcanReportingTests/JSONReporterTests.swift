import ArcanDomain
import ArcanReporting
import Foundation
import Testing

@Suite("JSON reporter")
struct JSONReporterTests {
    @Test("categorized output is versioned and decodes to the report")
    func rendersDecodableReport() throws {
        let candidate = try makeCandidate()
        let report = CategorizedReviewReport(
            schemaVersion: CategorizedReviewReport.currentSchemaVersion,
            requestID: UUID(),
            categorizationSummary: "One confirmed issue.",
            confirmedFindings: [Finding(
                id: candidate.candidateID,
                candidateIDs: [candidate.candidateID],
                assessment: .confirmed,
                ruleID: "ARCAN-GOD-001",
                title: "God Object",
                category: .antiPattern,
                severity: .warning,
                classificationRationale: "The evidence supports the issue.",
                sources: ["god-object"],
                candidates: [candidate]
            )],
            uncertainFindings: [],
            candidates: [candidate],
            categorizationDecisions: [],
            counts: ReviewReportCounts(
                totalCandidates: 1,
                confirmed: 1,
                rejected: 0,
                uncertain: 0,
                findingsPerCategory: [
                    CategoryFindingCount(category: .antiPattern, count: 1)
                ]
            ),
            diagnostics: [],
            analyzerResults: [],
            categorizationExecutionMetadata: LLMExecutionMetadata(
                providerID: "ollama",
                modelID: "qwen",
                requestCount: 1,
                providerDurationMilliseconds: 9
            )
        )

        let output = try JSONReporter().render(report: report)
        let decoded = try JSONDecoder().decode(
            CategorizedReviewReport.self,
            from: Data(output.utf8)
        )

        #expect(decoded == report)
        #expect(decoded.schemaVersion == 1)
        #expect(output.contains(#""schemaVersion":1"#))
    }

    @Test("categorized report decoding requires the new schema fields")
    func requiresCategorizedFields() {
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "requestID": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
              "categorizationSummary": "Summary"
            }
            """.utf8
        )

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                CategorizedReviewReport.self,
                from: data
            )
        }
    }

    @Test("output decodes to the original analysis result")
    func rendersDecodableAnalysis() throws {
        let analysis = try makeAnalysis()

        let output = try JSONReporter().render(analysis: analysis)
        let decoded = try JSONDecoder().decode(
            ReviewAnalysisResult.self,
            from: Data(output.utf8)
        )

        #expect(decoded == analysis)
        #expect(decoded.candidates.first?.sourceIdentifiers == ["god-object"])
    }

    private func makeAnalysis() throws -> ReviewAnalysisResult {
        let candidate = try makeCandidate()
        return ReviewAnalysisResult(
            schemaVersion: ReviewAnalysisResult.currentSchemaVersion,
            requestID: UUID(),
            candidates: [candidate],
            analyzerResults: [
                AnalyzerResult(
                    analyzerID: "god-object",
                    candidates: [candidate],
                    durationMilliseconds: 12
                )
            ],
            diagnostics: []
        )
    }
}

private func makeCandidate() throws -> FindingCandidate {
    try FindingCandidate(
        candidateID: UUID(),
        ruleID: "ARCAN-GOD-001",
        title: "God Object candidate",
        explanation: "The type exceeds multiple thresholds.",
        filePath: "Sources/App.swift",
        range: SourceRange(
            startLine: 1,
            startColumn: 1,
            endLine: 20,
            endColumn: 2
        ),
        proposedSeverity: .warning,
        proposedCategory: .antiPattern,
        evidence: [
            .metric(MetricEvidence(
                metricName: "methods",
                observedValue: 30,
                thresholdValue: 25
            ))
        ],
        sourceIdentifiers: ["god-object"]
    )
}
