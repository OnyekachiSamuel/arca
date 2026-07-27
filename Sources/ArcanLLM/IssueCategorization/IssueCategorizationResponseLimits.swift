public struct IssueCategorizationResponseLimits: Equatable, Sendable {
    public let maximumResponseUTF8Bytes: Int
    public let maximumSummaryUTF8Bytes: Int
    public let maximumDecisionCount: Int
    public let maximumCandidateIDsPerDecision: Int
    public let maximumTitleUTF8Bytes: Int
    public let maximumRationaleUTF8Bytes: Int

    public init(
        maximumResponseUTF8Bytes: Int = 64_000,
        maximumSummaryUTF8Bytes: Int = 4_000,
        maximumDecisionCount: Int = 100,
        maximumCandidateIDsPerDecision: Int = 100,
        maximumTitleUTF8Bytes: Int = 500,
        maximumRationaleUTF8Bytes: Int = 4_000
    ) {
        self.maximumResponseUTF8Bytes = maximumResponseUTF8Bytes
        self.maximumSummaryUTF8Bytes = maximumSummaryUTF8Bytes
        self.maximumDecisionCount = maximumDecisionCount
        self.maximumCandidateIDsPerDecision = maximumCandidateIDsPerDecision
        self.maximumTitleUTF8Bytes = maximumTitleUTF8Bytes
        self.maximumRationaleUTF8Bytes = maximumRationaleUTF8Bytes
    }

    public static let `default` = IssueCategorizationResponseLimits()

    var isValid: Bool {
        maximumResponseUTF8Bytes > 0
            && maximumSummaryUTF8Bytes > 0
            && maximumDecisionCount > 0
            && maximumCandidateIDsPerDecision > 0
            && maximumTitleUTF8Bytes > 0
            && maximumRationaleUTF8Bytes > 0
    }
}
