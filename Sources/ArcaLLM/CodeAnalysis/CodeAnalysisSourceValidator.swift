import ArcaDomain
import Foundation

struct CodeAnalysisSourceValidator: Sendable {
    let sourceLines: [String]
    let limits: CodeAnalysisResponseLimits

    func validateEvidence(
        description: String,
        excerpt: String,
        startLine: Int,
        endLine: Int,
        findingStartLine: Int,
        findingEndLine: Int
    ) -> CodeAnalysisEvidenceValidationResult {
        let normalizedDescription = description.trimmedForCodeAnalysis
        guard !normalizedDescription.isEmpty else {
            return .rejected(.emptyDescription)
        }
        guard normalizedDescription.utf8.count
                <= limits.maximumEvidenceDescriptionUTF8Bytes else {
            return .rejected(.descriptionTooLarge)
        }
        guard !excerpt.trimmedForCodeAnalysis.isEmpty else {
            return .rejected(.emptyExcerpt)
        }
        guard excerpt.utf8.count
                <= limits.maximumEvidenceExcerptUTF8Bytes else {
            return .rejected(.excerptTooLarge)
        }
        guard isValidRange(startLine: startLine, endLine: endLine) else {
            return .rejected(.invalidRange(
                startLine: startLine,
                endLine: endLine
            ))
        }
        guard startLine >= findingStartLine,
              endLine <= findingEndLine else {
            return .rejected(.outsideFinding(
                evidenceStartLine: startLine,
                evidenceEndLine: endLine,
                findingStartLine: findingStartLine,
                findingEndLine: findingEndLine
            ))
        }

        let selectedSource = sourceLines[(startLine - 1)...(endLine - 1)]
            .map { PromptTextRedactor.redactCommonSecrets(in: $0) }
            .joined(separator: "\n")
        guard selectedSource.contains(excerpt) else {
            return .rejected(.excerptMismatch(
                startLine: startLine,
                endLine: endLine
            ))
        }

        return .accepted(SourceCodeEvidence(
            description: normalizedDescription,
            range: sourceRange(startLine: startLine, endLine: endLine),
            excerpt: excerpt
        ))
    }

    func sourceRange(startLine: Int, endLine: Int) -> SourceRange {
        SourceRange(
            startLine: startLine,
            startColumn: 1,
            endLine: endLine,
            endColumn: sourceLines[endLine - 1].utf8.count + 1
        )
    }

    func isValidRange(startLine: Int, endLine: Int) -> Bool {
        startLine >= 1
            && endLine >= startLine
            && endLine <= sourceLines.count
    }

    func isSafePath(_ path: String) -> Bool {
        let trimmedPath = path.trimmedForCodeAnalysis
        guard !trimmedPath.isEmpty,
              path == trimmedPath,
              !path.hasPrefix("/"),
              path.lowercased().hasSuffix(".swift"),
              !path.contains("\0") else {
            return false
        }

        return path.split(separator: "/", omittingEmptySubsequences: false)
            .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}

enum CodeAnalysisEvidenceValidationResult {
    case accepted(SourceCodeEvidence)
    case rejected(CodeAnalysisEvidenceValidationFailure)
}

enum CodeAnalysisEvidenceValidationFailure {
    case emptyDescription
    case descriptionTooLarge
    case emptyExcerpt
    case excerptTooLarge
    case invalidRange(startLine: Int, endLine: Int)
    case outsideFinding(
        evidenceStartLine: Int,
        evidenceEndLine: Int,
        findingStartLine: Int,
        findingEndLine: Int
    )
    case excerptMismatch(startLine: Int, endLine: Int)

    var isExcerptMismatch: Bool {
        if case .excerptMismatch = self { return true }
        return false
    }

    func evidenceVerificationMessage(evidenceIndex: Int) -> String {
        switch self {
        case let .excerptMismatch(startLine, endLine):
            "Evidence \(evidenceIndex + 1) could not be matched exactly to source lines \(startLine)–\(endLine)."
        default:
            "Evidence \(evidenceIndex + 1) could not be verified."
        }
    }

    var code: String {
        switch self {
        case .emptyDescription:
            "ARCA-LLM-ANALYSIS-EVIDENCE-EMPTY-DESCRIPTION"
        case .descriptionTooLarge:
            "ARCA-LLM-ANALYSIS-EVIDENCE-DESCRIPTION-TOO-LARGE"
        case .emptyExcerpt:
            "ARCA-LLM-ANALYSIS-EVIDENCE-EMPTY-EXCERPT"
        case .excerptTooLarge:
            "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-TOO-LARGE"
        case .invalidRange:
            "ARCA-LLM-ANALYSIS-EVIDENCE-INVALID-RANGE"
        case .outsideFinding:
            "ARCA-LLM-ANALYSIS-EVIDENCE-OUTSIDE-FINDING"
        case .excerptMismatch:
            "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-MISMATCH"
        }
    }

    func message(findingIndex: Int, evidenceIndex: Int) -> String {
        let prefix = "Finding \(findingIndex + 1), evidence \(evidenceIndex + 1)"
        switch self {
        case .emptyDescription:
            return "\(prefix) has an empty description."
        case .descriptionTooLarge:
            return "\(prefix) description exceeds the configured size limit."
        case .emptyExcerpt:
            return "\(prefix) has an empty source excerpt."
        case .excerptTooLarge:
            return "\(prefix) source excerpt exceeds the configured size limit."
        case let .invalidRange(startLine, endLine):
            return "\(prefix) has invalid source lines \(startLine)–\(endLine)."
        case let .outsideFinding(
            evidenceStartLine,
            evidenceEndLine,
            findingStartLine,
            findingEndLine
        ):
            return "\(prefix) lines \(evidenceStartLine)–\(evidenceEndLine) are outside finding lines \(findingStartLine)–\(findingEndLine)."
        case let .excerptMismatch(startLine, endLine):
            return "\(prefix) excerpt does not exactly match source lines \(startLine)–\(endLine)."
        }
    }
}

private extension String {
    var trimmedForCodeAnalysis: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
