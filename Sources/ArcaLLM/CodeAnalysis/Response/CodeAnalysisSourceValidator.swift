import ArcaDomain
import Foundation

struct CodeAnalysisSourceValidator: Sendable {
    let sourceLines: [String]
    let limits: CodeAnalysisResponseLimits
    
    func validateEvidence(
        description: String,
        startLine: Int,
        endLine: Int
    ) -> CodeAnalysisEvidenceValidationResult {
        let normalizedDescription = description.trimmedForCodeAnalysis
        guard !normalizedDescription.isEmpty else {
            return .rejected(.emptyDescription)
        }
        guard
            normalizedDescription.utf8.count
                <= limits.maximumEvidenceDescriptionUTF8Bytes
        else {
            return .rejected(.descriptionTooLarge)
        }
        guard isValidRange(startLine: startLine, endLine: endLine) else {
            return .rejected(
                .invalidRange(
                    startLine: startLine,
                    endLine: endLine
                ))
        }
        
        return .accepted(
            SourceCodeEvidence(
                description: normalizedDescription,
                range: sourceRange(startLine: startLine, endLine: endLine)
            ))
    }
    
    func sourceRange(startLine: Int, endLine: Int) -> SourceRange {
        SourceRange(
            startLine: startLine,
            endLine: endLine
        )
    }
    
    func isValidRange(startLine: Int, endLine: Int) -> Bool {
        startLine >= 1
        && endLine >= startLine
        && endLine <= sourceLines.count
    }
}

enum CodeAnalysisEvidenceValidationResult {
    case accepted(SourceCodeEvidence)
    case rejected(CodeAnalysisEvidenceValidationFailure)
}

enum CodeAnalysisEvidenceValidationFailure {
    case emptyDescription
    case descriptionTooLarge
    case invalidRange(startLine: Int, endLine: Int)
    
    var code: String {
        switch self {
        case .emptyDescription:
            "ARCA-LLM-ANALYSIS-EVIDENCE-EMPTY-DESCRIPTION"
        case .descriptionTooLarge:
            "ARCA-LLM-ANALYSIS-EVIDENCE-DESCRIPTION-TOO-LARGE"
        case .invalidRange:
            "ARCA-LLM-ANALYSIS-EVIDENCE-INVALID-RANGE"
        }
    }
    
    func message(findingIndex: Int, evidenceIndex: Int) -> String {
        let prefix = "Finding \(findingIndex + 1), evidence \(evidenceIndex + 1)"
        switch self {
        case .emptyDescription:
            return "\(prefix) has an empty description."
        case .descriptionTooLarge:
            return "\(prefix) description exceeds the configured size limit."
        case .invalidRange(let startLine, let endLine):
            return "\(prefix) has invalid source lines \(startLine)–\(endLine)."
        }
    }
}

extension String {
    fileprivate var trimmedForCodeAnalysis: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
