public struct CodeAnalysisPromptLimits: Equatable, Sendable {
    public let maximumPromptUTF8Bytes: Int

    public init(maximumPromptUTF8Bytes: Int) {
        self.maximumPromptUTF8Bytes = maximumPromptUTF8Bytes
    }

    public static let `default` = CodeAnalysisPromptLimits(
        maximumPromptUTF8Bytes: 96_000
    )
}
