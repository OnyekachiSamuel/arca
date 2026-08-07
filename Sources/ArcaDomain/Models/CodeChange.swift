public struct CodeChange: Codable, Equatable, Sendable {
    public let filePath: String
    public let previousFilePath: String?
    public let addedLineRanges: [ChangedLineRange]
    public let modifiedLineRanges: [ChangedLineRange]
    public let deletedLineRanges: [DeletedLineRange]

    public init(
        filePath: String,
        previousFilePath: String? = nil,
        addedLineRanges: [ChangedLineRange] = [],
        modifiedLineRanges: [ChangedLineRange] = [],
        deletedLineRanges: [DeletedLineRange] = []
    ) {
        self.filePath = filePath
        self.previousFilePath = previousFilePath
        self.addedLineRanges = addedLineRanges
        self.modifiedLineRanges = modifiedLineRanges
        self.deletedLineRanges = deletedLineRanges
    }
}
