public struct SourceFileAnalysisContext: Codable, Equatable, Sendable {
    public let filePath: String
    public let sourceContent: String
    public let lineCount: Int
    public let change: SourceFileChangeContext?

    public init(
        filePath: String,
        sourceContent: String,
        lineCount: Int,
        change: SourceFileChangeContext? = nil
    ) {
        self.filePath = filePath
        self.sourceContent = sourceContent
        self.lineCount = lineCount
        self.change = change
    }
}
