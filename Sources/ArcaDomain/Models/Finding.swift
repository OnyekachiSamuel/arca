import Foundation

public struct Finding: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let candidateIDs: [UUID]
    public let assessment: FindingAssessment
    public let ruleID: String
    public let title: String
    public let category: FindingCategory
    public let severity: Severity
    public let classificationRationale: String
    public let sources: [String]
    public let candidates: [FindingCandidate]

    public init(
        id: UUID,
        candidateIDs: [UUID],
        assessment: FindingAssessment,
        ruleID: String,
        title: String,
        category: FindingCategory,
        severity: Severity,
        classificationRationale: String,
        sources: [String],
        candidates: [FindingCandidate]
    ) {
        self.id = id
        self.candidateIDs = candidateIDs
        self.assessment = assessment
        self.ruleID = ruleID
        self.title = title
        self.category = category
        self.severity = severity
        self.classificationRationale = classificationRationale
        self.sources = sources
        self.candidates = candidates
    }
}
