import ArcanDomain

public protocol SourceContextProvider: Sendable {
    func contexts(
        for change: CodeChange,
        in sourceFile: SourceFile,
        surroundingLineCount: Int
    ) throws -> [SourceContextWindow]
}
