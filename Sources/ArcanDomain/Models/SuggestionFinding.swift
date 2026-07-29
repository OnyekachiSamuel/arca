import Foundation

public struct SuggestionFinding: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let ruleID: String
    public let externalRuleID: String?
    public let title: String
    public let category: FindingCategory
    public let severity: Severity
    public let filePath: String
    public let range: SourceRange?
    public let explanation: String
    public let evidence: [Evidence]
    public let suggestion: Suggestion?
    public let sources: [String]
    public let metadata: [String: FindingMetadataValue]

    public init(
        id: UUID,
        ruleID: String,
        externalRuleID: String? = nil,
        title: String,
        category: FindingCategory = .uncategorized,
        severity: Severity,
        filePath: String,
        range: SourceRange? = nil,
        explanation: String,
        evidence: [Evidence] = [],
        suggestion: Suggestion? = nil,
        sources: [String] = [],
        metadata: [String: FindingMetadataValue] = [:]
    ) {
        self.id = id
        self.ruleID = ruleID
        self.externalRuleID = externalRuleID
        self.title = title
        self.category = category
        self.severity = severity
        self.filePath = filePath
        self.range = range
        self.explanation = explanation
        self.evidence = evidence
        self.suggestion = suggestion
        self.sources = sources
        self.metadata = metadata
    }

    public func withSuggestion(
        _ suggestion: Suggestion
    ) -> SuggestionFinding {
        SuggestionFinding(
            id: id,
            ruleID: ruleID,
            externalRuleID: externalRuleID,
            title: title,
            category: category,
            severity: severity,
            filePath: filePath,
            range: range,
            explanation: explanation,
            evidence: evidence,
            suggestion: suggestion,
            sources: sources,
            metadata: metadata
        )
    }
}
