public struct SourceCodeEvidence: Codable, Equatable, Sendable {
    public let description: String
    public let range: SourceRange

    public init(
        description: String,
        range: SourceRange
    ) {
        self.description = description
        self.range = range
    }
}
