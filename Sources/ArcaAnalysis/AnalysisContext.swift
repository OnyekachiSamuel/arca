import ArcaDomain

public struct AnalysisContext: Equatable, Sendable {
    public let request: ReviewRequest
    public let sourceFiles: [SourceFile]
    public let changes: [CodeChange]

    public init(
        request: ReviewRequest,
        sourceFiles: [SourceFile] = [],
        changes: [CodeChange]? = nil
    ) {
        self.request = request
        self.sourceFiles = sourceFiles
        self.changes = changes ?? request.changes
    }
}
