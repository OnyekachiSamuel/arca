import ArcanDomain

public struct AnalysisContext: Equatable, Sendable {
    public let request: ReviewRequest

    public init(request: ReviewRequest) {
        self.request = request
    }
}
