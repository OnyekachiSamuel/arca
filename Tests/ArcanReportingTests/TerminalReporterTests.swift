import ArcanDomain
import ArcanReporting
import Foundation
import Testing

@Suite("Terminal reporter")
struct TerminalReporterTests {
    @Test("non-TTY output matches the readable finding snapshot without color")
    func rendersFindingWithoutColor() throws {
        let reporter: any Reporter = TerminalReporter(outputIsTTY: { false })

        let output = try reporter.render(report: makeReport())

        let expected = """
        ARCAN Review Report
        1 finding

        [WARNING] ARCAN-GOD-001: God Object candidate
        File: Sources/LargeCoordinator.swift:1:1-9:2
        Explanation: Type 'LargeCoordinator' exceeds multiple configured structural thresholds.
        Evidence:
          - lines: 9 (threshold: 8)
          - methods: 3 (threshold: 2)
          - storedProperties: 3 (threshold: 2)
        Suggestion: Split the type into smaller, focused components.
          1. Extract networking.
          2. Extract persistence.
        """

        #expect(output == expected)
        #expect(!output.contains("\u{001B}["))
    }

    @Test("TTY output applies severity color")
    func rendersFindingWithColor() throws {
        let reporter = TerminalReporter(outputIsTTY: { true })

        let output = try reporter.render(report: makeReport())

        #expect(output.contains("\u{001B}[33m[WARNING]\u{001B}[0m"))
    }

    @Test("skipped analyzers and diagnostics are visible")
    func rendersSkippedAnalyzerDiagnostic() throws {
        let report = ReviewReport(
            schemaVersion: ReviewReport.currentSchemaVersion,
            requestID: UUID(),
            findings: [],
            analyzerResults: [
                AnalyzerResult(
                    analyzerID: "swiftlint",
                    findings: [],
                    tool: ToolMetadata(name: "SwiftLint"),
                    executionStatus: .skipped,
                    diagnostics: [
                        AnalyzerDiagnostic(
                            code: "ARCAN-SWIFTLINT-UNAVAILABLE",
                            severity: .warning,
                            message: "SwiftLint was not found. Style analysis was skipped."
                        )
                    ]
                )
            ]
        )
        let reporter = TerminalReporter(outputIsTTY: { false })

        let output = try reporter.render(report: report)

        #expect(output == """
        ARCAN Review Report
        0 findings
        1 analyzer skipped

        [WARNING] ARCAN-SWIFTLINT-UNAVAILABLE: SwiftLint was not found. Style analysis was skipped.
        """)
    }

    private func makeReport() -> ReviewReport {
        let finding = Finding(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            severity: .warning,
            filePath: "Sources/LargeCoordinator.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 9,
                endColumn: 2
            ),
            explanation: "Type 'LargeCoordinator' exceeds multiple configured structural thresholds.",
            evidence: [
                Evidence(metric: "lines", observedValue: 9, thresholdValue: 8),
                Evidence(metric: "methods", observedValue: 3, thresholdValue: 2),
                Evidence(
                    metric: "storedProperties",
                    observedValue: 3,
                    thresholdValue: 2
                )
            ],
            suggestion: Suggestion(
                summary: "Split the type into smaller, focused components.",
                steps: ["Extract networking.", "Extract persistence."]
            )
        )
        return ReviewReport(
            schemaVersion: ReviewReport.currentSchemaVersion,
            requestID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            findings: [finding],
            analyzerResults: [
                AnalyzerResult(analyzerID: "god-object", findings: [finding])
            ]
        )
    }
}
