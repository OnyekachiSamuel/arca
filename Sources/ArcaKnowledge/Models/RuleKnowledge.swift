import ArcaDomain

public struct RuleKnowledge: Codable, Equatable, Sendable {
    public let ruleID: String
    public let title: String
    public let group: RuleKnowledgeGroup
    public let category: FindingCategory
    public let defaultSeverity: Severity
    public let definition: String
    public let evidenceCriteria: [String]
    public let classificationGuidance: [String]
    public let severityGuidance: [String]
    public let refactoringGuardrails: [String]

    public init(
        ruleID: String,
        title: String,
        group: RuleKnowledgeGroup,
        category: FindingCategory,
        defaultSeverity: Severity,
        definition: String,
        evidenceCriteria: [String],
        classificationGuidance: [String],
        severityGuidance: [String],
        refactoringGuardrails: [String]
    ) {
        self.ruleID = ruleID
        self.title = title
        self.group = group
        self.category = category
        self.defaultSeverity = defaultSeverity
        self.definition = definition
        self.evidenceCriteria = evidenceCriteria
        self.classificationGuidance = classificationGuidance
        self.severityGuidance = severityGuidance
        self.refactoringGuardrails = refactoringGuardrails
    }
}
