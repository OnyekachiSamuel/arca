import ArcaDomain
import Foundation

struct SwiftLintCandidateMapper: Sendable {
    let workingDirectoryURL: URL
    let analyzerID: String

    func map(_ violation: SwiftLintViolation) throws -> FindingCandidate {
        let range = sourceRange(for: violation)
        let isTeamConvention = violation.ruleID.hasPrefix("arca_team_")
        return try FindingCandidate(
            candidateID: UUID(),
            ruleID: isTeamConvention
                ? "ARCA-TEAM-001"
                : "swiftlint.\(violation.ruleID)",
            title: violation.type,
            explanation: violation.reason,
            filePath: normalizedPath(violation.file),
            range: range,
            proposedSeverity: try severity(from: violation.severity),
            proposedCategory: isTeamConvention ? .teamConvention : .style,
            evidence: [
                .analyzer(AnalyzerEvidence(
                    description: violation.reason,
                    externalRuleID: violation.ruleID,
                    range: range
                ))
            ],
            sourceIdentifiers: [analyzerID],
            analyzerMetadata: metadata(for: violation)
        )
    }

    private func severity(from value: String) throws -> Severity {
        switch value.lowercased() {
        case "warning": .warning
        case "error": .error
        default: throw SwiftLintAnalyzerError.unsupportedSeverity(value)
        }
    }

    private func sourceRange(for violation: SwiftLintViolation) -> SourceRange? {
        guard let line = violation.line, line > 0 else { return nil }
        let column = max(1, violation.character ?? 1)
        return SourceRange(
            startLine: line,
            startColumn: column,
            endLine: line,
            endColumn: column
        )
    }

    private func normalizedPath(_ path: String) -> String {
        let url = path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : workingDirectoryURL.appendingPathComponent(path)
        return url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func metadata(
        for violation: SwiftLintViolation
    ) -> [String: FindingMetadataValue] {
        var metadata: [String: FindingMetadataValue] = [
            "rule_id": .string(violation.ruleID),
            "reason": .string(violation.reason),
            "severity": .string(violation.severity),
            "type": .string(violation.type),
            "file": .string(violation.file)
        ]
        if let line = violation.line { metadata["line"] = .integer(line) }
        if let character = violation.character {
            metadata["character"] = .integer(character)
        }
        return metadata
    }
}
