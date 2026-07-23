import ArcanDomain

public struct RuleKnowledge: Codable, Equatable, Sendable {
    public let ruleID: String
    public let title: String
    public let category: FindingCategory
    public let defaultSeverity: Severity
    public let definition: String
    public let evidenceCriteria: [String]
    public let refactoringGuardrails: [String]

    public init(
        ruleID: String,
        title: String,
        category: FindingCategory,
        defaultSeverity: Severity,
        definition: String,
        evidenceCriteria: [String],
        refactoringGuardrails: [String]
    ) {
        self.ruleID = ruleID
        self.title = title
        self.category = category
        self.defaultSeverity = defaultSeverity
        self.definition = definition
        self.evidenceCriteria = evidenceCriteria
        self.refactoringGuardrails = refactoringGuardrails
    }
}
