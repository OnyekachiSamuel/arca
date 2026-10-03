public struct SourceFileChangeContext: Codable, Equatable, Sendable {
    public let addedLineRanges: [ChangedLineRange]
    public let modifiedLineRanges: [ChangedLineRange]
    public let deletedLineRanges: [DeletedLineRange]

    public init(
        addedLineRanges: [ChangedLineRange] = [],
        modifiedLineRanges: [ChangedLineRange] = [],
        deletedLineRanges: [DeletedLineRange] = []
    ) {
        self.addedLineRanges = addedLineRanges
        self.modifiedLineRanges = modifiedLineRanges
        self.deletedLineRanges = deletedLineRanges
    }
}
