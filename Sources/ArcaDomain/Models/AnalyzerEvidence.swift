public struct AnalyzerEvidence: Codable, Equatable, Sendable {
    public let description: String
    public let externalRuleID: String?
    public let range: SourceRange?

    public init(
        description: String,
        externalRuleID: String? = nil,
        range: SourceRange? = nil
    ) {
        self.description = description
        self.externalRuleID = externalRuleID
        self.range = range
    }
}
