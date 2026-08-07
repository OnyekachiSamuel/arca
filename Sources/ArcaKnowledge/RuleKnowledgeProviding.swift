public protocol RuleKnowledgeProviding: Sendable {
    var allKnowledge: [RuleKnowledge] { get }

    func knowledge(for ruleID: String) -> RuleKnowledge?
    func knowledge(in group: RuleKnowledgeGroup) -> [RuleKnowledge]
}
