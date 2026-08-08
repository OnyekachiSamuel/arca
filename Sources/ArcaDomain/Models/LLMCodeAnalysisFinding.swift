import Foundation

public enum LLMDetectedIssueType: String, Codable, CaseIterable, Sendable {
    case codeSmell
    case antiPattern
    case architecture
    case style
    case teamConvention
    case general
}

public struct LLMCodeAnalysisFinding: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let canonicalRuleID: String?
    public let title: String
    public let issueType: LLMDetectedIssueType
    public let explanation: String
    public let filePath: String
    public let range: SourceRange
    public let severity: Severity
    public let evidence: [FindingEvidence]
    public let sourceIdentifiers: [String]
    public let metadata: [String: FindingMetadataValue]

    public init(
        id: UUID = UUID(),
        canonicalRuleID: String?,
        title: String,
        issueType: LLMDetectedIssueType,
        explanation: String,
        filePath: String,
        range: SourceRange,
        severity: Severity,
        evidence: [FindingEvidence],
        sourceIdentifiers: [String],
        metadata: [String: FindingMetadataValue] = [:]
    ) {
        self.id = id
        self.canonicalRuleID = canonicalRuleID
        self.title = title
        self.issueType = issueType
        self.explanation = explanation
        self.filePath = filePath
        self.range = range
        self.severity = severity
        self.evidence = evidence
        self.sourceIdentifiers = sourceIdentifiers
        self.metadata = metadata
    }
}
