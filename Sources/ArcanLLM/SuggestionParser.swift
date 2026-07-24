import ArcanDomain
import Foundation

public struct SuggestionParser: Sendable {
    private static let maximumResponseUTF8Bytes = 16_000
    private static let maximumSummaryUTF8Bytes = 500
    private static let maximumStepCount = 20
    private static let maximumStepUTF8Bytes = 2_000
    private static let maximumCodeExampleUTF8Bytes = 8_000

    public init() {}

    public func parse(_ responseText: String) -> SuggestionParsingResult {
        guard responseText.utf8.count <= Self.maximumResponseUTF8Bytes else {
            return rejected(
                "The LLM suggestion response exceeds the maximum size."
            )
        }

        guard let jsonText = extractJSON(from: responseText),
              let jsonData = jsonText.data(using: .utf8) else {
            return rejected(
                "The LLM suggestion response is not a supported JSON document."
            )
        }

        let response: SuggestionResponse

        do {
            response = try JSONDecoder().decode(
                SuggestionResponse.self,
                from: jsonData
            )
        } catch {
            return rejected(
                "The LLM suggestion response does not match the required schema."
            )
        }

        let summary = response.summary.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !summary.isEmpty else {
            return rejected("The LLM suggestion summary must not be empty.")
        }
        guard summary.utf8.count <= Self.maximumSummaryUTF8Bytes else {
            return rejected(
                "The LLM suggestion summary exceeds the maximum size."
            )
        }

        guard (1...Self.maximumStepCount).contains(response.steps.count) else {
            return rejected(
                "The LLM suggestion must contain between 1 and \(Self.maximumStepCount) steps."
            )
        }

        let steps = response.steps.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard steps.allSatisfy({ !$0.isEmpty }) else {
            return rejected("LLM suggestion steps must not be empty.")
        }
        guard steps.allSatisfy({
            $0.utf8.count <= Self.maximumStepUTF8Bytes
        }) else {
            return rejected("An LLM suggestion step exceeds the maximum size.")
        }

        if let codeExample = response.codeExample {
            guard !codeExample.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty else {
                return rejected(
                    "The LLM code example must not be empty when provided."
                )
            }
            guard codeExample.utf8.count
                <= Self.maximumCodeExampleUTF8Bytes else {
                return rejected(
                    "The LLM code example exceeds the maximum size."
                )
            }
            guard !codeExample.contains("```") else {
                return rejected(
                    "The LLM code example must not contain Markdown fences."
                )
            }
        }

        return .parsed(
            Suggestion(
                summary: summary,
                steps: steps,
                codeExample: response.codeExample
            )
        )
    }

    private func extractJSON(from responseText: String) -> String? {
        let trimmedResponse = responseText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard trimmedResponse.hasPrefix("```") else {
            return trimmedResponse
        }

        let lines = trimmedResponse.components(separatedBy: .newlines)
        guard lines.count >= 3,
              lines.first == "```" || lines.first == "```json",
              lines.last == "```" else {
            return nil
        }

        let jsonText = lines
            .dropFirst()
            .dropLast()
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !jsonText.contains("```") else {
            return nil
        }

        return jsonText
    }

    private func rejected(_ message: String) -> SuggestionParsingResult {
        .rejected(
            AnalyzerDiagnostic(
                code: "ARCAN-LLM-SUGGESTION-INVALID",
                severity: .warning,
                message: message
            )
        )
    }
}

private struct SuggestionResponse: Decodable {
    let summary: String
    let steps: [String]
    let codeExample: String?
}
