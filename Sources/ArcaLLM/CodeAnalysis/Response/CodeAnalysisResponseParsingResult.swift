import ArcaDomain

public struct CodeAnalysisResponseParsingResult: Equatable, Sendable {
    public let candidates: [FindingCandidate]
    public let diagnostics: [LLMIssueDetectionDiagnostic]
    
    public init(
        candidates: [FindingCandidate],
        diagnostics: [LLMIssueDetectionDiagnostic]
    ) {
        self.candidates = candidates
        self.diagnostics = diagnostics
    }
}
