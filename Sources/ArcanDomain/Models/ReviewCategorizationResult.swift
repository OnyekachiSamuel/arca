public struct ReviewCategorizationResult: Codable, Equatable, Sendable {
    public let analysis: ReviewAnalysisResult
    public let categorization: FindingCategorization?
    public let categorizationDiagnostics: [AnalyzerDiagnostic]
    public let llmExecutionMetadata: LLMExecutionMetadata

    public init(
        analysis: ReviewAnalysisResult,
        categorization: FindingCategorization?,
        categorizationDiagnostics: [AnalyzerDiagnostic],
        llmExecutionMetadata: LLMExecutionMetadata
    ) {
        self.analysis = analysis
        self.categorization = categorization
        self.categorizationDiagnostics = categorizationDiagnostics
        self.llmExecutionMetadata = llmExecutionMetadata
    }
}
