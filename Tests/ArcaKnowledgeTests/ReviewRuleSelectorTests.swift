import ArcaDomain
import ArcaKnowledge
import Testing

@Suite("Review rule selector")
struct ReviewRuleSelectorTests {
    @Test("God Object review selects only the God Object rule")
    func selectsOnlyGodObjectRule() {
        let rules = ReviewRuleSelector().rules(
            for: [.godObject],
            from: StubRuleKnowledgeProvider()
        )

        #expect(rules.map(\.ruleID) == ["ARCA-GOD-001"])
    }

    @Test("domain reviews select rules from their matching groups")
    func selectsRulesByDomainGroup() {
        let selector = ReviewRuleSelector()
        let provider = StubRuleKnowledgeProvider()

        #expect(
            selector.rules(for: [.tcaArchitecture], from: provider)
                .map(\.ruleID) == ["ARCA-TCA-001"]
        )
        #expect(
            selector.rules(for: [.style], from: provider)
                .map(\.ruleID) == ["ARCA-STYLE-001"]
        )
        #expect(
            selector.rules(for: [.teamConvention], from: provider)
                .map(\.ruleID) == ["ARCA-TEAM-001"]
        )
    }

    @Test("multiple reviews return a stable union without duplicate rules")
    func selectsStableRuleUnion() {
        let rules = ReviewRuleSelector().rules(
            for: [.teamConvention, .godObject, .style],
            from: StubRuleKnowledgeProvider()
        )

        #expect(
            rules.map(\.ruleID) == [
                "ARCA-GOD-001",
                "ARCA-STYLE-001",
                "ARCA-TEAM-001"
            ]
        )
    }
}

private struct StubRuleKnowledgeProvider: RuleKnowledgeProviding {
    let allKnowledge: [RuleKnowledge] = [
        makeRule(
            id: "ARCA-LONG-METHOD-001",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern
        ),
        makeRule(
            id: "ARCA-GOD-001",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern
        ),
        makeRule(
            id: "ARCA-TCA-001",
            group: .tcaArchitecture,
            category: .architecture
        ),
        makeRule(
            id: "ARCA-STYLE-001",
            group: .style,
            category: .style
        ),
        makeRule(
            id: "ARCA-TEAM-001",
            group: .teamConventions,
            category: .teamConvention
        )
    ]

    func knowledge(for ruleID: String) -> RuleKnowledge? {
        allKnowledge.first { $0.ruleID == ruleID }
    }

    func knowledge(in group: RuleKnowledgeGroup) -> [RuleKnowledge] {
        allKnowledge.filter { $0.group == group }
    }
}

private func makeRule(
    id: String,
    group: RuleKnowledgeGroup,
    category: FindingCategory
) -> RuleKnowledge {
    RuleKnowledge(
        ruleID: id,
        title: id,
        group: group,
        category: category,
        defaultSeverity: .warning,
        definition: "Definition",
        evidenceCriteria: ["Evidence"],
        classificationGuidance: ["Guidance"],
        severityGuidance: ["Severity"],
        refactoringGuardrails: ["Guardrail"]
    )
}
