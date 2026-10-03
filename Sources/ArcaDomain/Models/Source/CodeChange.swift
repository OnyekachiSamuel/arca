public struct CodeChange: Codable, Equatable, Sendable {
    public let filePath: String
    public let addedLineRanges: [ChangedLineRange]
    public let modifiedLineRanges: [ChangedLineRange]
    public let deletedLineRanges: [DeletedLineRange]

    public init(
        filePath: String,
        addedLineRanges: [ChangedLineRange] = [],
        modifiedLineRanges: [ChangedLineRange] = [],
        deletedLineRanges: [DeletedLineRange] = []
    ) {
        self.filePath = filePath
        self.addedLineRanges = addedLineRanges
        self.modifiedLineRanges = modifiedLineRanges
        self.deletedLineRanges = deletedLineRanges
    }
}
