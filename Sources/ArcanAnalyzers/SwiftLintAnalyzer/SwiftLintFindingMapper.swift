import ArcanDomain
import Foundation

struct SwiftLintFindingMapper: Sendable {
    let workingDirectoryURL: URL

    func map(_ violation: SwiftLintViolation) throws -> Finding {
        Finding(
            id: UUID(),
            ruleID: "swiftlint.\(violation.ruleID)",
            externalRuleID: violation.ruleID,
            title: violation.type,
            category: .style,
            severity: try severity(from: violation.severity),
            filePath: normalizedPath(violation.file),
            range: sourceRange(for: violation),
            explanation: violation.reason,
            metadata: metadata(for: violation)
        )
    }

    private func severity(from value: String) throws -> Severity {
        switch value.lowercased() {
        case "warning":
            .warning
        case "error":
            .error
        default:
            throw SwiftLintAnalyzerError.unsupportedSeverity(value)
        }
    }

    private func sourceRange(
        for violation: SwiftLintViolation
    ) -> SourceRange? {
        guard let line = violation.line, line > 0 else {
            return nil
        }
        let column = max(1, violation.character ?? 1)
        return SourceRange(
            startLine: line,
            startColumn: column,
            endLine: line,
            endColumn: column
        )
    }

    private func normalizedPath(_ path: String) -> String {
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            url = workingDirectoryURL.appendingPathComponent(path)
        }
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
        if let line = violation.line {
            metadata["line"] = .integer(line)
        }
        if let character = violation.character {
            metadata["character"] = .integer(character)
        }
        return metadata
    }
}
