import ArcaDomain

public struct ReviewEngine: Sendable {
    private let runner: AnalyzerRunner
    private let candidateAggregator: FindingCandidateAggregator

    public init(
        runner: AnalyzerRunner = AnalyzerRunner(),
        candidateAggregator: FindingCandidateAggregator =
            FindingCandidateAggregator()
    ) {
        self.runner = runner
        self.candidateAggregator = candidateAggregator
    }

    public func review(
        analyzers: [any Analyzer],
        context: AnalysisContext
    ) async throws -> ReviewAnalysisResult {
        let rawAnalyzerResults = try await runner.run(
            analyzers,
            context: context
        )
        let aggregation = try candidateAggregator.aggregate(
            rawAnalyzerResults,
            repositoryRoot: context.request.repositoryRoot
        )

        return ReviewAnalysisResult(
            schemaVersion: ReviewAnalysisResult.currentSchemaVersion,
            requestID: context.request.id,
            candidates: aggregation.candidates,
            analyzerResults: aggregation.analyzerResults,
            diagnostics: aggregation.analyzerResults.flatMap(\.diagnostics)
        )
    }
}
