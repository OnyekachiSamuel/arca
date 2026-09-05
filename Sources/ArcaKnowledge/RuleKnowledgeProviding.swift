import ArcaDomain

public protocol RuleKnowledgeProviding: Sendable {
  var allKnowledge: [RuleKnowledge] { get }

  func knowledge(for ruleID: String) -> RuleKnowledge?
  func knowledge(for reviewType: ReviewType) -> [RuleKnowledge]
}

extension RuleKnowledgeProviding {
  public func knowledge(for reviewType: ReviewType) -> [RuleKnowledge] {
    allKnowledge.filter { $0.reviewType == reviewType }
  }
}
