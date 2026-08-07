import Foundation

public enum FindingCandidateValidationError:
    Error,
    Equatable,
    LocalizedError,
    Sendable
{
    case missingRuleID
    case missingTitle
    case missingExplanation
    case missingFilePath
    case invalidSourceRange
    case invalidEvidenceSourceRange
    case missingEvidence
    case missingSourceIdentifiers
    case blankSourceIdentifier

    public var errorDescription: String? {
        switch self {
        case .missingRuleID:
            "A finding candidate requires a rule ID."
        case .missingTitle:
            "A finding candidate requires a title."
        case .missingExplanation:
            "A finding candidate requires an explanation."
        case .missingFilePath:
            "A finding candidate requires a file path."
        case .invalidSourceRange:
            "A finding candidate requires a valid one-based source range."
        case .invalidEvidenceSourceRange:
            "Source-code evidence requires a valid one-based source range."
        case .missingEvidence:
            "A finding candidate requires at least one evidence item."
        case .missingSourceIdentifiers:
            "A finding candidate requires at least one source identifier."
        case .blankSourceIdentifier:
            "Finding candidate source identifiers cannot be blank."
        }
    }
}
