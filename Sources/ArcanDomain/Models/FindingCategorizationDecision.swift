import Foundation

public struct FindingCategorizationDecision: Codable, Equatable, Sendable {
    public let candidateIDs: [UUID]
    public let sourceIdentifiers: [String]
    public let assessment: FindingAssessment
    public let category: FindingCategory
    public let severity: Severity
    public let canonicalRuleID: String
    public let title: String
    public let rationale: String

    public init(
        candidateIDs: [UUID],
        sourceIdentifiers: [String],
        assessment: FindingAssessment,
        category: FindingCategory,
        severity: Severity,
        canonicalRuleID: String,
        title: String,
        rationale: String
    ) {
        self.candidateIDs = candidateIDs
        self.sourceIdentifiers = sourceIdentifiers
        self.assessment = assessment
        self.category = category
        self.severity = severity
        self.canonicalRuleID = canonicalRuleID
        self.title = title
        self.rationale = rationale
    }
}
