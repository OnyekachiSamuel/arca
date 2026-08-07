public struct LLMExecutionMetadata: Codable, Equatable, Sendable {
    public let providerID: String
    public let modelID: String
    public let requestCount: Int
    public let usage: LLMTokenUsageMetadata
    public let providerDurationMilliseconds: Int

    public init(
        providerID: String,
        modelID: String,
        requestCount: Int,
        usage: LLMTokenUsageMetadata = LLMTokenUsageMetadata(),
        providerDurationMilliseconds: Int
    ) {
        self.providerID = providerID
        self.modelID = modelID
        self.requestCount = requestCount
        self.usage = usage
        self.providerDurationMilliseconds = providerDurationMilliseconds
    }
}
