import ArcaDomain
import Foundation

struct LLMConfigurationDocument: Decodable {
  let defaultProvider: String
  let providers: [LLMProviderConfigurationDocument]

  init(from decoder: any Decoder) throws {
    let container: KeyedDecodingContainer<ConfigurationCodingKey>
    do {
      container = try decoder.container(keyedBy: ConfigurationCodingKey.self)
    } catch {
      throw ConfigurationDecodingIssue.invalidValue(
        field: "llm",
        reason: "expected a JSON object."
      )
    }

    try ConfigurationDecodingSupport.rejectUnknownFields(
      in: container,
      allowing: ["defaultProvider", "providers"],
      pathPrefix: "llm"
    )
    defaultProvider = try Self.decodeRequired(
      String.self,
      key: "defaultProvider",
      expectedType: "a string",
      from: container
    )
    providers = try Self.decodeRequired(
      [LLMProviderConfigurationDocument].self,
      key: "providers",
      expectedType: "an array",
      from: container
    )
  }

  func resolvedConfiguration() throws -> LLMConfiguration {
    let defaultProvider = defaultProvider.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !defaultProvider.isEmpty else {
      throw ConfigurationLoadingError.invalidValue(
        field: "llm.defaultProvider",
        reason: "must not be empty."
      )
    }
    guard !providers.isEmpty else {
      throw ConfigurationLoadingError.invalidValue(
        field: "llm.providers",
        reason: "must contain at least one provider."
      )
    }

    let resolved = try providers.enumerated().map { index, provider in
      try provider.resolvedConfiguration(index: index)
    }
    guard Set(resolved.map(\.id)).count == resolved.count else {
      throw ConfigurationLoadingError.invalidValue(
        field: "llm.providers",
        reason: "provider IDs must be unique."
      )
    }
    guard resolved.contains(where: { $0.id == defaultProvider }) else {
      throw ConfigurationLoadingError.invalidValue(
        field: "llm.defaultProvider",
        reason: "must identify a configured provider."
      )
    }

    return LLMConfiguration(
      defaultProvider: defaultProvider,
      providers: resolved
    )
  }

  private static func decodeRequired<Value: Decodable>(
    _ type: Value.Type,
    key: String,
    expectedType: String,
    from container: KeyedDecodingContainer<ConfigurationCodingKey>
  ) throws -> Value {
    let codingKey = ConfigurationCodingKey(key)
    guard container.contains(codingKey),
      try !container.decodeNil(forKey: codingKey)
    else {
      throw ConfigurationDecodingIssue.invalidValue(
        field: "llm.\(key)",
        reason: "expected \(expectedType)."
      )
    }
    do {
      return try container.decode(type, forKey: codingKey)
    } catch let issue as ConfigurationDecodingIssue {
      throw issue
    } catch {
      throw ConfigurationDecodingIssue.invalidValue(
        field: "llm.\(key)",
        reason: "expected \(expectedType)."
      )
    }
  }
}

struct LLMProviderConfigurationDocument: Decodable {
  let id: String?
  let baseURL: String?
  let completionPath: String?
  let modelID: String?
  let apiKeyEnvironmentVariable: String?
  let timeoutSeconds: Int?
  let temperature: Double?
  let seed: Int?

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: ConfigurationCodingKey.self)
    try ConfigurationDecodingSupport.rejectUnknownFields(
      in: container,
      allowing: [
        "id", "baseURL", "completionPath", "modelID",
        "apiKeyEnvironmentVariable", "timeoutSeconds", "temperature", "seed",
      ],
      pathPrefix: "llm.providers"
    )
    id = try container.decodeIfPresent(String.self, forKey: .init("id"))
    baseURL = try container.decodeIfPresent(String.self, forKey: .init("baseURL"))
    completionPath = try container.decodeIfPresent(
      String.self,
      forKey: .init("completionPath")
    )
    modelID = try container.decodeIfPresent(String.self, forKey: .init("modelID"))
    apiKeyEnvironmentVariable = try container.decodeIfPresent(
      String.self,
      forKey: .init("apiKeyEnvironmentVariable")
    )
    timeoutSeconds = try container.decodeIfPresent(
      Int.self,
      forKey: .init("timeoutSeconds")
    )
    temperature = try container.decodeIfPresent(
      Double.self,
      forKey: .init("temperature")
    )
    seed = try container.decodeIfPresent(Int.self, forKey: .init("seed"))
  }

  func resolvedConfiguration(index: Int) throws -> LLMProviderConfiguration {
    let prefix = "llm.providers[\(index)]"
    let id = try requiredNonempty(id, field: "\(prefix).id")
    let baseURL = try requiredNonempty(baseURL, field: "\(prefix).baseURL")
    let modelID = try requiredNonempty(modelID, field: "\(prefix).modelID")
    let completionPath = completionPath ?? "/v1/chat/completions"
    let timeoutSeconds = timeoutSeconds ?? 120

    guard let url = URL(string: baseURL),
      let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https",
      url.host != nil
    else {
      throw ConfigurationLoadingError.invalidValue(
        field: "\(prefix).baseURL",
        reason: "must be an HTTP or HTTPS URL with a host."
      )
    }
    guard completionPath.hasPrefix("/"), !completionPath.hasPrefix("//") else {
      throw ConfigurationLoadingError.invalidValue(
        field: "\(prefix).completionPath",
        reason: "must start with one '/'."
      )
    }
    guard timeoutSeconds > 0 else {
      throw ConfigurationLoadingError.invalidValue(
        field: "\(prefix).timeoutSeconds",
        reason: "must be greater than zero."
      )
    }
    if let temperature,
      !temperature.isFinite || !(0...2).contains(temperature)
    {
      throw ConfigurationLoadingError.invalidValue(
        field: "\(prefix).temperature",
        reason: "must be between 0 and 2."
      )
    }
    if let apiKeyEnvironmentVariable,
      apiKeyEnvironmentVariable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      throw ConfigurationLoadingError.invalidValue(
        field: "\(prefix).apiKeyEnvironmentVariable",
        reason: "must not be empty."
      )
    }

    return LLMProviderConfiguration(
      id: id,
      baseURL: baseURL,
      completionPath: completionPath,
      modelID: modelID,
      apiKeyEnvironmentVariable: apiKeyEnvironmentVariable,
      timeoutSeconds: timeoutSeconds,
      temperature: temperature,
      seed: seed
    )
  }

  private func requiredNonempty(
    _ value: String?,
    field: String
  ) throws -> String {
    guard let value,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw ConfigurationLoadingError.invalidValue(
        field: field,
        reason: "is required."
      )
    }
    return value
  }
}
