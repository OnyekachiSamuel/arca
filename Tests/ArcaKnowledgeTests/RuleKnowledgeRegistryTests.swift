import ArcaDomain
import ArcaKnowledge
import Foundation
import Testing

@Suite("Rule knowledge registry")
struct RuleKnowledgeRegistryTests {
  @Test("loads all bundled rule definitions and Markdown knowledge")
  func loadsBundledRules() throws {
    let registry = try RuleKnowledgeRegistry.bundled()

    #expect(registry.allKnowledge.count == 28)
    let rule = try #require(
      registry.knowledge(for: "ARCA-SWIFT-CONCURRENCY-001")
    )
    #expect(rule.reviewType == .swift)
    #expect(rule.category == "concurrency")
    #expect(rule.issueType == .unsafeCode)
    #expect(rule.problemContext.contains("Swift concurrency"))
    #expect(rule.supportingKnowledge.hasPrefix("# Improper Isolation"))
    #expect(rule.supportingKnowledge.contains("```swift"))
  }

  @Test("loads a project ruleset and resolves knowledge relative to it")
  func loadsProjectRuleset() throws {
    let fixture = try RulesetFixture()
    let markdown = "# Team rule\n\n```swift\nlet value = 1\n```\n"
    try markdown.write(
      to: fixture.referencesURL.appendingPathComponent("RULE-001.md"),
      atomically: true,
      encoding: .utf8
    )
    try fixture.writeRules([fixture.rule()])

    let registry = try RuleKnowledgeRegistry(
      rulesetURL: fixture.rulesetURL
    )

    #expect(registry.allKnowledge.count == 1)
    #expect(registry.allKnowledge[0].supportingKnowledge == markdown)
  }

  @Test("rejects missing knowledge files")
  func rejectsMissingKnowledgeFile() throws {
    let fixture = try RulesetFixture()
    try fixture.writeRules([fixture.rule()])

    #expect(throws: RuleKnowledgeRegistryError.self) {
      try RuleKnowledgeRegistry(rulesetURL: fixture.rulesetURL)
    }
  }

  @Test("rejects duplicate rule identifiers")
  func rejectsDuplicateRuleIDs() throws {
    let fixture = try RulesetFixture()
    try "# Knowledge".write(
      to: fixture.referencesURL.appendingPathComponent("RULE-001.md"),
      atomically: true,
      encoding: .utf8
    )
    let rule = fixture.rule()
    try fixture.writeRules([rule, rule])

    #expect(throws: RuleKnowledgeRegistryError.duplicateRuleID("RULE-001")) {
      try RuleKnowledgeRegistry(rulesetURL: fixture.rulesetURL)
    }
  }

  @Test("uses schema version one without legacy decoding")
  func usesSchemaVersionOne() throws {
    let fixture = try RulesetFixture()
    try fixture.writeRules([], schemaVersion: 2)

    #expect(throws: RuleKnowledgeRegistryError.unsupportedSchemaVersion(2)) {
      try RuleKnowledgeRegistry(rulesetURL: fixture.rulesetURL)
    }
  }
}

private struct RulesetFixture {
  let directoryURL: URL
  let referencesURL: URL
  let rulesetURL: URL

  init() throws {
    directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    referencesURL = directoryURL.appendingPathComponent("references", isDirectory: true)
    rulesetURL = directoryURL.appendingPathComponent("rules.json")
    try FileManager.default.createDirectory(
      at: referencesURL,
      withIntermediateDirectories: true
    )
  }

  func writeRules(
    _ rules: [[String: Any]],
    schemaVersion: Int = 1
  ) throws {
    let data = try JSONSerialization.data(
      withJSONObject: ["schemaVersion": schemaVersion, "rules": rules],
      options: [.prettyPrinted, .sortedKeys]
    )
    try data.write(to: rulesetURL)
  }

  func rule() -> [String: Any] {
    [
      "ruleID": "RULE-001",
      "reviewType": "swift",
      "category": "concurrency",
      "issueType": "unsafe-code",
      "title": "Unsafe state",
      "problemContext": "State is shared.",
      "expectedBehavior": "State is isolated.",
      "violationCriteria": "Shared state is not isolated.",
      "knowledgeFile": "references/RULE-001.md",
    ]
  }
}
