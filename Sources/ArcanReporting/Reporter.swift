import ArcanDomain

public protocol Reporter: Sendable {
    func render(analysis: ReviewAnalysisResult) throws -> String
}
