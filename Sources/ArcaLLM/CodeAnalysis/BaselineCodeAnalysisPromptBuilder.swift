import ArcaDomain
import ArcaKnowledge
import Foundation

public struct BaselineCodeAnalysisPromptBuilder: Sendable {
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

        let payload = BaselineCodeAnalysisPromptInput(
            file: BaselineCodeAnalysisFileInput(
                path: context.filePath,
                lineCount: context.lineCount,
                lines: sourceLines.enumerated().map { index, text in
                    BaselineCodeAnalysisSourceLineInput(
                        lineNumber: index + 1,
                        text: PromptTextRedactor.redactCommonSecrets(
                            in: text
                        )
                    )
                }
            ),
            change: context.change
        )
        let inputJSON = try encode(payload)
        let selectedTasks = sortedRules.map {
            "- \($0.ruleID): \($0.title)"
        }.joined(separator: "\n")
        let promptText = BaselineCodeAnalysisPromptTemplateV1.render(
            inputJSON: inputJSON,
            selectedTasks: selectedTasks
        )
        let promptByteCount = promptText.utf8.count
        guard promptByteCount <= limits.maximumPromptUTF8Bytes else {
            throw CodeAnalysisPromptBuildingError.promptTooLarge(
                actualBytes: promptByteCount,
                maximumBytes: limits.maximumPromptUTF8Bytes
            )
        }

        return CodeAnalysisPrompt(
            templateID: BaselineCodeAnalysisPromptTemplateV1.id,
            templateVersion: BaselineCodeAnalysisPromptTemplateV1.version,
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

    private func encode(
        _ input: BaselineCodeAnalysisPromptInput
    ) throws -> String {
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

private struct BaselineCodeAnalysisPromptInput: Encodable {
    let file: BaselineCodeAnalysisFileInput
    let change: SourceFileChangeContext?
}

private struct BaselineCodeAnalysisFileInput: Encodable {
    let path: String
    let lineCount: Int
    let lines: [BaselineCodeAnalysisSourceLineInput]
}

private struct BaselineCodeAnalysisSourceLineInput: Encodable {
    let lineNumber: Int
    let text: String
}
