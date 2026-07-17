public struct SourceContextWindow: Codable, Equatable, Sendable {
    public let filePath: String
    public let changedLineRange: ChangedLineRange
    public let includedLineRange: SourceLineRange
    public let sourceText: String
    public let containingType: TypeStructuralMetrics?

    public init(
        filePath: String,
        changedLineRange: ChangedLineRange,
        includedLineRange: SourceLineRange,
        sourceText: String,
        containingType: TypeStructuralMetrics?
    ) {
        self.filePath = filePath
        self.changedLineRange = changedLineRange
        self.includedLineRange = includedLineRange
        self.sourceText = sourceText
        self.containingType = containingType
    }
}
