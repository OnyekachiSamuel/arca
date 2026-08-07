import ArcaDomain

public struct GodObjectRuleMetadata: Equatable, Sendable {
    public let ruleID: String
    public let title: String
    public let category: FindingCategory
    public let severity: Severity
    public let explanation: String

    public init(
        ruleID: String,
        title: String,
        category: FindingCategory = .antiPattern,
        severity: Severity,
        explanation: String
    ) {
        self.ruleID = ruleID
        self.title = title
        self.category = category
        self.severity = severity
        self.explanation = explanation
    }

    public static let standard = GodObjectRuleMetadata(
        ruleID: "ARCA-GOD-001",
        title: "God Object candidate",
        category: .antiPattern,
        severity: .warning,
        explanation: "exceeds multiple configured structural thresholds and has low cohesion, suggesting it may have too many responsibilities."
    )
}
