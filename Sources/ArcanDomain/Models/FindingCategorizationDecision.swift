import Foundation

public struct FindingCategorizationDecision:
    Codable,
    Equatable,
    Sendable
{
    public let candidateIDs: [UUID]
    public let assessment: FindingAssessment
    public let category: FindingCategory
    public let severity: Severity
    public let canonicalRuleID: String
    public let title: String
    public let rationale: String

    public init(
        candidateIDs: [UUID],
        assessment: FindingAssessment,
        category: FindingCategory,
        severity: Severity,
        canonicalRuleID: String,
        title: String,
        rationale: String
    ) {
        self.candidateIDs = candidateIDs
        self.assessment = assessment
        self.category = category
        self.severity = severity
        self.canonicalRuleID = canonicalRuleID
        self.title = title
        self.rationale = rationale
    }
}
