import ArcanDomain
import ArcanReporting
import Foundation
import Testing

@Suite("Terminal reporter")
struct TerminalReporterTests {
    @Test("renders candidate analysis without final-finding language")
    func rendersAnalysis() throws {
        let candidate = try terminalCandidate()
        let analysis = ReviewAnalysisResult(
            schemaVersion: ReviewAnalysisResult.currentSchemaVersion,
            requestID: UUID(),
            candidates: [candidate],
            analyzerResults: [
                AnalyzerResult(
                    analyzerID: "god-object",
                    candidates: [candidate]
                )
            ],
            diagnostics: []
        )

        let output = try TerminalReporter(outputIsTTY: { false })
            .render(analysis: analysis)

        #expect(output == """
        ARCAN Review Analysis
        1 candidate

        [WARNING] ARCAN-GOD-001: God Object candidate
        File: Sources/App.swift:1:1-20:2
        Explanation: The type exceeds multiple thresholds.
        Evidence:
          - methods: 30 (threshold: 25)
        """)
    }

    @Test("renders skipped analyzer diagnostics")
    func rendersSkippedDiagnostic() throws {
        let diagnostic = AnalyzerDiagnostic(
            code: "ARCAN-SWIFTLINT-UNAVAILABLE",
            severity: .warning,
            message: "SwiftLint was not found."
        )
        let analysis = ReviewAnalysisResult(
            schemaVersion: ReviewAnalysisResult.currentSchemaVersion,
            requestID: UUID(),
            candidates: [],
            analyzerResults: [
                AnalyzerResult(
                    analyzerID: "swiftlint",
                    candidates: [],
                    executionStatus: .skipped,
                    diagnostics: [diagnostic]
                )
            ],
            diagnostics: [diagnostic]
        )

        let output = try TerminalReporter(outputIsTTY: { false })
            .render(analysis: analysis)

        #expect(output.contains("1 analyzer skipped"))
        #expect(output.contains("ARCAN-SWIFTLINT-UNAVAILABLE"))
    }

    @Test("TTY output applies severity color")
    func rendersColor() throws {
        let candidate = try terminalCandidate()
        let analysis = ReviewAnalysisResult(
            schemaVersion: 1,
            requestID: UUID(),
            candidates: [candidate],
            analyzerResults: [],
            diagnostics: []
        )

        let output = try TerminalReporter(outputIsTTY: { true })
            .render(analysis: analysis)

        #expect(output.contains("\u{001B}[33m[WARNING]\u{001B}[0m"))
    }
}

private func terminalCandidate() throws -> FindingCandidate {
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
