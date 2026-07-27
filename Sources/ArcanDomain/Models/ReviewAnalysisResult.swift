import Foundation

public struct ReviewAnalysisResult: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let requestID: UUID
    public let candidates: [FindingCandidate]
    public let analyzerResults: [AnalyzerResult]
    public let diagnostics: [AnalyzerDiagnostic]

    public init(
        schemaVersion: Int,
        requestID: UUID,
        candidates: [FindingCandidate],
        analyzerResults: [AnalyzerResult],
        diagnostics: [AnalyzerDiagnostic]
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.candidates = candidates
        self.analyzerResults = analyzerResults
        self.diagnostics = diagnostics
    }
}
