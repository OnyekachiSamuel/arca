import ArcanDomain
import ArcanReporting
import Foundation
import Testing

@Suite("Terminal reporter")
struct TerminalReporterTests {
    @Test("renders a normalized categorized report")
    func rendersCategorizedReport() throws {
        let candidate = try categorizedCandidate()
        let finding = categorizedFinding(candidate: candidate)
        let report = CategorizedReviewReport(
            schemaVersion: 1,
            requestID: UUID(),
            categorizationSummary: "The candidate is confirmed.",
            confirmedFindings: [finding],
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
            diagnostics: [AnalyzerDiagnostic(
                code: "ARCAN-NOTE",
                severity: .info,
                message: "Review completed."
            )],
            analyzerResults: [],
            categorizationExecutionMetadata: LLMExecutionMetadata(
                providerID: "ollama",
                modelID: "qwen",
                requestCount: 1,
                providerDurationMilliseconds: 12
            )
        )

        let output = try TerminalReporter(outputIsTTY: { false })
            .render(report: report)

        #expect(output == """
        ARCAN Categorized Review
        Summary: The candidate is confirmed.

        Counts:
          Candidates: 1
          Confirmed: 1
          Rejected: 0
          Uncertain: 0

        Findings by category:
          antiPattern: 1

        Confirmed findings:

        [WARNING] ARCAN-GOD-001: God Object
        Assessment: confirmed
        Sources: god-object, llm-code-analysis
        Candidates:
          - 11111111-1111-1111-1111-111111111111 Sources/App.swift:1:1-20:2
        Rationale: Static and LLM evidence agree.

        [INFO] ARCAN-NOTE: Review completed.
        """)
    }

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

private func categorizedCandidate() throws -> FindingCandidate {
    try FindingCandidate(
        candidateID: UUID(
            uuidString: "11111111-1111-1111-1111-111111111111"
        )!,
        ruleID: "ARCAN-GOD-001",
        title: "God Object candidate",
        explanation: "The type owns unrelated responsibilities.",
        filePath: "Sources/App.swift",
        range: SourceRange(
            startLine: 1,
            startColumn: 1,
            endLine: 20,
            endColumn: 2
        ),
        proposedSeverity: .warning,
        proposedCategory: .antiPattern,
        evidence: [.metric(MetricEvidence(
            metricName: "methods",
            observedValue: 30,
            thresholdValue: 25
        ))],
        sourceIdentifiers: ["god-object"]
    )
}

private func categorizedFinding(candidate: FindingCandidate) -> Finding {
    Finding(
        id: candidate.candidateID,
        candidateIDs: [candidate.candidateID],
        assessment: .confirmed,
        ruleID: "ARCAN-GOD-001",
        title: "God Object",
        category: .antiPattern,
        severity: .warning,
        classificationRationale: "Static and LLM evidence agree.",
        sources: ["god-object", "llm-code-analysis"],
        candidates: [candidate]
    )
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
