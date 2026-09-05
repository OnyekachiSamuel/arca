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

  @Test("each review selects only rules with its review type")
  func selectsRulesByReviewType() {
    let selector = ReviewRuleSelector()
    let provider = StubRuleKnowledgeProvider()

    #expect(
      selector.rules(for: [.tca], from: provider)
        .map(\.ruleID) == ["ARCA-TCA-001"]
    )
    #expect(
      selector.rules(for: [.swift], from: provider)
        .map(\.ruleID) == [
          "ARCA-LONG-METHOD-001",
          "ARCA-SWIFT-001",
        ]
    )
    #expect(
      selector.rules(for: [.security], from: provider)
        .map(\.ruleID) == ["ARCA-SECURITY-001"]
    )
  }

  @Test("multiple reviews return a stable union without duplicate rules")
  func selectsStableRuleUnion() {
    let rules = ReviewRuleSelector().rules(
      for: [.security, .godObject, .swift],
      from: StubRuleKnowledgeProvider()
    )

    #expect(
      rules.map(\.ruleID) == [
        "ARCA-GOD-001",
        "ARCA-LONG-METHOD-001",
        "ARCA-SECURITY-001",
        "ARCA-SWIFT-001",
      ]
    )
  }
}

private struct StubRuleKnowledgeProvider: RuleKnowledgeProviding {
  let allKnowledge: [RuleKnowledge] = [
    makeRule(
      id: "ARCA-LONG-METHOD-001",
      reviewType: .swift
    ),
    makeRule(
      id: "ARCA-GOD-001",
      reviewType: .godObject
    ),
    makeRule(
      id: "ARCA-TCA-001",
      reviewType: .tca
    ),
    makeRule(
      id: "ARCA-SWIFT-001",
      reviewType: .swift
    ),
    makeRule(
      id: "ARCA-SECURITY-001",
      reviewType: .security
    ),
  ]

  func knowledge(for ruleID: String) -> RuleKnowledge? {
    allKnowledge.first { $0.ruleID == ruleID }
  }

}

private func makeRule(
  id: String,
  reviewType: ReviewType
) -> RuleKnowledge {
  RuleKnowledge(
    ruleID: id,
    reviewType: reviewType,
    category: "architecture",
    issueType: .antiPattern,
    title: id,
    problemContext: "Problem context",
    expectedBehavior: "Expected behavior",
    violationCriteria: "Violation criteria",
    knowledgeFile: "references/\(id).md",
    supportingKnowledge: "# Supporting knowledge"
  )
}
