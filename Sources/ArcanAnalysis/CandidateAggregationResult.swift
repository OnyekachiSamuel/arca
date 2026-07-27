import ArcanDomain

public struct CandidateAggregationResult: Equatable, Sendable {
    public let candidates: [FindingCandidate]
    public let analyzerResults: [AnalyzerResult]

    public init(
        candidates: [FindingCandidate],
        analyzerResults: [AnalyzerResult]
    ) {
        self.candidates = candidates
        self.analyzerResults = analyzerResults
    }
}
