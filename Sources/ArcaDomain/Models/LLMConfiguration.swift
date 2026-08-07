public struct LLMConfiguration: Codable, Equatable, Sendable {
    public let providerID: String
    public let baseURL: String
    public let completionPath: String
    public let modelID: String
    public let timeoutSeconds: Int
    public let temperature: Double?
    public let seed: Int?

    public init(
        providerID: String = "llm-server",
        baseURL: String,
        completionPath: String = "/v1/chat/completions",
        modelID: String,
        timeoutSeconds: Int = 120,
        temperature: Double? = nil,
        seed: Int? = nil
    ) {
        self.providerID = providerID
        self.baseURL = baseURL
        self.completionPath = completionPath
        self.modelID = modelID
        self.timeoutSeconds = timeoutSeconds
        self.temperature = temperature
        self.seed = seed
    }
}
