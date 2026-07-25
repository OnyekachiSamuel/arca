public struct SourceFileAnalysisContextLimits: Equatable, Sendable {
    public let maximumSourceUTF8Bytes: Int

    public init(maximumSourceUTF8Bytes: Int) {
        self.maximumSourceUTF8Bytes = maximumSourceUTF8Bytes
    }

    public static let `default` = SourceFileAnalysisContextLimits(
        maximumSourceUTF8Bytes: 64_000
    )
}
