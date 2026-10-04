import ArcaDomain
import Foundation

public struct LLMServerProvider: LLMProvider, Sendable {
    typealias RequestSender = @Sendable (
        URLRequest
    ) async throws -> (Data, URLResponse)

    public let id: String

    private let configuration: LLMServerConfiguration
    private let sendRequest: RequestSender

    public init(configuration: LLMServerConfiguration) {
        self.init(
            configuration: configuration,
            sendRequest: { request in
                try await URLSession.shared.data(for: request)
            }
        )
    }

    init(
        configuration: LLMServerConfiguration,
        sendRequest: @escaping RequestSender
    ) {
        self.configuration = configuration
        self.sendRequest = sendRequest
        id = configuration.providerID
    }

    public func submit(_ request: LLMRequest) async throws -> LLMResponse {
        let urlRequest = try makeURLRequest(for: request)
        let clock = ContinuousClock()
        let start = clock.now
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await sendRequest(urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .timedOut {
            throw LLMServerProviderError.requestTimedOut
        } catch {
            throw LLMServerProviderError.transportFailure
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServerProviderError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LLMServerProviderError.unexpectedStatusCode(
                httpResponse.statusCode
            )
        }

        let serverResponse: ChatCompletionResponse

        do {
            serverResponse = try JSONDecoder().decode(
                ChatCompletionResponse.self,
                from: data
            )
        } catch {
            throw LLMServerProviderError.invalidResponse
        }

        guard let content = serverResponse.choices.first?.message.content,
              !content.isEmpty else {
            throw LLMServerProviderError.missingResponseContent
        }

        return LLMResponse(
            text: content,
            usage: LLMTokenUsageMetadata(
                inputTokens: serverResponse.usage?.promptTokens,
                outputTokens: serverResponse.usage?.completionTokens,
                totalTokens: serverResponse.usage?.totalTokens
            ),
            durationMilliseconds: milliseconds(
                in: start.duration(to: clock.now)
            )
        )
    }

    private func makeURLRequest(
        for request: LLMRequest
    ) throws -> URLRequest {
        guard let scheme = configuration.baseURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              configuration.baseURL.host != nil,
              !configuration.providerID
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
              configuration.completionPath.hasPrefix("/"),
              !configuration.completionPath.hasPrefix("//"),
              let endpointURL = URL(
                string: configuration.completionPath,
                relativeTo: configuration.baseURL
              )?.absoluteURL else {
            throw LLMServerProviderError.invalidServerConfiguration
        }

        let modelID = request.modelID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !modelID.isEmpty,
              !request.prompt
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
              request.timeout > .zero,
              let timeoutInterval = timeInterval(for: request.timeout) else {
            throw LLMServerProviderError.invalidRequest
        }

        let body = ChatCompletionRequest(
            model: modelID,
            messages: [
                ChatMessage(role: "user", content: request.prompt)
            ],
            stream: false,
            seed: request.seed,
            temperature: request.temperature,
            responseFormat: request.responseFormat.map(
                ChatCompletionResponseFormat.init
            )
        )
        let encodedBody: Data

        do {
            encodedBody = try JSONEncoder().encode(body)
        } catch {
            throw LLMServerProviderError.requestEncodingFailed
        }

        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeoutInterval
        urlRequest.httpBody = encodedBody
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            urlRequest.setValue(
                "Bearer \(apiKey)",
                forHTTPHeaderField: "Authorization"
            )
        }

        return urlRequest
    }

    private func timeInterval(for duration: Duration) -> TimeInterval? {
        let components = duration.components
        let seconds =
            Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000

        guard seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }

    private func milliseconds(in duration: Duration) -> Int {
        let components = duration.components
        let milliseconds =
            components.seconds * 1_000
            + components.attoseconds / 1_000_000_000_000_000
        return max(0, Int(milliseconds))
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let seed: Int?
    let temperature: Double?
    let responseFormat: ChatCompletionResponseFormat?

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case seed
        case temperature
        case responseFormat = "response_format"
    }
}

private struct ChatCompletionResponseFormat: Encodable {
    let type = "json_schema"
    let jsonSchema: ChatCompletionJSONSchema

    init(_ format: LLMStructuredResponseFormat) {
        switch format {
        case .codeAnalysis(let requiresRuleID):
            jsonSchema = ChatCompletionJSONSchema(
                name: "arca_code_analysis",
                strict: true,
                schema: CodeAnalysisJSONSchema(
                    requiresRuleID: requiresRuleID
                )
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }
}

private struct ChatCompletionJSONSchema: Encodable {
    let name: String
    let strict: Bool
    let schema: CodeAnalysisJSONSchema
}

private struct CodeAnalysisJSONSchema: Encodable {
    let type = "object"
    let properties: RootProperties
    let required = ["findings"]
    let additionalProperties = false

    init(requiresRuleID: Bool) {
        properties = RootProperties(
            findings: FindingArraySchema(
                requiresRuleID: requiresRuleID
            )
        )
    }
}

private struct RootProperties: Encodable {
    let findings: FindingArraySchema
}

private struct FindingArraySchema: Encodable {
    let type = "array"
    let items: FindingSchema
    let minItems = 0
    let maxItems = 5

    init(requiresRuleID: Bool) {
        items = FindingSchema(requiresRuleID: requiresRuleID)
    }
}

private struct FindingSchema: Encodable {
    let type = "object"
    let properties: FindingProperties
    let required: [String]
    let additionalProperties = false

    init(requiresRuleID: Bool) {
        properties = FindingProperties(requiresRuleID: requiresRuleID)
        required = requiresRuleID
            ? ["ruleID", "explanation", "evidence"]
            : ["title", "explanation", "evidence"]
    }
}

private struct FindingProperties: Encodable {
    let ruleID: StringSchema?
    let title: StringSchema?
    let explanation = StringSchema()
    let evidence = EvidenceArraySchema()

    init(requiresRuleID: Bool) {
        ruleID = requiresRuleID ? StringSchema() : nil
        title = requiresRuleID ? nil : StringSchema()
    }
}

private struct EvidenceArraySchema: Encodable {
    let type = "array"
    let items = EvidenceSchema()
    let minItems = 1
    let maxItems = 5
}

private struct EvidenceSchema: Encodable {
    let type = "object"
    let properties = EvidenceProperties()
    let required = ["description", "startLine", "endLine"]
    let additionalProperties = false
}

private struct EvidenceProperties: Encodable {
    let description = StringSchema()
    let startLine = IntegerSchema()
    let endLine = IntegerSchema()
}

private struct StringSchema: Encodable {
    let type = "string"
}

private struct IntegerSchema: Encodable {
    let type = "integer"
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [ChatCompletionChoice]
    let usage: ChatCompletionUsage?
}

private struct ChatCompletionChoice: Decodable {
    let message: ChatCompletionResponseMessage
}

private struct ChatCompletionResponseMessage: Decodable {
    let content: String
}

private struct ChatCompletionUsage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}
