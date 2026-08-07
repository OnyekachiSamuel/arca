import Foundation

enum PromptTextRedactor {
    static func redactCommonSecrets(in text: String) -> String {
        let replacements = [
            PromptSecretReplacement(
                pattern: #"(?i)(\b(?:let|var)\s+(?:(?:password|passwd|token|api_?key|secret|access_?key)|[A-Za-z_][A-Za-z0-9_]*(?:password|passwd|token|api_?key|secret|access_?key)[A-Za-z0-9_]*)\s*(?::[^=\n]+)?=\s*)\"(?:\\.|[^\"\\])*\""#,
                template: #"$1\"[REDACTED]\""#
            ),
            PromptSecretReplacement(
                pattern: #"(?i)(\bBearer\s+)[A-Za-z0-9._~+/=-]{8,}"#,
                template: "$1[REDACTED]"
            ),
            PromptSecretReplacement(
                pattern: #"\b(?:sk-[A-Za-z0-9_-]{8,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b"#,
                template: "[REDACTED]"
            ),
            PromptSecretReplacement(
                pattern: #"-----BEGIN(?: [A-Z0-9]+)? PRIVATE KEY-----[\s\S]*?-----END(?: [A-Z0-9]+)? PRIVATE KEY-----"#,
                template: "[REDACTED PRIVATE KEY]"
            )
        ]

        return replacements.reduce(text) { redactedText, replacement in
            replacement.apply(to: redactedText)
        }
    }
}

private struct PromptSecretReplacement {
    let pattern: String
    let template: String

    func apply(to text: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: template
        )
    }
}
