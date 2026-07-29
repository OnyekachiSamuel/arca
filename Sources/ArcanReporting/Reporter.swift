import ArcanDomain

public protocol Reporter: Sendable {
    func render(analysis: ReviewAnalysisResult) throws -> String
    func render(report: ReviewReport) throws -> String
}
