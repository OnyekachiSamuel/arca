public struct ReviewReportCounts: Codable, Equatable, Sendable {
    public let totalCandidates: Int
    public let confirmed: Int
    public let rejected: Int
    public let uncertain: Int
    public let findingsPerCategory: [CategoryFindingCount]

    public init(
        totalCandidates: Int,
        confirmed: Int,
        rejected: Int,
        uncertain: Int,
        findingsPerCategory: [CategoryFindingCount]
    ) {
        self.totalCandidates = totalCandidates
        self.confirmed = confirmed
        self.rejected = rejected
        self.uncertain = uncertain
        self.findingsPerCategory = findingsPerCategory
    }
}
