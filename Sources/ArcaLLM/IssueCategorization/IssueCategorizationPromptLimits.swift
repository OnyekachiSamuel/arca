public struct IssueCategorizationPromptLimits: Equatable, Sendable {
    public let maximumPromptUTF8Bytes: Int

    public init(maximumPromptUTF8Bytes: Int) {
        self.maximumPromptUTF8Bytes = maximumPromptUTF8Bytes
    }

    public static let `default` = IssueCategorizationPromptLimits(
        maximumPromptUTF8Bytes: 96_000
    )
}
