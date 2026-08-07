import ArcaDomain

public struct FindingCandidateAggregator: Sendable {
    private let normalizer: FindingCandidateNormalizer

    public init(
        normalizer: FindingCandidateNormalizer = FindingCandidateNormalizer()
    ) {
        self.normalizer = normalizer
    }

    public func aggregate(
        _ results: [AnalyzerResult],
        repositoryRoot: String?
    ) throws -> CandidateAggregationResult {
        let normalizedResults = try results.map { result in
            AnalyzerResult(
                analyzerID: result.analyzerID,
                candidates: try result.candidates.map {
                    try normalizer.normalize(
                        $0,
                        repositoryRoot: repositoryRoot,
                        sourceIdentifier: result.analyzerID
                    )
                },
                tool: result.tool,
                executionStatus: result.executionStatus,
                diagnostics: result.diagnostics,
                durationMilliseconds: result.durationMilliseconds,
                llmExecutionMetadata: result.llmExecutionMetadata
            )
        }

        return CandidateAggregationResult(
            candidates: normalizedResults.flatMap(\.candidates),
            analyzerResults: normalizedResults
        )
    }
}
