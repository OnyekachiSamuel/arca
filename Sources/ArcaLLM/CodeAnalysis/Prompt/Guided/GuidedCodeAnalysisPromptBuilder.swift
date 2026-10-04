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
        
        let sourceInput = CodeAnalysisSourceInputRenderer().render(
            context: context,
            sourceLines: sourceLines
        )
        let promptText = GuidedCodeAnalysisPromptTemplateV1.render(
            rulesAndKnowledge: sortedRules.map(renderRule).joined(
                separator: "\n\n"
            ),
            sourceInput: sourceInput
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
    
}
