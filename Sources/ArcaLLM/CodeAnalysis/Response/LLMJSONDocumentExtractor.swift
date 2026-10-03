import Foundation

enum LLMJSONDocumentExtractor {
    static func extract(from responseText: String) -> String? {
        let trimmedResponse = responseText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        guard !trimmedResponse.isEmpty else { return nil }
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
        
        guard !jsonText.isEmpty,
              !jsonText.contains("```") else {
            return nil
        }
        
        return jsonText
    }
}
