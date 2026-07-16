import Foundation

public struct Finding: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let ruleID: String
    public let title: String
    public let severity: Severity
    public let filePath: String
    public let range: SourceRange?
    public let explanation: String
    public let evidence: [Evidence]
    public let suggestion: Suggestion?

    public init(
        id: UUID,
        ruleID: String,
        title: String,
        severity: Severity,
        filePath: String,
        range: SourceRange? = nil,
        explanation: String,
        evidence: [Evidence] = [],
        suggestion: Suggestion? = nil
    ) {
        self.id = id
        self.ruleID = ruleID
        self.title = title
        self.severity = severity
        self.filePath = filePath
        self.range = range
        self.explanation = explanation
        self.evidence = evidence
        self.suggestion = suggestion
    }
}
