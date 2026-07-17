import ArcanDomain

public struct AnalyzerRegistry: Sendable {
    private let registeredAnalyzers: [any Analyzer]

    public init(analyzers: [any Analyzer]) {
        registeredAnalyzers = analyzers
    }

    public var supportedReviewTypes: Set<ReviewType> {
        registeredAnalyzers.reduce(into: Set<ReviewType>()) {
            supportedReviewTypes, analyzer in
            supportedReviewTypes.formUnion(analyzer.supportedReviewTypes)
        }
    }

    public func analyzers(
        matching selectedReviewTypes: Set<ReviewType>
    ) -> [any Analyzer] {
        registeredAnalyzers.filter { analyzer in
            !analyzer.supportedReviewTypes.isDisjoint(
                with: selectedReviewTypes
            )
        }
    }
}
