import ArcanDomain

public struct AnalysisContext: Equatable, Sendable {
    public let request: ReviewRequest
    public let sourceFiles: [SourceFile]

    public init(
        request: ReviewRequest,
        sourceFiles: [SourceFile] = []
    ) {
        self.request = request
        self.sourceFiles = sourceFiles
    }
}
