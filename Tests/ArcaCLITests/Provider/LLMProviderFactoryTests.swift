import ArcaConfiguration
import ArcaDomain
import Testing

@testable import ArcaCLI

@Suite("LLM provider factory")
struct LLMProviderFactoryTests {
  @Test("reads the API key from the configured environment variable")
  func resolvesAPIKeyFromEnvironment() throws {
    let profile = LLMProviderConfiguration(
      id: "openai",
      baseURL: "https://api.openai.com",
      modelID: "gpt-test",
      apiKeyEnvironmentVariable: "OPENAI_API_KEY"
    )
    let factory = LLMProviderFactory(environment: [
      "OPENAI_API_KEY": "test-secret"
    ])

    let serverConfiguration = try factory.serverConfiguration(for: profile)

    #expect(serverConfiguration.apiKey == "test-secret")
  }

  @Test("missing API-key environment variable is an explicit safe error")
  func rejectsMissingAPIKey() {
    let profile = LLMProviderConfiguration(
      id: "openai",
      baseURL: "https://api.openai.com",
      modelID: "gpt-test",
      apiKeyEnvironmentVariable: "OPENAI_API_KEY"
    )

    #expect(
      throws: ConfigurationLoadingError.invalidValue(
        field: "llm.providers[openai].apiKeyEnvironmentVariable",
        reason: "environment variable 'OPENAI_API_KEY' is not set."
      )
    ) {
      try LLMProviderFactory(environment: [:]).serverConfiguration(for: profile)
    }
  }
}
