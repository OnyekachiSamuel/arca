public struct SourceCodeEvidence: Codable, Equatable, Sendable {
    public let description: String
    public let range: SourceRange
    public let excerpt: String

    public init(
        description: String,
        range: SourceRange,
        excerpt: String
    ) {
        self.description = description
        self.range = range
        self.excerpt = excerpt
    }
}
