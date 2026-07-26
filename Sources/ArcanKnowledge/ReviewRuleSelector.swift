import ArcanDomain

public struct ReviewRuleSelector: Sendable {
    public init() {}

    public func rules(
        for reviewTypes: Set<ReviewType>,
        from knowledgeProvider: any RuleKnowledgeProviding
    ) -> [RuleKnowledge] {
        var rulesByID: [String: RuleKnowledge] = [:]

        for reviewType in reviewTypes {
            for rule in rules(
                for: reviewType,
                from: knowledgeProvider
            ) {
                rulesByID[rule.ruleID] = rule
            }
        }

        return rulesByID.values.sorted { $0.ruleID < $1.ruleID }
    }

    private func rules(
        for reviewType: ReviewType,
        from knowledgeProvider: any RuleKnowledgeProviding
    ) -> [RuleKnowledge] {
        switch reviewType {
        case .godObject:
            knowledgeProvider.knowledge(for: "ARCAN-GOD-001").map { [$0] }
                ?? []
        case .tcaArchitecture:
            knowledgeProvider.knowledge(in: .tcaArchitecture)
        case .style:
            knowledgeProvider.knowledge(in: .style)
        case .teamConvention:
            knowledgeProvider.knowledge(in: .teamConventions)
        }
    }
}
