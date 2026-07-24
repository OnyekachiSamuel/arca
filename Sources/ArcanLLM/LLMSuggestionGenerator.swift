import ArcanDomain

public struct LLMSuggestionGenerator: Sendable {
    private let provider: any LLMProvider
    private let promptBuilder: SuggestionPromptBuilder
    private let parser: SuggestionParser
    private let modelID: String
    private let timeout: Duration
    private let seed: Int?
    private let temperature: Double?

    public init(
        provider: any LLMProvider,
        promptBuilder: SuggestionPromptBuilder,
        parser: SuggestionParser = SuggestionParser(),
        modelID: String,
        timeout: Duration,
        seed: Int? = nil,
        temperature: Double? = nil
    ) {
        self.provider = provider
        self.promptBuilder = promptBuilder
        self.parser = parser
        self.modelID = modelID
        self.timeout = timeout
        self.seed = seed
        self.temperature = temperature
    }

    public func generate(
        for finding: Finding,
        sourceContext: SourceContextWindow
    ) async throws -> SuggestionParsingResult {
        let prompt = try promptBuilder.build(
            finding: finding,
            sourceContext: sourceContext
        )
        let response = try await provider.submit(
            LLMRequest(
                modelID: modelID,
                prompt: prompt.text,
                timeout: timeout,
                seed: seed,
                temperature: temperature
            )
        )

        return parser.parse(response.text)
    }
}
