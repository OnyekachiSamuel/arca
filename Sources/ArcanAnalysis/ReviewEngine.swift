import ArcanDomain

public struct ReviewEngine: Sendable {
    private let runner: AnalyzerRunner
    private let findingNormalizer: FindingNormalizer

    public init(
        runner: AnalyzerRunner = AnalyzerRunner(),
        findingNormalizer: FindingNormalizer = FindingNormalizer()
    ) {
        self.runner = runner
        self.findingNormalizer = findingNormalizer
    }

    public func review(
        analyzers: [any Analyzer],
        context: AnalysisContext
    ) async throws -> ReviewReport {
        let rawAnalyzerResults = try await runner.run(
            analyzers,
            context: context
        )
        let analyzerResults = try rawAnalyzerResults.map { result in
            AnalyzerResult(
                analyzerID: result.analyzerID,
                findings: try result.findings.map {
                    try findingNormalizer.normalize(
                        $0,
                        repositoryRoot: context.request.repositoryRoot,
                        sourceIdentifier: result.analyzerID
                    )
                },
                tool: result.tool,
                executionStatus: result.executionStatus,
                diagnostics: result.diagnostics,
                durationMilliseconds: result.durationMilliseconds
            )
        }

        return ReviewReport(
            schemaVersion: ReviewReport.currentSchemaVersion,
            requestID: context.request.id,
            findings: analyzerResults.flatMap(\.findings),
            analyzerResults: analyzerResults
        )
    }
}
