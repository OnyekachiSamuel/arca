public struct FindingCategorization: Codable, Equatable, Sendable {
    public let summary: String
    public let decisions: [FindingCategorizationDecision]

    public init(
        summary: String,
        decisions: [FindingCategorizationDecision]
    ) {
        self.summary = summary
        self.decisions = decisions
    }
}
