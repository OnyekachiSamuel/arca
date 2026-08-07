public struct CategoryFindingCount: Codable, Equatable, Sendable {
    public let category: FindingCategory
    public let count: Int

    public init(category: FindingCategory, count: Int) {
        self.category = category
        self.count = count
    }
}
