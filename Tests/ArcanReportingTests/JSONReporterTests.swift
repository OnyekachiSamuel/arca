import ArcanDomain
import ArcanReporting
import Foundation
import Testing

@Suite("JSON reporter")
struct JSONReporterTests {
    @Test("output decodes to the original versioned report")
    func rendersDecodableReport() throws {
        let report = makeReport()
        let reporter: any Reporter = JSONReporter()

        let output = try reporter.render(report: report)
        let decoded = try JSONDecoder().decode(
            ReviewReport.self,
            from: Data(output.utf8)
        )

        #expect(decoded == report)
        #expect(
            decoded.schemaVersion == ReviewReport.currentSchemaVersion
        )
        #expect(!output.contains("ARCAN Review Report"))
        #expect(!output.contains("\u{001B}["))
        #expect(!output.contains("```"))
    }

    private func makeReport() -> ReviewReport {
        let finding = Finding(
            id: UUID(
                uuidString: "11111111-2222-3333-4444-555555555555"
            )!,
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            severity: .warning,
            filePath: "Sources/LargeCoordinator.swift",
            explanation: "The type exceeds configured thresholds."
        )
        return ReviewReport(
            schemaVersion: ReviewReport.currentSchemaVersion,
            requestID: UUID(
                uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
            )!,
            findings: [finding],
            analyzerResults: [
                AnalyzerResult(
                    analyzerID: "god-object",
                    findings: [finding],
                    durationMilliseconds: 12
                )
            ]
        )
    }
}
