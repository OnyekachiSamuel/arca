import ArcaDomain
import Foundation

public struct RuleKnowledgeRegistry: Sendable {
  public static let currentSchemaVersion = 1

  public let allKnowledge: [RuleKnowledge]

  public init(rulesetURL: URL) throws {
    let rulesetURL = rulesetURL.standardizedFileURL
    let baseURL = rulesetURL.deletingLastPathComponent()
    let data: Data
    do {
      data = try Data(contentsOf: rulesetURL)
    } catch {
      throw RuleKnowledgeRegistryError.unreadableRuleset(
        rulesetURL.path
      )
    }

    try self.init(data: data) { knowledgeFile in
      let knowledgeURL =
        baseURL
        .appendingPathComponent(knowledgeFile)
        .standardizedFileURL
      guard knowledgeURL.path.hasPrefix(baseURL.path + "/") else {
        throw RuleKnowledgeRegistryError.invalidKnowledgePath(
          knowledgeFile
        )
      }
      return try Self.readKnowledge(
        at: knowledgeURL,
        declaredPath: knowledgeFile
      )
    }
  }

  public static func bundled() throws -> RuleKnowledgeRegistry {
    guard
      let rulesetURL = Bundle.module.url(
        forResource: "arca-rulesets",
        withExtension: "json"
      )
    else {
      throw RuleKnowledgeRegistryError.bundledResourceNotFound
    }
    let data: Data
    do {
      data = try Data(contentsOf: rulesetURL)
    } catch {
      throw RuleKnowledgeRegistryError.unreadableRuleset(
        rulesetURL.path
      )
    }

    return try RuleKnowledgeRegistry(data: data) { knowledgeFile in
      let components = knowledgeFile.split(separator: "/")
      guard components.count == 2,
        components.first == "references",
        !knowledgeFile.hasPrefix("/")
      else {
        throw RuleKnowledgeRegistryError.invalidKnowledgePath(
          knowledgeFile
        )
      }
      let fileURL = URL(fileURLWithPath: knowledgeFile)
      guard
        let knowledgeURL = Bundle.module.url(
          forResource: fileURL.deletingPathExtension().lastPathComponent,
          withExtension: fileURL.pathExtension
        )
      else {
        throw RuleKnowledgeRegistryError.missingKnowledgeFile(
          knowledgeFile
        )
      }
      return try readKnowledge(
        at: knowledgeURL,
        declaredPath: knowledgeFile
      )
    }
  }

  public func knowledge(for reviewType: ReviewType) -> [RuleKnowledge] {
    allKnowledge.filter { $0.reviewType == reviewType }
  }

  private init(
    data: Data,
    knowledgeLoader: (String) throws -> String
  ) throws {
    let document: RuleKnowledgeDocument
    do {
      document = try JSONDecoder().decode(
        RuleKnowledgeDocument.self,
        from: data
      )
    } catch {
      throw RuleKnowledgeRegistryError.invalidJSON
    }
    guard document.schemaVersion == Self.currentSchemaVersion else {
      throw RuleKnowledgeRegistryError.unsupportedSchemaVersion(
        document.schemaVersion
      )
    }
    guard !document.rules.isEmpty else {
      throw RuleKnowledgeRegistryError.emptyRegistry
    }

    var encounteredRuleIDs: Set<String> = []
    var loaded: [RuleKnowledge] = []
    for definition in document.rules {
      try Self.validate(definition)
      guard encounteredRuleIDs.insert(definition.ruleID).inserted else {
        throw RuleKnowledgeRegistryError.duplicateRuleID(
          definition.ruleID
        )
      }
      let markdown = try knowledgeLoader(definition.knowledgeFile)
      guard
        !markdown.trimmingCharacters(
          in: .whitespacesAndNewlines
        ).isEmpty
      else {
        throw RuleKnowledgeRegistryError.emptyKnowledgeFile(
          definition.knowledgeFile
        )
      }
      let knowledge = RuleKnowledge(
        ruleID: definition.ruleID,
        reviewType: definition.reviewType,
        category: definition.category,
        issueType: definition.issueType,
        title: definition.title,
        problemContext: definition.problemContext,
        expectedBehavior: definition.expectedBehavior,
        violationCriteria: definition.violationCriteria,
        knowledgeFile: definition.knowledgeFile,
        supportingKnowledge: markdown,
        deprecatedFromVersion: definition.deprecatedFromVersion
      )
      loaded.append(knowledge)
    }
    allKnowledge = loaded
  }

  private static func readKnowledge(
    at url: URL,
    declaredPath: String
  ) throws -> String {
    do {
      return try String(contentsOf: url, encoding: .utf8)
    } catch {
      throw RuleKnowledgeRegistryError.missingKnowledgeFile(
        declaredPath
      )
    }
  }

  private static func validate(_ rule: RuleDefinition) throws {
    let requiredValues = [
      ("rule ID", rule.ruleID),
      ("category", rule.category),
      ("title", rule.title),
      ("problem context", rule.problemContext),
      ("expected behavior", rule.expectedBehavior),
      ("violation criteria", rule.violationCriteria),
      ("knowledge file", rule.knowledgeFile),
    ]
    for (field, value) in requiredValues where value.trimmed.isEmpty {
      throw RuleKnowledgeRegistryError.invalidRule(
        ruleID: rule.ruleID,
        reason: "\(field) must not be empty."
      )
    }
    guard rule.ruleID == rule.ruleID.trimmed else {
      throw RuleKnowledgeRegistryError.invalidRule(
        ruleID: rule.ruleID,
        reason: "rule ID must not contain surrounding whitespace."
      )
    }
    if rule.issueType == .deprecatedAPI,
      rule.deprecatedFromVersion?.trimmed.isEmpty != false
    {
      throw RuleKnowledgeRegistryError.invalidRule(
        ruleID: rule.ruleID,
        reason: "deprecated API rules require deprecatedFromVersion."
      )
    }
  }
}

private struct RuleKnowledgeDocument: Decodable {
  let schemaVersion: Int
  let rules: [RuleDefinition]
}

private struct RuleDefinition: Decodable {
  let ruleID: String
  let reviewType: ReviewType
  let category: String
  let issueType: IssueType
  let title: String
  let problemContext: String
  let expectedBehavior: String
  let violationCriteria: String
  let knowledgeFile: String
  let deprecatedFromVersion: String?
}

extension String {
  fileprivate var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
