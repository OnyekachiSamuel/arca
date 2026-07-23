import Foundation

public enum RuleKnowledgeRegistryError: Error, Equatable, LocalizedError {
    case bundledResourceNotFound
    case unreadableResource
    case invalidJSON
    case unsupportedSchemaVersion(Int)
    case emptyRegistry
    case duplicateRuleID(String)
    case invalidRule(ruleID: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .bundledResourceNotFound:
            "The bundled rule knowledge resource could not be found."
        case .unreadableResource:
            "The bundled rule knowledge resource could not be read."
        case .invalidJSON:
            "The rule knowledge resource is not valid JSON."
        case let .unsupportedSchemaVersion(version):
            "Rule knowledge schema version \(version) is not supported."
        case .emptyRegistry:
            "The rule knowledge registry must contain at least one rule."
        case let .duplicateRuleID(ruleID):
            "The rule knowledge registry contains duplicate rule ID '\(ruleID)'."
        case let .invalidRule(ruleID, reason):
            "Rule knowledge for '\(ruleID)' is invalid: \(reason)"
        }
    }
}
