import ArcanDomain
import Foundation
import Testing
@testable import ArcanAnalysis

@Suite("Review engine")
struct ReviewEngineTests {
    @Test("engine builds one report in stable analyzer and finding order")
    func buildsStableReport() async throws {
        let requestID = UUID(
            uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        )!
        let context = AnalysisContext(
            request: ReviewRequest(
                id: requestID,
                repositoryRoot: "/project",
                selectedFiles: ["Sources/App.swift"]
            )
        )
        let analyzers: [any Analyzer] = [
            ResultAnalyzer(
                id: "first",
                finding: finding(
                    id: "11111111-2222-3333-4444-555555555555",
                    ruleID: "FIRST",
                    filePath: "/project/Sources/App.swift"
                )
            ),
            ResultAnalyzer(
                id: "second",
                finding: finding(
                    id: "66666666-7777-8888-9999-AAAAAAAAAAAA",
                    ruleID: "SECOND",
                    filePath: "/project/Sources/Other.swift"
                )
            )
        ]
        let runner = AnalyzerRunner(
            clock: TestAnalyzerClock.make(
                milliseconds: [0, 4, 4, 13]
            )
        )
        let engine = ReviewEngine(runner: runner)

        let report = try await engine.review(
            analyzers: analyzers,
            context: context
        )

        #expect(
            report.schemaVersion == ReviewReport.currentSchemaVersion
        )
        #expect(report.requestID == requestID)
        #expect(
            report.analyzerResults.map(\.analyzerID)
                == ["first", "second"]
        )
        #expect(
            report.analyzerResults.map(\.durationMilliseconds)
                == [4, 9]
        )
        #expect(report.findings.map(\.ruleID) == ["FIRST", "SECOND"])
        #expect(
            report.findings.map(\.filePath)
                == ["Sources/App.swift", "Sources/Other.swift"]
        )
        #expect(
            report.analyzerResults.flatMap(\.findings).map(\.filePath)
                == ["Sources/App.swift", "Sources/Other.swift"]
        )
        #expect(
            report.findings.map(\.sources)
                == [["first"], ["second"]]
        )
        #expect(
            report.analyzerResults.flatMap(\.findings).map(\.sources)
                == [["first"], ["second"]]
        )
    }

    @Test("engine builds an empty report when no analyzers are selected")
    func buildsEmptyReport() async throws {
        let requestID = UUID()
        let context = AnalysisContext(
            request: ReviewRequest(id: requestID, selectedFiles: [])
        )
        let runner = AnalyzerRunner(
            clock: TestAnalyzerClock.make(milliseconds: [])
        )
        let engine = ReviewEngine(runner: runner)

        let report = try await engine.review(
            analyzers: [],
            context: context
        )

        #expect(report.requestID == requestID)
        #expect(report.analyzerResults.isEmpty)
        #expect(report.findings.isEmpty)
    }

    private func finding(
        id: String,
        ruleID: String,
        filePath: String
    ) -> Finding {
        Finding(
            id: UUID(uuidString: id)!,
            ruleID: ruleID,
            title: ruleID,
            severity: .warning,
            filePath: filePath,
            explanation: "\(ruleID) explanation"
        )
    }
}

private struct ResultAnalyzer: Analyzer {
    let id: String
    let supportedReviewTypes: Set<ReviewType> = [.godObject]
    let finding: Finding

    func analyze(context: AnalysisContext) async throws -> AnalyzerResult {
        AnalyzerResult(analyzerID: id, findings: [finding])
    }
}
