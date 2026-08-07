import ArcaDomain
import ArcaKnowledge
import Foundation

public struct CodeAnalysisPromptBuilder: Sendable {
    private let limits: CodeAnalysisPromptLimits

    public init(limits: CodeAnalysisPromptLimits = .default) {
        self.limits = limits
    }

    public func build(
        context: SourceFileAnalysisContext,
        rules: [RuleKnowledge]
    ) throws -> CodeAnalysisPrompt {
        guard limits.maximumPromptUTF8Bytes > 0 else {
            throw CodeAnalysisPromptBuildingError.invalidLimits
        }
        guard !rules.isEmpty else {
            throw CodeAnalysisPromptBuildingError.noApplicableRules
        }

        let sortedRules = try validatedRules(rules)
        let sourceLines = SourceTextLineExtractor.lines(
            in: context.sourceContent
        )

        guard sourceLines.count == context.lineCount else {
            throw CodeAnalysisPromptBuildingError.sourceLineCountMismatch(
                expected: context.lineCount,
                actual: sourceLines.count
            )
        }

        let payload = CodeAnalysisPromptInput(
            file: CodeAnalysisFileInput(
                path: context.filePath,
                lineCount: context.lineCount,
                lines: sourceLines.enumerated().map { index, text in
                    CodeAnalysisSourceLineInput(
                        lineNumber: index + 1,
                        text: PromptTextRedactor.redactCommonSecrets(
                            in: text
                        )
                    )
                }
            ),
            change: context.change,
            rules: sortedRules.map(makeRuleInput)
        )
        let inputJSON = try encode(payload)
        let promptText = CodeAnalysisPromptTemplateV1.render(
            inputJSON: inputJSON
        )
        let promptByteCount = promptText.utf8.count

        guard promptByteCount <= limits.maximumPromptUTF8Bytes else {
            throw CodeAnalysisPromptBuildingError.promptTooLarge(
                actualBytes: promptByteCount,
                maximumBytes: limits.maximumPromptUTF8Bytes
            )
        }

        return CodeAnalysisPrompt(
            templateID: CodeAnalysisPromptTemplateV1.id,
            templateVersion: CodeAnalysisPromptTemplateV1.version,
            text: promptText
        )
    }

    private func validatedRules(
        _ rules: [RuleKnowledge]
    ) throws -> [RuleKnowledge] {
        var encounteredRuleIDs: Set<String> = []

        for rule in rules {
            guard encounteredRuleIDs.insert(rule.ruleID).inserted else {
                throw CodeAnalysisPromptBuildingError.duplicateRuleID(
                    rule.ruleID
                )
            }
        }

        return rules.sorted { $0.ruleID < $1.ruleID }
    }

    private func makeRuleInput(
        from knowledge: RuleKnowledge
    ) -> CodeAnalysisRuleInput {
        CodeAnalysisRuleInput(
            ruleID: knowledge.ruleID,
            title: knowledge.title,
            group: knowledge.group,
            category: knowledge.category,
            defaultSeverity: knowledge.defaultSeverity,
            definition: knowledge.definition,
            evidenceCriteria: knowledge.evidenceCriteria,
            classificationGuidance: knowledge.classificationGuidance,
            severityGuidance: knowledge.severityGuidance
        )
    }

    private func encode(_ input: CodeAnalysisPromptInput) throws -> String {
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
            throw CodeAnalysisPromptBuildingError.inputEncodingFailed
        }
    }
}

private struct CodeAnalysisPromptInput: Encodable {
    let file: CodeAnalysisFileInput
    let change: SourceFileChangeContext?
    let rules: [CodeAnalysisRuleInput]
}

private struct CodeAnalysisFileInput: Encodable {
    let path: String
    let lineCount: Int
    let lines: [CodeAnalysisSourceLineInput]
}

private struct CodeAnalysisSourceLineInput: Encodable {
    let lineNumber: Int
    let text: String
}

private struct CodeAnalysisRuleInput: Encodable {
    let ruleID: String
    let title: String
    let group: RuleKnowledgeGroup
    let category: FindingCategory
    let defaultSeverity: Severity
    let definition: String
    let evidenceCriteria: [String]
    let classificationGuidance: [String]
    let severityGuidance: [String]
}
