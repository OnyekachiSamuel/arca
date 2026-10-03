public struct LLMConfiguration: Codable, Equatable, Sendable {
    public let defaultProvider: String
    public let providers: [LLMProviderConfiguration]
    
    public init(
        defaultProvider: String,
        providers: [LLMProviderConfiguration]
    ) {
        self.defaultProvider = defaultProvider
        self.providers = providers
    }
    
    public func provider(id: String? = nil) -> LLMProviderConfiguration? {
        let selectedID = id ?? defaultProvider
        return providers.first { $0.id == selectedID }
    }
}

public struct LLMProviderConfiguration: Codable, Equatable, Sendable {
    public let id: String
    public let baseURL: String
    public let completionPath: String
    public let modelID: String
    public let apiKeyEnvironmentVariable: String?
    public let timeoutSeconds: Int
    public let temperature: Double?
    public let seed: Int?
    
    public init(
        id: String,
        baseURL: String,
        completionPath: String = "/v1/chat/completions",
        modelID: String,
        apiKeyEnvironmentVariable: String? = nil,
        timeoutSeconds: Int = 120,
        temperature: Double? = nil,
        seed: Int? = nil
    ) {
        self.id = id
        self.baseURL = baseURL
        self.completionPath = completionPath
        self.modelID = modelID
        self.apiKeyEnvironmentVariable = apiKeyEnvironmentVariable
        self.timeoutSeconds = timeoutSeconds
        self.temperature = temperature
        self.seed = seed
    }
}
