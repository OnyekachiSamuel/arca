import Foundation

public struct CategorizedReviewReport: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let requestID: UUID
    public let categorizationSummary: String?
    public let confirmedFindings: [Finding]
    public let uncertainFindings: [Finding]
    public let candidates: [FindingCandidate]
    public let categorizationDecisions: [FindingCategorizationDecision]
    public let counts: ReviewReportCounts
    public let diagnostics: [AnalyzerDiagnostic]
    public let analyzerResults: [AnalyzerResult]
    public let categorizationExecutionMetadata: LLMExecutionMetadata

    public init(
        schemaVersion: Int,
        requestID: UUID,
        categorizationSummary: String?,
        confirmedFindings: [Finding],
        uncertainFindings: [Finding],
        candidates: [FindingCandidate],
        categorizationDecisions: [FindingCategorizationDecision],
        counts: ReviewReportCounts,
        diagnostics: [AnalyzerDiagnostic],
        analyzerResults: [AnalyzerResult],
        categorizationExecutionMetadata: LLMExecutionMetadata
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.categorizationSummary = categorizationSummary
        self.confirmedFindings = confirmedFindings
        self.uncertainFindings = uncertainFindings
        self.candidates = candidates
        self.categorizationDecisions = categorizationDecisions
        self.counts = counts
        self.diagnostics = diagnostics
        self.analyzerResults = analyzerResults
        self.categorizationExecutionMetadata = categorizationExecutionMetadata
    }
}
