import Foundation

public enum CodeAnalysisPromptBuildingError:
    Error,
    Equatable,
    LocalizedError
{
    case invalidLimits
    case noApplicableRules
    case duplicateRuleID(String)
    case sourceLineCountMismatch(expected: Int, actual: Int)
    case promptTooLarge(actualBytes: Int, maximumBytes: Int)
    case inputEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidLimits:
            "The code-analysis prompt size limit must be greater than zero."
        case .noApplicableRules:
            "At least one applicable rule is required to build a code-analysis prompt."
        case let .duplicateRuleID(ruleID):
            "The code-analysis prompt contains the rule ID '\(ruleID)' more than once."
        case let .sourceLineCountMismatch(expected, actual):
            "The source context reports \(expected) lines, but its content contains \(actual) lines."
        case let .promptTooLarge(actualBytes, maximumBytes):
            "The code-analysis prompt is \(actualBytes) UTF-8 bytes; the limit is \(maximumBytes)."
        case .inputEncodingFailed:
            "The code-analysis prompt input could not be encoded."
        }
    }
}
