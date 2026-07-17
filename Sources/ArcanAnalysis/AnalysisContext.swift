import ArcanDomain

public struct AnalysisContext: Equatable, Sendable {
    public let request: ReviewRequest
    public let sourceFiles: [SourceFile]
    public let changes: [CodeChange]
    public let sourceContexts: [SourceContextWindow]

    public init(
        request: ReviewRequest,
        sourceFiles: [SourceFile] = [],
        changes: [CodeChange]? = nil,
        sourceContexts: [SourceContextWindow] = []
    ) {
        self.request = request
        self.sourceFiles = sourceFiles
        self.changes = changes ?? request.changes
        self.sourceContexts = sourceContexts
    }
}
