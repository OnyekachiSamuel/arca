import ArcaDomain
import ArcaReporting
import Foundation
import Testing

@Suite("Terminal reporter")
struct TerminalReporterTests {
    @Test("renders an isolated LLM run and its provider measurements")
    func rendersLLMRun() throws {
        let report = llmDetectionReport(
            promptVariant: .baseline,
            usage: LLMTokenUsageMetadata(
                inputTokens: 100,
                outputTokens: 20,
                totalTokens: 120
            )
        )

        let output = try TerminalReporter(outputIsTTY: { false })
            .render(detectionReport: report)

        #expect(output == """
        ARCA LLM Detection Experiment
        Overall result: No candidates detected

        Run configuration
        -----------------
        Prompt: Baseline — source and general instructions only
        Review: God Object
        File: Sources/App.swift
        Provider: lm-studio
        Model: qwen
        Requests: 1
        Duration: 25 ms
        Token usage: 100 input, 20 output, 120 total

        Detection results
        -----------------
        No candidates were returned by the model.
        """)
    }

    @Test("renders an LLM candidate and validation notes clearly")
    func rendersLLMCandidate() throws {
        let report = llmDetectionReport(
            promptVariant: .guided,
            candidates: [try experimentalLLMCandidate()],
            diagnostics: [AnalyzerDiagnostic(
                code: "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-MISMATCH",
                severity: .warning,
                message: "Evidence 1 could not be matched exactly to source lines 2–10."
            )]
        )

        let output = try TerminalReporter(outputIsTTY: { false })
            .render(detectionReport: report)

        #expect(output.contains("Overall result: 1 candidate detected"))
        #expect(output.contains(
            "Prompt: Guided — rules and knowledge included"
        ))
        #expect(output.contains("Candidate 1 — God Object candidate"))
        #expect(output.contains("Issue type: Anti-pattern"))
        #expect(output.contains("Canonical rule: ARCA-GOD-001"))
        #expect(output.contains("Location: Sources/App.swift"))
        #expect(output.contains("Lines: 1–20"))
        #expect(output.contains("LLM detection\n-------------"))
        #expect(output.contains("Evidence verification\n---------------------"))
        #expect(output.contains(
            "Evidence 1 could not be matched exactly to source lines 2–10."
        ))
        #expect(!output.contains(
            "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-MISMATCH"
        ))
        #expect(!output.contains("Sources/App.swift:1:1-20:2"))
    }

    @Test("renders a baseline finding without implying a canonical rule")
    func rendersRuleFreeBaselineFinding() throws {
        let finding = try FindingCandidate(
            candidateID: UUID(),
            ruleID: nil,
            title: "Large Class",
            explanation: "The type contains substantial state and behavior.",
            filePath: "Sources/App.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 20,
                endColumn: 2
            ),
            proposedSeverity: .warning,
            proposedCategory: .general,
            evidence: [.sourceCode(SourceCodeEvidence(
                description: "The type contains many members.",
                range: SourceRange(
                    startLine: 1,
                    startColumn: 1,
                    endLine: 20,
                    endColumn: 2
                ),
                excerpt: "final class App"
            ))],
            sourceIdentifiers: ["llm-code-analysis"],
            analyzerMetadata: ["issueType": .string("codeSmell")]
        )
        let report = llmDetectionReport(
            promptVariant: .baseline,
            candidates: [finding]
        )

        let output = try TerminalReporter(outputIsTTY: { false })
            .render(detectionReport: report)

        #expect(output.contains("Candidate 1 — Large Class"))
        #expect(output.contains("Issue type: Code smell"))
        #expect(!output.contains("Canonical rule:"))
        #expect(!output.contains("ARCA-GOD-001"))
    }

    @Test("renders a normalized categorized report")
    func rendersCategorizedReport() throws {
        let staticCandidate = try categorizedStaticCandidate()
        let llmCandidate = try categorizedLLMCandidate()
        let candidates = [staticCandidate, llmCandidate]
        let finding = categorizedFinding(candidates: candidates)
        let report = CategorizedReviewReport(
            schemaVersion: 1,
            requestID: UUID(),
            categorizationSummary: "The candidate is confirmed.",
            confirmedFindings: [finding],
            uncertainFindings: [],
            candidates: candidates,
            categorizationDecisions: [FindingCategorizationDecision(
                candidateIDs: candidates.map(\.candidateID),
                sourceIdentifiers: finding.sources,
                assessment: .confirmed,
                category: .antiPattern,
                severity: .warning,
                canonicalRuleID: "ARCA-GOD-001",
                title: "God Object",
                rationale: "Static and LLM evidence agree."
            )],
            counts: ReviewReportCounts(
                totalCandidates: 2,
                confirmed: 2,
                rejected: 0,
                uncertain: 0,
                findingsPerCategory: [
                    CategoryFindingCount(category: .antiPattern, count: 1)
                ]
            ),
            diagnostics: [
                AnalyzerDiagnostic(
                    code: "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-MISMATCH",
                    severity: .warning,
                    message: "Evidence 1 could not be matched exactly to source lines 2–10."
                ),
                AnalyzerDiagnostic(
                    code: "ARCA-NOTE",
                    severity: .info,
                    message: "Review completed."
                )
            ],
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
        ARCA Code Review
        Overall result: 1 confirmed issue

        Summary
        -------
        The candidate is confirmed.

        Issue 1 — God Object
        --------------------
        Status: CONFIRMED
        Severity: [WARNING]
        Rule: ARCA-GOD-001
        Category: Anti-pattern
        Location: Sources/App.swift
        Lines: 1–20

        Detection evidence
        ------------------
        [STATIC ANALYZER] God Object candidate
          Analyzer: god-object
          Explanation: The type exceeds multiple structural thresholds.
          Evidence:
            - methods: 30 (threshold: 25)

        [LLM ANALYZER] God Object candidate
          Analyzer: llm-code-analysis
          Provider: lm-studio
          Model: qwen
          Explanation: The type owns unrelated responsibilities.
          Evidence:
            - The type handles users and invoices.

        Categorization
        --------------
        Assessment: Confirmed
        Grouped candidates: 2
        Analyzer agreement: Static analyzer + LLM analyzer
        Provider: ollama
        Model: qwen

        Review statistics
        -----------------
        Detected candidates: 2
          From static analyzers: 1
          From LLM analysis: 1
        Final issues: 1
          Confirmed: 1
        Findings by category:
          Anti-pattern: 1

        Evidence verification
        ---------------------
        Evidence 1 could not be matched exactly to source lines 2–10.

        [INFO] ARCA-NOTE: Review completed.
        """)
        #expect(!output.contains(
            "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-MISMATCH"
        ))
        #expect(!output.contains("Candidate assessments"))
        #expect(!output.contains("Requires manual review"))
        #expect(!output.contains("Why it was categorized this way"))
        #expect(!output.contains("Static and LLM evidence agree."))
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
        ARCA Review Analysis
        1 candidate

        [WARNING] ARCA-GOD-001: God Object candidate
        File: Sources/App.swift:1:1-20:2
        Explanation: The type exceeds multiple thresholds.
        Evidence:
          - methods: 30 (threshold: 25)
        """)
    }

    @Test("shows uncertain issues as requiring manual review")
    func rendersManualReviewCount() throws {
        let candidate = try categorizedStaticCandidate()
        let finding = Finding(
            id: candidate.candidateID,
            candidateIDs: [candidate.candidateID],
            assessment: .uncertain,
            ruleID: "ARCA-GOD-001",
            title: "God Object",
            category: .antiPattern,
            severity: .warning,
            classificationRationale: "The evidence is inconclusive.",
            sources: ["god-object"],
            candidates: [candidate]
        )
        let report = CategorizedReviewReport(
            schemaVersion: 1,
            requestID: UUID(),
            categorizationSummary: "One issue needs review.",
            confirmedFindings: [],
            uncertainFindings: [finding],
            candidates: [candidate],
            categorizationDecisions: [],
            counts: ReviewReportCounts(
                totalCandidates: 1,
                confirmed: 0,
                rejected: 0,
                uncertain: 1,
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
                providerDurationMilliseconds: 12
            )
        )

        let output = try TerminalReporter(outputIsTTY: { false })
            .render(report: report)

        #expect(output.contains(
            "Overall result: 1 issue requiring manual review"
        ))
        #expect(output.contains("Final issues: 1"))
        #expect(output.contains("  Confirmed: 0"))
        #expect(output.contains("  Requires manual review: 1"))
    }

    @Test("renders skipped analyzer diagnostics")
    func rendersSkippedDiagnostic() throws {
        let diagnostic = AnalyzerDiagnostic(
            code: "ARCA-SWIFTLINT-UNAVAILABLE",
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
        #expect(output.contains("ARCA-SWIFTLINT-UNAVAILABLE"))
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

private func categorizedStaticCandidate() throws -> FindingCandidate {
    try FindingCandidate(
        candidateID: UUID(
            uuidString: "11111111-1111-1111-1111-111111111111"
        )!,
        ruleID: "ARCA-GOD-001",
        title: "God Object candidate",
        explanation: "The type exceeds multiple structural thresholds.",
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

private func categorizedLLMCandidate() throws -> FindingCandidate {
    try FindingCandidate(
        candidateID: UUID(
            uuidString: "22222222-2222-2222-2222-222222222222"
        )!,
        ruleID: "ARCA-GOD-001",
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
        evidence: [.sourceCode(SourceCodeEvidence(
            description: "The type handles users and invoices.",
            range: SourceRange(
                startLine: 2,
                startColumn: 1,
                endLine: 10,
                endColumn: 2
            ),
            excerpt: "final class App"
        ))],
        sourceIdentifiers: [
            "llm-code-analysis",
            "llm-provider:lm-studio",
            "llm-model:qwen"
        ]
    )
}

private func experimentalLLMCandidate() throws -> FindingCandidate {
    try FindingCandidate(
        candidateID: UUID(
            uuidString: "22222222-2222-2222-2222-222222222222"
        )!,
        ruleID: "ARCA-GOD-001",
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
        evidence: [.sourceCode(SourceCodeEvidence(
            description: "The type handles users and invoices.",
            range: SourceRange(
                startLine: 2,
                startColumn: 1,
                endLine: 10,
                endColumn: 2
            ),
            excerpt: "final class App"
        ))],
        sourceIdentifiers: [
            "llm-code-analysis",
            "llm-provider:lm-studio",
            "llm-model:qwen"
        ]
    )
}

private func llmDetectionReport(
    promptVariant: CodeAnalysisPromptVariant,
    candidates: [FindingCandidate] = [],
    diagnostics: [AnalyzerDiagnostic] = [],
    usage: LLMTokenUsageMetadata = LLMTokenUsageMetadata()
) -> LLMIssueDetectionReport {
    LLMIssueDetectionReport(
        requestID: UUID(),
        filePath: "Sources/App.swift",
        reviewType: .godObject,
        promptVariant: promptVariant,
        analysis: AnalyzerResult(
            analyzerID: "llm-code-analysis",
            candidates: candidates,
            tool: ToolMetadata(name: "lm-studio", version: "qwen"),
            diagnostics: diagnostics,
            llmExecutionMetadata: LLMExecutionMetadata(
                providerID: "lm-studio",
                modelID: "qwen",
                requestCount: 1,
                usage: usage,
                providerDurationMilliseconds: 25
            )
        ),
        seed: 42,
        temperature: 0
    )
}

private func categorizedFinding(
    candidates: [FindingCandidate]
) -> Finding {
    Finding(
        id: candidates[0].candidateID,
        candidateIDs: candidates.map(\.candidateID),
        assessment: .confirmed,
        ruleID: "ARCA-GOD-001",
        title: "God Object",
        category: .antiPattern,
        severity: .warning,
        classificationRationale: "Static and LLM evidence agree.",
        sources: ["god-object", "llm-code-analysis"],
        candidates: candidates
    )
}

private func terminalCandidate() throws -> FindingCandidate {
    try FindingCandidate(
        candidateID: UUID(),
        ruleID: "ARCA-GOD-001",
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
