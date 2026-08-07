import ArcaConfiguration
import ArcaDomain
import ArcaLLM
import Foundation

struct LLMProviderFactory: Sendable {
    func make(
        configuration: LLMConfiguration
    ) throws -> any LLMProvider {
        guard let baseURL = URL(string: configuration.baseURL) else {
            throw ConfigurationLoadingError.invalidValue(
                field: "llm.baseURL",
                reason: "must be a valid URL."
            )
        }

        return LLMServerProvider(configuration: LLMServerConfiguration(
            providerID: configuration.providerID,
            baseURL: baseURL,
            completionPath: configuration.completionPath
        ))
    }
}
