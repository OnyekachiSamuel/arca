import ArcanAnalysis
import ArcanDomain
import Foundation
import Testing

@Suite("Analyzer runner")
struct AnalyzerRunnerTests {
    @Test("runner invokes an analyzer and returns its result")
    func invokesAnalyzer() async throws {
        let request = ReviewRequest(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            selectedFiles: ["Sources/App.swift"]
        )
        let context = AnalysisContext(request: request)
        let expected = AnalyzerResult(analyzerID: "mock", findings: [])
        let recorder = RecordAnalysisContext()
        let analyzer = MockAnalyzer(recorder: recorder, result: expected)

        let result = try await AnalyzerRunner().run(analyzer, context: context)

        #expect(result == expected)
        #expect(analyzer.id == "mock")
        #expect(analyzer.supportedReviewTypes == [.godObject, .style])
        let receivedContext = await recorder.receivedContext
        #expect(receivedContext == context)
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
