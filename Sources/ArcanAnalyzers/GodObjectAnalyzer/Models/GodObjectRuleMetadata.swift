import ArcanDomain

public struct GodObjectRuleMetadata: Equatable, Sendable {
    public let ruleID: String
    public let title: String
    public let category: FindingCategory
    public let severity: Severity
    public let explanation: String
    public let suggestion: Suggestion

    public init(
        ruleID: String,
        title: String,
        category: FindingCategory = .antiPattern,
        severity: Severity,
        explanation: String,
        suggestion: Suggestion
    ) {
        self.ruleID = ruleID
        self.title = title
        self.category = category
        self.severity = severity
        self.explanation = explanation
        self.suggestion = suggestion
    }

    public static let standard = GodObjectRuleMetadata(
        ruleID: "ARCAN-GOD-001",
        title: "God Object candidate",
        category: .antiPattern,
        severity: .warning,
        explanation: "exceeds multiple configured structural thresholds, suggesting it may have too many responsibilities.",
        suggestion: Suggestion(
            summary: "Split the type into smaller, focused components.",
            steps: [
                "Group related properties and methods by responsibility.",
                "Extract each responsibility into a dedicated type.",
                "Keep only necessary coordination in the original type."
            ]
        )
    )
}
