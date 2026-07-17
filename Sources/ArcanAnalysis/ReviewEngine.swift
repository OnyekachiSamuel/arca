import ArcanDomain

public struct ReviewEngine: Sendable {
    private let runner: AnalyzerRunner

    public init(runner: AnalyzerRunner = AnalyzerRunner()) {
        self.runner = runner
    }

    public func review(
        analyzers: [any Analyzer],
        context: AnalysisContext
    ) async throws -> ReviewReport {
        let analyzerResults = try await runner.run(
            analyzers,
            context: context
        )

        return ReviewReport(
            schemaVersion: 1,
            requestID: context.request.id,
            findings: analyzerResults.flatMap(\.findings),
            analyzerResults: analyzerResults
        )
    }
}
