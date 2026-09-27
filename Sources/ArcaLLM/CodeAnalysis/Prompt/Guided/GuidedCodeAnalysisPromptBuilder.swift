import ArcaDomain
import ArcaKnowledge
import Foundation

public struct GuidedCodeAnalysisPromptBuilder: Sendable {
  private let limits: CodeAnalysisPromptLimits

  public init(limits: CodeAnalysisPromptLimits = .default) {
    self.limits = limits
  }

  public func build(
    context: SourceFileAnalysisContext,
    rules: [RuleKnowledge]
  ) throws -> String {
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

    let payload = GuidedCodeAnalysisPromptInput(
      file: GuidedCodeAnalysisFileInput(
        path: context.filePath,
        lineCount: context.lineCount,
        lines: sourceLines.enumerated().map { index, text in
          GuidedCodeAnalysisSourceLineInput(
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
    let promptText = GuidedCodeAnalysisPromptTemplateV1.render(
      rulesAndKnowledge: sortedRules.map(renderRule).joined(
        separator: "\n\n"
      ),
      sourceInputJSON: inputJSON
    )
    let promptByteCount = promptText.utf8.count
    guard promptByteCount <= limits.maximumPromptUTF8Bytes else {
      throw CodeAnalysisPromptBuildingError.promptTooLarge(
        actualBytes: promptByteCount,
        maximumBytes: limits.maximumPromptUTF8Bytes
      )
    }

    return promptText
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

  private func renderRule(_ knowledge: RuleKnowledge) -> String {
    return """
      <RULE>
      <RULE_DEFINITION>
      Rule ID: \(knowledge.ruleID)
      Review type: \(knowledge.reviewType.commandLineName)
      Category: \(knowledge.category)
      Issue type: \(knowledge.issueType.rawValue)
      Title: \(knowledge.title)

      Problem context:
      \(knowledge.problemContext)

      Expected behavior:
      \(knowledge.expectedBehavior)

      Violation criteria:
      \(knowledge.violationCriteria)
      </RULE_DEFINITION>

      <SUPPORTING_KNOWLEDGE file="\(knowledge.knowledgeFile)">
      \(knowledge.supportingKnowledge)
      </SUPPORTING_KNOWLEDGE>
      </RULE>
      """
  }

  private func encode(
    _ input: GuidedCodeAnalysisPromptInput
  ) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [
      .prettyPrinted,
      .sortedKeys,
      .withoutEscapingSlashes,
    ]
    do {
      let data = try encoder.encode(input)
      return String(decoding: data, as: UTF8.self)
    } catch {
      throw CodeAnalysisPromptBuildingError.inputEncodingFailed
    }
  }
}

private struct GuidedCodeAnalysisPromptInput: Encodable {
  let file: GuidedCodeAnalysisFileInput
  let change: SourceFileChangeContext?
}

private struct GuidedCodeAnalysisFileInput: Encodable {
  let path: String
  let lineCount: Int
  let lines: [GuidedCodeAnalysisSourceLineInput]
}

private struct GuidedCodeAnalysisSourceLineInput: Encodable {
  let lineNumber: Int
  let text: String
}
