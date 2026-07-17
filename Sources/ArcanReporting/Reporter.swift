import ArcanDomain

public protocol Reporter: Sendable {
    func render(report: ReviewReport) throws -> String
}
