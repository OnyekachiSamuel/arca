import ArcanDomain

public struct IssueCategorizationParsingResult: Equatable, Sendable {
    public let categorization: FindingCategorization?
    public let diagnostics: [AnalyzerDiagnostic]

    public init(
        categorization: FindingCategorization?,
        diagnostics: [AnalyzerDiagnostic]
    ) {
        self.categorization = categorization
        self.diagnostics = diagnostics
    }
}
