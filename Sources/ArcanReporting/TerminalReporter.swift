import ArcanDomain
import Darwin

public struct TerminalReporter: Reporter {
    private let outputIsTTY: @Sendable () -> Bool

    public init(outputIsTTY: (@Sendable () -> Bool)? = nil) {
        self.outputIsTTY = outputIsTTY ?? {
            Darwin.isatty(STDOUT_FILENO) == 1
        }
    }

    public func render(analysis: ReviewAnalysisResult) throws -> String {
        let usesColor = outputIsTTY()
        let candidateLabel = analysis.candidates.count == 1
            ? "candidate"
            : "candidates"
        var lines = [
            "ARCAN Review Analysis",
            "\(analysis.candidates.count) \(candidateLabel)"
        ]
        let skippedCount = analysis.analyzerResults.filter {
            $0.executionStatus == .skipped
        }.count
        if skippedCount > 0 {
            let analyzerLabel = skippedCount == 1 ? "analyzer" : "analyzers"
            lines.append("\(skippedCount) \(analyzerLabel) skipped")
        }

        for candidate in analysis.candidates {
            lines.append("")
            lines.append(
                "\(severityLabel(for: candidate.proposedSeverity, usesColor: usesColor)) "
                    + "\(candidate.ruleID): \(candidate.title)"
            )
            lines.append("File: \(location(for: candidate))")
            lines.append("Explanation: \(candidate.explanation)")
            appendEvidence(candidate.evidence, to: &lines)
        }

        for diagnostic in analysis.diagnostics {
            lines.append("")
            lines.append(
                "\(severityLabel(for: diagnostic.severity, usesColor: usesColor)) "
                    + "\(diagnostic.code): \(diagnostic.message)"
            )
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

    private func location(for candidate: FindingCandidate) -> String {
        guard let range = candidate.range else {
            return candidate.filePath
        }
        return "\(candidate.filePath):\(range.startLine):\(range.startColumn)"
            + "-\(range.endLine):\(range.endColumn)"
    }

    private func appendEvidence(
        _ evidence: [FindingEvidence],
        to lines: inout [String]
    ) {
        guard !evidence.isEmpty else { return }

        lines.append("Evidence:")
        for item in evidence {
            switch item {
            case .metric(let metric):
                lines.append(
                    "  - \(metric.metricName): \(metric.observedValue) "
                        + "(threshold: \(metric.thresholdValue))"
                )
            case .analyzer(let analyzer):
                lines.append("  - \(analyzer.description)")
            case .sourceCode(let sourceCode):
                lines.append("  - \(sourceCode.description)")
            }
        }
    }
}
