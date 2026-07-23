import ArcanDomain

public enum SuggestionParsingResult: Equatable, Sendable {
    case parsed(Suggestion)
    case rejected(AnalyzerDiagnostic)
}
