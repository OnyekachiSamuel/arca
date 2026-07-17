import ArcanAnalysis
import ArcanDomain
import Foundation
import Testing

@Suite("Analyzer runner")
struct AnalyzerRunnerTests {
    @Test("runner invokes an analyzer and returns its result")
    func invokesAnalyzer() async throws {
        let change = CodeChange(
            filePath: "Sources/App.swift",
            modifiedLineRanges: [
                ChangedLineRange(startLine: 4, endLine: 6)
            ]
        )
        let request = ReviewRequest(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            selectedFiles: ["Sources/App.swift"],
            changes: [change]
        )
        let sourceContext = SourceContextWindow(
            filePath: "Sources/App.swift",
            changedLineRange: ChangedLineRange(startLine: 4, endLine: 6),
            includedLineRange: SourceLineRange(startLine: 2, endLine: 8),
            sourceText: "struct App {}",
            containingType: nil
        )
        let context = AnalysisContext(
            request: request,
            sourceContexts: [sourceContext]
        )
        let expected = AnalyzerResult(analyzerID: "mock", findings: [])
        let recorder = RecordAnalysisContext()
        let analyzer = MockAnalyzer(recorder: recorder, result: expected)

        let result = try await AnalyzerRunner().run(analyzer, context: context)

        #expect(result == expected)
        #expect(analyzer.id == "mock")
        #expect(analyzer.supportedReviewTypes == [.godObject, .style])
        let receivedContext = await recorder.receivedContext
        #expect(receivedContext == context)
        #expect(receivedContext?.changes == [change])
        #expect(receivedContext?.sourceContexts == [sourceContext])
    }
}

private struct MockAnalyzer: Analyzer {
    let id = "mock"
    let supportedReviewTypes: Set<ReviewType> = [.godObject, .style]
    let recorder: RecordAnalysisContext
    let result: AnalyzerResult

    func analyze(context: AnalysisContext) async throws -> AnalyzerResult {
        await recorder.record(context)
        return result
    }
}

private actor RecordAnalysisContext {
    private(set) var receivedContext: AnalysisContext?

    func record(_ context: AnalysisContext) {
        receivedContext = context
    }
}
