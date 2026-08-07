public struct LLMResponse: Equatable, Sendable {
    public let text: String
    public let usage: LLMUsageMetadata
    public let durationMilliseconds: Int

    public init(
        text: String,
        usage: LLMUsageMetadata,
        durationMilliseconds: Int
    ) {
        self.text = text
        self.usage = usage
        self.durationMilliseconds = durationMilliseconds
    }
}
