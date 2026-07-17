import ArcanDomain
import Darwin

public struct TerminalReporter: Reporter {
    private let outputIsTTY: @Sendable () -> Bool

    public init(outputIsTTY: (@Sendable () -> Bool)? = nil) {
        self.outputIsTTY = outputIsTTY ?? {
            Darwin.isatty(STDOUT_FILENO) == 1
        }
    }

    public func render(report: ReviewReport) throws -> String {
        let usesColor = outputIsTTY()
        let findingLabel = report.findings.count == 1 ? "finding" : "findings"
        var lines = [
            "ARCAN Review Report",
            "\(report.findings.count) \(findingLabel)"
        ]

        for finding in report.findings {
            lines.append("")
            lines.append(
                "\(severityLabel(for: finding.severity, usesColor: usesColor)) "
                    + "\(finding.ruleID): \(finding.title)"
            )
            lines.append("File: \(location(for: finding))")
            lines.append("Explanation: \(finding.explanation)")
            appendEvidence(finding.evidence, to: &lines)
            appendSuggestion(finding.suggestion, to: &lines)
        }

        return lines.joined(separator: "\n")
    }

    private func severityLabel(
        for severity: Severity,
        usesColor: Bool
    ) -> String {
        let label = "[\(severity.rawValue.uppercased())]"
        guard usesColor else { return label }

        let colorCode: String
        switch severity {
        case .info:
            colorCode = "36"
        case .warning:
            colorCode = "33"
        case .error:
            colorCode = "31"
        case .critical:
            colorCode = "1;31"
        }
        return "\u{001B}[\(colorCode)m\(label)\u{001B}[0m"
    }

    private func location(for finding: Finding) -> String {
        guard let range = finding.range else {
            return finding.filePath
        }
        return "\(finding.filePath):\(range.startLine):\(range.startColumn)"
            + "-\(range.endLine):\(range.endColumn)"
    }

    private func appendEvidence(
        _ evidence: [Evidence],
        to lines: inout [String]
    ) {
        guard !evidence.isEmpty else { return }

        lines.append("Evidence:")
        for item in evidence {
            lines.append(
                "  - \(item.metric): \(item.observedValue) "
                    + "(threshold: \(item.thresholdValue))"
            )
        }
    }

    private func appendSuggestion(
        _ suggestion: Suggestion?,
        to lines: inout [String]
    ) {
        guard let suggestion else { return }

        lines.append("Suggestion: \(suggestion.summary)")
        for (index, step) in suggestion.steps.enumerated() {
            lines.append("  \(index + 1). \(step)")
        }
    }
}
