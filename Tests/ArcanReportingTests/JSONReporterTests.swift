import ArcanDomain
import ArcanReporting
import Foundation
import Testing

@Suite("JSON reporter")
struct JSONReporterTests {
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
