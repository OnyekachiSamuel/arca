import ArcaDomain

public struct LLMResponse: Equatable, Sendable {
    public let text: String
    public let usage: LLMTokenUsageMetadata
    public let durationMilliseconds: Int

    public init(
        text: String,
        usage: LLMTokenUsageMetadata,
        durationMilliseconds: Int
    ) {
        self.text = text
        self.usage = usage
        self.durationMilliseconds = durationMilliseconds
    }
}
