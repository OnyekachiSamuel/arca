import ArcanDomain

public protocol Analyzer: Sendable {
    var id: String { get }
    var supportedReviewTypes: Set<ReviewType> { get }

    func analyze(context: AnalysisContext) async throws -> AnalyzerResult
}
