import Foundation

public struct Finding: Codable, Equatable, Sendable, Identifiable {
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

    public func withSuggestion(_ suggestion: Suggestion) -> Finding {
        Finding(
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

    private enum CodingKeys: String, CodingKey {
        case id
        case ruleID
        case externalRuleID
        case title
        case category
        case severity
        case filePath
        case range
        case explanation
        case evidence
        case suggestion
        case sources
        case metadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ruleID = try container.decode(String.self, forKey: .ruleID)
        externalRuleID = try container.decodeIfPresent(
            String.self,
            forKey: .externalRuleID
        )
        title = try container.decode(String.self, forKey: .title)
        category = try container.decodeIfPresent(
            FindingCategory.self,
            forKey: .category
        ) ?? .uncategorized
        severity = try container.decode(Severity.self, forKey: .severity)
        filePath = try container.decode(String.self, forKey: .filePath)
        range = try container.decodeIfPresent(SourceRange.self, forKey: .range)
        explanation = try container.decode(String.self, forKey: .explanation)
        evidence = try container.decodeIfPresent(
            [Evidence].self,
            forKey: .evidence
        ) ?? []
        suggestion = try container.decodeIfPresent(
            Suggestion.self,
            forKey: .suggestion
        )
        sources = try container.decodeIfPresent(
            [String].self,
            forKey: .sources
        ) ?? []
        metadata = try container.decodeIfPresent(
            [String: FindingMetadataValue].self,
            forKey: .metadata
        ) ?? [:]
    }
}
