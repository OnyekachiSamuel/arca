public struct SourceFileChangeContext: Codable, Equatable, Sendable {
    public let previousFilePath: String?
    public let addedLineRanges: [ChangedLineRange]
    public let modifiedLineRanges: [ChangedLineRange]
    public let deletedLineRanges: [DeletedLineRange]

    public init(
        previousFilePath: String? = nil,
        addedLineRanges: [ChangedLineRange] = [],
        modifiedLineRanges: [ChangedLineRange] = [],
        deletedLineRanges: [DeletedLineRange] = []
    ) {
        self.previousFilePath = previousFilePath
        self.addedLineRanges = addedLineRanges
        self.modifiedLineRanges = modifiedLineRanges
        self.deletedLineRanges = deletedLineRanges
    }
}
