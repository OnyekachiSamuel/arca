import ArcaDomain

public protocol Reporter: Sendable {
    func render(analysis: ReviewAnalysisResult) throws -> String
    func render(report: CategorizedReviewReport) throws -> String
}
