import ArcaDomain

public struct ReviewRuleSelector: Sendable {
  public init() {}

  public func rules(
    for reviewTypes: Set<ReviewType>,
    from knowledgeProvider: any RuleKnowledgeProviding
  ) -> [RuleKnowledge] {
    knowledgeProvider.allKnowledge
      .filter { reviewTypes.contains($0.reviewType) }
      .sorted { $0.ruleID < $1.ruleID }
  }
}
