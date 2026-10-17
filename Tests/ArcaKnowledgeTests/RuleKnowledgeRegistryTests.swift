import ArcaDomain
import ArcaKnowledge
import Foundation
import Testing

@Suite("Rule knowledge registry")
struct RuleKnowledgeRegistryTests {
  @Test("loads all bundled rule definitions and Markdown knowledge")
  func loadsBundledRules() throws {
    let registry = try RuleKnowledgeRegistry.bundled()

    #expect(registry.allKnowledge.count == 36)

    let concurrencyRules = registry.allKnowledge.filter {
      $0.reviewType == .swift && $0.category == "concurrency"
    }
    #expect(concurrencyRules.count == 13)
    #expect(
      concurrencyRules.map(\.ruleID).sorted()
        == (1...13).map {
          String(format: "ARCA-SWIFT-CONCURRENCY-%03d", $0)
        }
    )

    let expectedKnowledgeMarkers = [
      "ARCA-SWIFT-CONCURRENCY-001": "actor Counter",
      "ARCA-SWIFT-CONCURRENCY-002": "searchTask?.cancel()",
      "ARCA-SWIFT-CONCURRENCY-003": "Forgot lock - data race!",
      "ARCA-SWIFT-CONCURRENCY-004": "static var shared = ImageCache()",
      "ARCA-SWIFT-CONCURRENCY-005": "Actor unlocked during await",
      "ARCA-SWIFT-CONCURRENCY-006": "article no longer accessible here",
      "ARCA-SWIFT-CONCURRENCY-007": "DirectoryCleaner.cleanup()",
      "ARCA-SWIFT-CONCURRENCY-008": "while !Task.isCancelled",
      "ARCA-SWIFT-CONCURRENCY-009": "for try await image in group",
      "ARCA-SWIFT-CONCURRENCY-010": "Task.sleep(for: .seconds(5))",
      "ARCA-SWIFT-CONCURRENCY-011": "Loader never deallocated",
      "ARCA-SWIFT-CONCURRENCY-012": "Stream never ends!",
      "ARCA-SWIFT-CONCURRENCY-013": "Consumer 1",
    ]
    for (ruleID, marker) in expectedKnowledgeMarkers {
      let rule = try #require(
        concurrencyRules.first { $0.ruleID == ruleID }
      )
      #expect(rule.supportingKnowledge.contains(marker))
    }

    let sharedInstanceStateRule = try #require(
      concurrencyRules.first {
        $0.ruleID == "ARCA-SWIFT-CONCURRENCY-001"
      }
    )
    #expect(
      sharedInstanceStateRule.violationCriteria.contains(
        "reachable through a visible global or static shared instance"
      )
    )

    let globalStateRule = try #require(
      concurrencyRules.first {
        $0.ruleID == "ARCA-SWIFT-CONCURRENCY-004"
      }
    )
    #expect(
      globalStateRule.violationCriteria.contains(
        "A shared reference to mutable instance state belongs to ARCA-SWIFT-CONCURRENCY-001"
      )
    )

    let replaceableTaskRule = try #require(
      concurrencyRules.first {
        $0.ruleID == "ARCA-SWIFT-CONCURRENCY-002"
      }
    )
    #expect(
      replaceableTaskRule.violationCriteria.contains(
        "Do not infer repeated invocation from callers outside the file"
      )
    )

    let unsafeEscapeRule = try #require(
      concurrencyRules.first {
        $0.ruleID == "ARCA-SWIFT-CONCURRENCY-003"
      }
    )
    #expect(unsafeEscapeRule.violationCriteria.contains("annotation alone is insufficient"))

    let transferRule = try #require(
      concurrencyRules.first {
        $0.ruleID == "ARCA-SWIFT-CONCURRENCY-006"
      }
    )
    #expect(transferRule.violationCriteria.contains("declaration outside the file"))

    let streamLifecycleRule = try #require(
      concurrencyRules.first {
        $0.ruleID == "ARCA-SWIFT-CONCURRENCY-012"
      }
    )
    #expect(streamLifecycleRule.violationCriteria.contains("cleanup responsibility is visible"))

    let streamConsumerRule = try #require(
      concurrencyRules.first {
        $0.ruleID == "ARCA-SWIFT-CONCURRENCY-013"
      }
    )
    #expect(streamConsumerRule.violationCriteria.contains("Multiple consumers alone are insufficient"))

    let closureCycleRule = try #require(
      registry.allKnowledge.first {
        $0.ruleID == "ARCA-SWIFT-MEMORY-001"
      }
    )
    #expect(
      closureCycleRule.violationCriteria.contains(
        "Stored Task ownership cycles belong to ARCA-SWIFT-CONCURRENCY-011"
      )
    )
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

  @Test("requires ruleset schema version one")
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
      "title": "Unsafe state",
      "problemContext": "State is shared.",
      "expectedBehavior": "State is isolated.",
      "violationCriteria": "Shared state is not isolated.",
      "knowledgeFile": "references/RULE-001.md",
    ]
  }
}
