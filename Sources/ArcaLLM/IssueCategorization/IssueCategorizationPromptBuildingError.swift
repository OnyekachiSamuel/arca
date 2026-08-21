import Foundation

public enum IssueCategorizationPromptBuildingError:
    Error,
    Equatable,
    LocalizedError
{
    case invalidLimits
    case noCandidates
    case noRuleKnowledge
    case missingCandidateRuleID(String)
    case duplicateCandidateID(String)
    case duplicateRuleID(String)
    case promptTooLarge(actualBytes: Int, maximumBytes: Int)
    case inputEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidLimits:
            "The issue-categorization prompt size limit must be greater than zero."
        case .noCandidates:
            "At least one candidate is required to build an issue-categorization prompt."
        case .noRuleKnowledge:
            "At least one relevant rule is required to build an issue-categorization prompt."
        case .missingCandidateRuleID(let candidateID):
            "Candidate '\(candidateID)' requires a canonical rule ID for categorization."
        case .duplicateCandidateID(let candidateID):
            "The issue-categorization prompt contains candidate ID '\(candidateID)' more than once."
        case .duplicateRuleID(let ruleID):
            "The issue-categorization prompt contains rule ID '\(ruleID)' more than once."
        case .promptTooLarge(let actualBytes, let maximumBytes):
            "The issue-categorization prompt is \(actualBytes) UTF-8 bytes; the limit is \(maximumBytes)."
        case .inputEncodingFailed:
            "The issue-categorization prompt input could not be encoded."
        }
    }
}
