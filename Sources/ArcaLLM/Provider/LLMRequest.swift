public struct LLMRequest: Equatable, Sendable {
    public let modelID: String
    public let prompt: String
    public let timeout: Duration
    public let seed: Int?
    public let temperature: Double?

    public init(
        modelID: String,
        prompt: String,
        timeout: Duration,
        seed: Int? = nil,
        temperature: Double? = nil
    ) {
        self.modelID = modelID
        self.prompt = prompt
        self.timeout = timeout
        self.seed = seed
        self.temperature = temperature
    }
}
