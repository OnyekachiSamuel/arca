import ArcanDomain

public struct SourceFileAnalysisContextBuildResult: Equatable, Sendable {
    public let contexts: [SourceFileAnalysisContext]
    public let diagnostics: [AnalyzerDiagnostic]

    public init(
        contexts: [SourceFileAnalysisContext],
        diagnostics: [AnalyzerDiagnostic]
    ) {
        self.contexts = contexts
        self.diagnostics = diagnostics
    }
}
