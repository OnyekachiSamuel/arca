import ArcanDomain

public struct CodeAnalysisResponseParsingResult: Equatable, Sendable {
    public let candidates: [FindingCandidate]
    public let diagnostics: [AnalyzerDiagnostic]

    public init(
        candidates: [FindingCandidate],
        diagnostics: [AnalyzerDiagnostic]
    ) {
        self.candidates = candidates
        self.diagnostics = diagnostics
    }
}
