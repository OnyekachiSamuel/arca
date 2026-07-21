import ArcanDomain
import Foundation
import Testing
@testable import ArcanAnalysis

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
        let analyzerResult = AnalyzerResult(
            analyzerID: "mock",
            findings: [],
            tool: ToolMetadata(name: "MockTool", version: "1.2.3")
        )
        let recorder = RecordAnalysisContext()
        let analyzer = MockAnalyzer(
            recorder: recorder,
            result: analyzerResult
        )
        let runner = AnalyzerRunner(
            clock: TestAnalyzerClock.make(milliseconds: [0, 8])
        )

        let result = try await runner.run(analyzer, context: context)

        #expect(result.analyzerID == "mock")
        #expect(result.findings.isEmpty)
        #expect(
            result.tool == ToolMetadata(
                name: "MockTool",
                version: "1.2.3"
            )
        )
        #expect(result.durationMilliseconds == 8)
        #expect(analyzer.id == "mock")
        #expect(analyzer.supportedReviewTypes == [.godObject, .style])
        let receivedContext = await recorder.receivedContext
        #expect(receivedContext == context)
        #expect(receivedContext?.changes == [change])
        #expect(receivedContext?.sourceContexts == [sourceContext])
    }

    @Test("runner executes only analyzers selected by the registry")
    func executesSelectedAnalyzers() async throws {
        let request = ReviewRequest(
            id: UUID(),
            selectedFiles: ["Sources/App.swift"],
            selectedReviewTypes: [.godObject]
        )
        let context = AnalysisContext(request: request)
        let godObjectRecorder = AnalyzerInvocationRecorder()
        let styleRecorder = AnalyzerInvocationRecorder()
        let registry = AnalyzerRegistry(analyzers: [
            RecordingAnalyzer(
                id: "god-object",
                supportedReviewTypes: [.godObject],
                recorder: godObjectRecorder
            ),
            RecordingAnalyzer(
                id: "style",
                supportedReviewTypes: [.style],
                recorder: styleRecorder
            )
        ])
        let selectedAnalyzers = registry.analyzers(
            matching: request.selectedReviewTypes
        )

        let results = try await AnalyzerRunner().run(
            selectedAnalyzers,
            context: context
        )

        #expect(results.map(\.analyzerID) == ["god-object"])
        let godObjectInvocationCount =
            await godObjectRecorder.invocationCount
        let styleInvocationCount = await styleRecorder.invocationCount
        #expect(godObjectInvocationCount == 1)
        #expect(styleInvocationCount == 0)
    }

    @Test("runner preserves analyzer order and records exact durations")
    func preservesOrderAndRecordsDurations() async throws {
        let context = AnalysisContext(
            request: ReviewRequest(id: UUID(), selectedFiles: [])
        )
        let recorder = AnalyzerOrderRecorder()
        let analyzers: [any Analyzer] = [
            OrderedAnalyzer(id: "first", recorder: recorder),
            OrderedAnalyzer(id: "second", recorder: recorder)
        ]
        let runner = AnalyzerRunner(
            clock: TestAnalyzerClock.make(
                milliseconds: [0, 10, 10, 35]
            )
        )

        let results = try await runner.run(analyzers, context: context)

        #expect(results.map(\.analyzerID) == ["first", "second"])
        #expect(results.map(\.durationMilliseconds) == [10, 25])
        let events = await recorder.events
        #expect(events == [
            "first-start",
            "first-end",
            "second-start",
            "second-end"
        ])
    }

    @Test("runner returns no results for an empty analyzer selection")
    func emptySelectionReturnsNoResults() async throws {
        let context = AnalysisContext(
            request: ReviewRequest(id: UUID(), selectedFiles: [])
        )
        let runner = AnalyzerRunner(
            clock: TestAnalyzerClock.make(milliseconds: [])
        )

        let results = try await runner.run([], context: context)

        #expect(results.isEmpty)
    }

    @Test("runner stops when one analyzer fails")
    func stopsAfterAnalyzerFailure() async {
        let context = AnalysisContext(
            request: ReviewRequest(id: UUID(), selectedFiles: [])
        )
        let recorder = AnalyzerOrderRecorder()
        let analyzers: [any Analyzer] = [
            OrderedAnalyzer(id: "first", recorder: recorder),
            FailingAnalyzer(id: "failing", recorder: recorder),
            OrderedAnalyzer(id: "third", recorder: recorder)
        ]

        do {
            _ = try await AnalyzerRunner().run(
                analyzers,
                context: context
            )
            Issue.record("Expected the runner to propagate the analyzer error.")
        } catch let error as AnalyzerRunnerTestError {
            #expect(error == .expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let events = await recorder.events
        #expect(events == [
            "first-start",
            "first-end",
            "failing-start"
        ])
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

private struct RecordingAnalyzer: Analyzer {
    let id: String
    let supportedReviewTypes: Set<ReviewType>
    let recorder: AnalyzerInvocationRecorder

    func analyze(context: AnalysisContext) async throws -> AnalyzerResult {
        await recorder.recordInvocation()
        return AnalyzerResult(analyzerID: id, findings: [])
    }
}

private actor AnalyzerInvocationRecorder {
    private(set) var invocationCount = 0

    func recordInvocation() {
        invocationCount += 1
    }
}

private struct OrderedAnalyzer: Analyzer {
    let id: String
    let supportedReviewTypes: Set<ReviewType> = [.godObject]
    let recorder: AnalyzerOrderRecorder

    func analyze(context: AnalysisContext) async throws -> AnalyzerResult {
        await recorder.record("\(id)-start")
        await recorder.record("\(id)-end")
        return AnalyzerResult(analyzerID: id, findings: [])
    }
}

private struct FailingAnalyzer: Analyzer {
    let id: String
    let supportedReviewTypes: Set<ReviewType> = [.godObject]
    let recorder: AnalyzerOrderRecorder

    func analyze(context: AnalysisContext) async throws -> AnalyzerResult {
        await recorder.record("\(id)-start")
        throw AnalyzerRunnerTestError.expected
    }
}

private actor AnalyzerOrderRecorder {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private enum AnalyzerRunnerTestError: Error, Equatable {
    case expected
}
