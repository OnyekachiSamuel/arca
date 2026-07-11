import ArcanDomain

public struct AnalyzerRunner: Sendable {
    public init() {}

    public func run(
        _ analyzer: any Analyzer,
        context: AnalysisContext
    ) async throws -> AnalyzerResult {
        try await analyzer.analyze(context: context)
    }
}
