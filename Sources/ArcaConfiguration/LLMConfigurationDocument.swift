import ArcaDomain
import Foundation

struct LLMConfigurationDocument: Decodable {
    let providerID: String?
    let baseURL: String?
    let completionPath: String?
    let modelID: String?
    let timeoutSeconds: Int?
    let temperature: Double?
    let seed: Int?

    init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<ConfigurationCodingKey>
        do {
            container = try decoder.container(
                keyedBy: ConfigurationCodingKey.self
            )
        } catch {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "llm",
                reason: "expected a JSON object."
            )
        }

        try ConfigurationDecodingSupport.rejectUnknownFields(
            in: container,
            allowing: [
                "providerID",
                "baseURL",
                "completionPath",
                "modelID",
                "timeoutSeconds",
                "temperature",
                "seed"
            ],
            pathPrefix: "llm"
        )

        providerID = try Self.decodeOptional(
            String.self,
            key: "providerID",
            expectedType: "a string",
            from: container
        )
        baseURL = try Self.decodeOptional(
            String.self,
            key: "baseURL",
            expectedType: "a string",
            from: container
        )
        completionPath = try Self.decodeOptional(
            String.self,
            key: "completionPath",
            expectedType: "a string",
            from: container
        )
        modelID = try Self.decodeOptional(
            String.self,
            key: "modelID",
            expectedType: "a string",
            from: container
        )
        timeoutSeconds = try Self.decodeOptional(
            Int.self,
            key: "timeoutSeconds",
            expectedType: "an integer",
            from: container
        )
        temperature = try Self.decodeOptional(
            Double.self,
            key: "temperature",
            expectedType: "a number",
            from: container
        )
        seed = try Self.decodeOptional(
            Int.self,
            key: "seed",
            expectedType: "an integer",
            from: container
        )
    }

    func resolvedConfiguration() throws -> LLMConfiguration {
        let providerID = providerID ?? "llm-server"
        let completionPath = completionPath ?? "/v1/chat/completions"
        let timeoutSeconds = timeoutSeconds ?? 120

        guard !providerID.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw ConfigurationLoadingError.invalidValue(
                field: "llm.providerID",
                reason: "must not be empty."
            )
        }
        guard completionPath.hasPrefix("/"),
              !completionPath.hasPrefix("//") else {
            throw ConfigurationLoadingError.invalidValue(
                field: "llm.completionPath",
                reason: "must start with one '/'."
            )
        }
        guard timeoutSeconds > 0 else {
            throw ConfigurationLoadingError.invalidValue(
                field: "llm.timeoutSeconds",
                reason: "must be greater than zero."
            )
        }
        if let temperature {
            guard temperature.isFinite, (0...2).contains(temperature) else {
                throw ConfigurationLoadingError.invalidValue(
                    field: "llm.temperature",
                    reason: "must be between 0 and 2."
                )
            }
        }

        guard let baseURL,
              !baseURL.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty else {
            throw ConfigurationLoadingError.invalidValue(
                field: "llm.baseURL",
                reason: "is required."
            )
        }
        guard let url = URL(string: baseURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            throw ConfigurationLoadingError.invalidValue(
                field: "llm.baseURL",
                reason: "must be an HTTP or HTTPS URL with a host."
            )
        }
        guard let modelID,
              !modelID.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty else {
            throw ConfigurationLoadingError.invalidValue(
                field: "llm.modelID",
                reason: "is required."
            )
        }

        return LLMConfiguration(
            providerID: providerID,
            baseURL: baseURL,
            completionPath: completionPath,
            modelID: modelID,
            timeoutSeconds: timeoutSeconds,
            temperature: temperature,
            seed: seed
        )
    }

    private static func decodeOptional<Value: Decodable>(
        _ type: Value.Type,
        key: String,
        expectedType: String,
        from container: KeyedDecodingContainer<ConfigurationCodingKey>
    ) throws -> Value? {
        let codingKey = ConfigurationCodingKey(key)
        guard container.contains(codingKey) else { return nil }
        guard try !container.decodeNil(forKey: codingKey) else {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "llm.\(key)",
                reason: "expected \(expectedType)."
            )
        }

        do {
            return try container.decode(type, forKey: codingKey)
        } catch {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "llm.\(key)",
                reason: "expected \(expectedType)."
            )
        }
    }
}
