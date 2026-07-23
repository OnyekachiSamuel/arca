import Foundation

public enum SuggestionPromptBuildingError: Error, Equatable, LocalizedError {
    case invalidLimits
    case unknownRuleID(String)
    case sourceExcerptTooLarge(actualBytes: Int, maximumBytes: Int)
    case promptTooLarge(actualBytes: Int, maximumBytes: Int)
    case inputEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidLimits:
            "Suggestion prompt size limits must be greater than zero."
        case let .unknownRuleID(ruleID):
            "No rule knowledge is registered for '\(ruleID)'."
        case let .sourceExcerptTooLarge(actualBytes, maximumBytes):
            "The source excerpt is \(actualBytes) UTF-8 bytes; the limit is \(maximumBytes)."
        case let .promptTooLarge(actualBytes, maximumBytes):
            "The suggestion prompt is \(actualBytes) UTF-8 bytes; the limit is \(maximumBytes)."
        case .inputEncodingFailed:
            "The suggestion prompt input could not be encoded."
        }
    }
}
