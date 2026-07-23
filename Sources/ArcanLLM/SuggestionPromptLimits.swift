public struct SuggestionPromptLimits: Equatable, Sendable {
    public let maximumSourceUTF8Bytes: Int
    public let maximumPromptUTF8Bytes: Int

    public init(
        maximumSourceUTF8Bytes: Int,
        maximumPromptUTF8Bytes: Int
    ) {
        self.maximumSourceUTF8Bytes = maximumSourceUTF8Bytes
        self.maximumPromptUTF8Bytes = maximumPromptUTF8Bytes
    }

    public static let `default` = SuggestionPromptLimits(
        maximumSourceUTF8Bytes: 16_000,
        maximumPromptUTF8Bytes: 32_000
    )
}
