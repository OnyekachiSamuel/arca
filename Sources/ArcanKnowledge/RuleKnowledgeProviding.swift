public protocol RuleKnowledgeProviding: Sendable {
    func knowledge(for ruleID: String) -> RuleKnowledge?
}
