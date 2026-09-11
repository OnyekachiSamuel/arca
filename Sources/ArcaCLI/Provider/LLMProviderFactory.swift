import ArcaConfiguration
import ArcaDomain
import ArcaLLM
import Foundation

struct LLMProviderFactory: Sendable {
  private let environment: [String: String]

  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    self.environment = environment
  }

  func make(
    configuration: LLMProviderConfiguration
  ) throws -> any LLMProvider {
    LLMServerProvider(configuration: try serverConfiguration(for: configuration))
  }

  func serverConfiguration(
    for configuration: LLMProviderConfiguration
  ) throws -> LLMServerConfiguration {
    guard let baseURL = URL(string: configuration.baseURL) else {
      throw ConfigurationLoadingError.invalidValue(
        field: "llm.providers[\(configuration.id)].baseURL",
        reason: "must be a valid URL."
      )
    }

    let apiKey: String?
    if let variable = configuration.apiKeyEnvironmentVariable {
      guard let value = environment[variable],
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw ConfigurationLoadingError.invalidValue(
          field: "llm.providers[\(configuration.id)].apiKeyEnvironmentVariable",
          reason: "environment variable '\(variable)' is not set."
        )
      }
      apiKey = value
    } else {
      apiKey = nil
    }

    return LLMServerConfiguration(
      providerID: configuration.id,
      baseURL: baseURL,
      completionPath: configuration.completionPath,
      apiKey: apiKey
    )
  }
}
