import ArcanDomain
import ArcanKnowledge
import Foundation

public struct SuggestionPromptBuilder: Sendable {
    private let knowledgeProvider: any RuleKnowledgeProviding
    private let limits: SuggestionPromptLimits

    public init(
        knowledgeProvider: any RuleKnowledgeProviding,
        limits: SuggestionPromptLimits = .default
    ) {
        self.knowledgeProvider = knowledgeProvider
        self.limits = limits
    }

    public func build(
        finding: Finding,
        sourceContext: SourceContextWindow
    ) throws -> SuggestionPrompt {
        guard limits.maximumSourceUTF8Bytes > 0,
              limits.maximumPromptUTF8Bytes > 0 else {
            throw SuggestionPromptBuildingError.invalidLimits
        }

        let sourceByteCount = sourceContext.sourceText.utf8.count
        guard sourceByteCount <= limits.maximumSourceUTF8Bytes else {
            throw SuggestionPromptBuildingError.sourceExcerptTooLarge(
                actualBytes: sourceByteCount,
                maximumBytes: limits.maximumSourceUTF8Bytes
            )
        }

        guard let knowledge = knowledgeProvider.knowledge(
            for: finding.ruleID
        ) else {
            throw SuggestionPromptBuildingError.unknownRuleID(finding.ruleID)
        }

        let payload = SuggestionPromptInput(
            finding: makeFindingInput(from: finding),
            rule: knowledge,
            sourceContext: makeSourceInput(from: sourceContext)
        )
        let inputJSON = try encode(payload)
        let promptText = SuggestionPromptTemplateV1.render(
            inputJSON: inputJSON
        )
        let promptByteCount = promptText.utf8.count

        guard promptByteCount <= limits.maximumPromptUTF8Bytes else {
            throw SuggestionPromptBuildingError.promptTooLarge(
                actualBytes: promptByteCount,
                maximumBytes: limits.maximumPromptUTF8Bytes
            )
        }

        return SuggestionPrompt(
            templateID: SuggestionPromptTemplateV1.id,
            templateVersion: SuggestionPromptTemplateV1.version,
            text: promptText
        )
    }

    private func makeFindingInput(
        from finding: Finding
    ) -> SuggestionFindingInput {
        SuggestionFindingInput(
            ruleID: finding.ruleID,
            title: redactCommonSecrets(in: finding.title),
            category: finding.category,
            severity: finding.severity,
            filePath: promptFilePath(from: finding.filePath),
            range: finding.range,
            explanation: redactCommonSecrets(in: finding.explanation),
            evidence: finding.evidence
                .map { evidence in
                    Evidence(
                        metric: redactCommonSecrets(in: evidence.metric),
                        observedValue: evidence.observedValue,
                        thresholdValue: evidence.thresholdValue
                    )
                }
                .sorted(by: evidencePrecedes)
        )
    }

    private func makeSourceInput(
        from context: SourceContextWindow
    ) -> SuggestionSourceInput {
        SuggestionSourceInput(
            changedLineRange: context.changedLineRange,
            includedLineRange: context.includedLineRange,
            sourceText: redactCommonSecrets(in: context.sourceText)
        )
    }

    private func evidencePrecedes(_ left: Evidence, _ right: Evidence) -> Bool {
        if left.metric != right.metric {
            return left.metric < right.metric
        }
        if left.observedValue != right.observedValue {
            return left.observedValue < right.observedValue
        }
        return left.thresholdValue < right.thresholdValue
    }

    private func promptFilePath(from path: String) -> String {
        let safePath: String

        if path.hasPrefix("/") {
            safePath = URL(fileURLWithPath: path).lastPathComponent
        } else {
            safePath = path
        }

        return redactCommonSecrets(in: safePath)
    }

    private func encode(_ input: SuggestionPromptInput) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]

        do {
            let data = try encoder.encode(input)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw SuggestionPromptBuildingError.inputEncodingFailed
        }
    }

    private func redactCommonSecrets(in text: String) -> String {
        let replacements = [
            SecretReplacement(
                pattern: #"(?i)(\b(?:let|var)\s+(?:(?:password|passwd|token|api_?key|secret|access_?key)|[A-Za-z_][A-Za-z0-9_]*(?:password|passwd|token|api_?key|secret|access_?key)[A-Za-z0-9_]*)\s*(?::[^=\n]+)?=\s*)\"(?:\\.|[^\"\\])*\""#,
                template: #"$1\"[REDACTED]\""#
            ),
            SecretReplacement(
                pattern: #"(?i)(\bBearer\s+)[A-Za-z0-9._~+/=-]{8,}"#,
                template: "$1[REDACTED]"
            ),
            SecretReplacement(
                pattern: #"\b(?:sk-[A-Za-z0-9_-]{8,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b"#,
                template: "[REDACTED]"
            ),
            SecretReplacement(
                pattern: #"-----BEGIN(?: [A-Z0-9]+)? PRIVATE KEY-----[\s\S]*?-----END(?: [A-Z0-9]+)? PRIVATE KEY-----"#,
                template: "[REDACTED PRIVATE KEY]"
            )
        ]

        return replacements.reduce(text) { redactedText, replacement in
            replacement.apply(to: redactedText)
        }
    }
}

private struct SuggestionPromptInput: Encodable {
    let finding: SuggestionFindingInput
    let rule: RuleKnowledge
    let sourceContext: SuggestionSourceInput
}

private struct SuggestionFindingInput: Encodable {
    let ruleID: String
    let title: String
    let category: FindingCategory
    let severity: Severity
    let filePath: String
    let range: SourceRange?
    let explanation: String
    let evidence: [Evidence]
}

private struct SuggestionSourceInput: Encodable {
    let changedLineRange: ChangedLineRange
    let includedLineRange: SourceLineRange
    let sourceText: String
}

private struct SecretReplacement {
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
