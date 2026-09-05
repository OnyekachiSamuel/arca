import Foundation

public enum RuleKnowledgeRegistryError: Error, Equatable, LocalizedError {
  case bundledResourceNotFound
  case unreadableRuleset(String)
  case missingKnowledgeFile(String)
  case emptyKnowledgeFile(String)
  case invalidKnowledgePath(String)
  case invalidJSON
  case unsupportedSchemaVersion(Int)
  case emptyRegistry
  case duplicateRuleID(String)
  case invalidRule(ruleID: String, reason: String)

  public var errorDescription: String? {
    switch self {
    case .bundledResourceNotFound:
      "The bundled rule knowledge resource could not be found."
    case .unreadableRuleset(let path):
      "The rule set at '\(path)' could not be read."
    case .missingKnowledgeFile(let path):
      "The supporting knowledge file '\(path)' could not be read."
    case .emptyKnowledgeFile(let path):
      "The supporting knowledge file '\(path)' must not be empty."
    case .invalidKnowledgePath(let path):
      "The supporting knowledge path '\(path)' is not allowed."
    case .invalidJSON:
      "The rule knowledge resource is not valid JSON."
    case .unsupportedSchemaVersion(let version):
      "Rule knowledge schema version \(version) is not supported."
    case .emptyRegistry:
      "The rule knowledge registry must contain at least one rule."
    case .duplicateRuleID(let ruleID):
      "The rule knowledge registry contains duplicate rule ID '\(ruleID)'."
    case .invalidRule(let ruleID, let reason):
      "Rule knowledge for '\(ruleID)' is invalid: \(reason)"
    }
  }
}
