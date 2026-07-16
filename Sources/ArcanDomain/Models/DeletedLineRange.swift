public struct DeletedLineRange: Codable, Equatable, Sendable {
    public let originalStartLine: Int
    public let originalEndLine: Int

    public init(originalStartLine: Int, originalEndLine: Int) {
        self.originalStartLine = originalStartLine
        self.originalEndLine = originalEndLine
    }
}
