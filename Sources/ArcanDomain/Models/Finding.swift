import Foundation

public struct Finding: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let ruleID: String
    public let title: String
    public let severity: Severity
    public let filePath: String
    public let explanation: String
    public let suggestion: Suggestion?

    public init(
        id: UUID,
        ruleID: String,
        title: String,
        severity: Severity,
        filePath: String,
        explanation: String,
        suggestion: Suggestion? = nil
    ) {
        self.id = id
        self.ruleID = ruleID
        self.title = title
        self.severity = severity
        self.filePath = filePath
        self.explanation = explanation
        self.suggestion = suggestion
    }
}
