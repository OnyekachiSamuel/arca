import ArcanDomain
import Darwin
import Foundation

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

    public func render(report: CategorizedReviewReport) throws -> String {
        let usesColor = outputIsTTY()
        let counts = report.counts
        let staticCandidateCount = report.candidates.filter {
            candidateKind(for: $0) == .staticAnalyzer
        }.count
        let llmCandidateCount = report.candidates.filter {
            candidateKind(for: $0) == .llmAnalyzer
        }.count
        let finalIssueCount = report.confirmedFindings.count
            + report.uncertainFindings.count
        var lines = [
            "ARCAN Code Review",
            "Overall result: \(overallResult(for: report))",
            "",
            "Summary",
            "-------",
            report.categorizationSummary ?? "Categorization unavailable."
        ]

        appendFindings(
            report.confirmedFindings,
            startingAt: 1,
            usesColor: usesColor,
            categorizationMetadata: report.categorizationExecutionMetadata,
            to: &lines
        )
        appendFindings(
            report.uncertainFindings,
            startingAt: report.confirmedFindings.count + 1,
            usesColor: usesColor,
            categorizationMetadata: report.categorizationExecutionMetadata,
            to: &lines
        )

        lines.append("")
        lines.append("Review statistics")
        lines.append("-----------------")
        lines.append("Detected candidates: \(counts.totalCandidates)")
        lines.append("  From static analyzers: \(staticCandidateCount)")
        lines.append("  From LLM analysis: \(llmCandidateCount)")
        lines.append("Final issues: \(finalIssueCount)")
        lines.append("  Confirmed: \(report.confirmedFindings.count)")
        if !report.uncertainFindings.isEmpty {
            lines.append(
                "  Requires manual review: \(report.uncertainFindings.count)"
            )
        }
        lines.append("Findings by category:")
        if counts.findingsPerCategory.isEmpty {
            lines.append("  None")
        } else {
            lines.append(contentsOf: counts.findingsPerCategory.map {
                "  \(displayName(for: $0.category)): \($0.count)"
            })
        }

        for diagnostic in report.diagnostics {
            lines.append("")
            lines.append(
                "\(severityLabel(for: diagnostic.severity, usesColor: usesColor)) "
                    + "\(diagnostic.code): \(diagnostic.message)"
            )
        }

        return lines.joined(separator: "\n")
    }

    private func appendFindings(
        _ findings: [Finding],
        startingAt firstIndex: Int,
        usesColor: Bool,
        categorizationMetadata: LLMExecutionMetadata,
        to lines: inout [String]
    ) {
        guard !findings.isEmpty else { return }

        for (offset, finding) in findings.enumerated() {
            lines.append("")
            lines.append("Issue \(firstIndex + offset) — \(finding.title)")
            lines.append("--------------------")
            lines.append(
                "Status: \(finding.assessment.rawValue.uppercased())"
            )
            lines.append(
                "Severity: \(severityLabel(for: finding.severity, usesColor: usesColor))"
            )
            lines.append("Rule: \(finding.ruleID)")
            lines.append("Category: \(displayName(for: finding.category))")
            let locations = terminalLocations(in: finding.candidates)
            if locations.count == 1, let location = locations.first {
                lines.append("Location: \(location.filePath)")
                if let lineRange = location.lineRange {
                    lines.append("Lines: \(lineRange)")
                }
            } else if !locations.isEmpty {
                lines.append("Locations:")
                lines.append(contentsOf: locations.map {
                    if let lineRange = $0.lineRange {
                        return "  - \($0.filePath), lines \(lineRange)"
                    }
                    return "  - \($0.filePath)"
                })
            }

            lines.append("")
            lines.append("Detection evidence")
            lines.append("------------------")
            for candidate in finding.candidates {
                appendCandidate(candidate, to: &lines)
            }

            lines.append("Categorization")
            lines.append("--------------")
            lines.append("Assessment: \(finding.assessment.rawValue.capitalized)")
            lines.append("Grouped candidates: \(finding.candidates.count)")
            lines.append("Analyzer agreement: \(agreementDescription(for: finding.candidates))")
            appendLLMMetadata(categorizationMetadata, to: &lines)
        }
    }

    private func appendCandidate(
        _ candidate: FindingCandidate,
        to lines: inout [String]
    ) {
        let kind = candidateKind(for: candidate)
        lines.append("[\(kind.heading)] \(candidate.title)")
        lines.append("  Analyzer: \(analyzerNames(for: candidate).joined(separator: ", "))")
        if let provider = sourceValue(prefix: "llm-provider:", in: candidate) {
            lines.append("  Provider: \(provider)")
        }
        if let model = sourceValue(prefix: "llm-model:", in: candidate) {
            lines.append("  Model: \(model)")
        }
        lines.append("  Explanation: \(candidate.explanation)")
        appendEvidence(candidate.evidence, indentation: "  ", to: &lines)
        lines.append("")
    }

    private func appendLLMMetadata(
        _ metadata: LLMExecutionMetadata,
        to lines: inout [String]
    ) {
        if !metadata.providerID.isEmpty {
            lines.append("Provider: \(metadata.providerID)")
        }
        if !metadata.modelID.isEmpty {
            lines.append("Model: \(metadata.modelID)")
        }
    }

    private func overallResult(for report: CategorizedReviewReport) -> String {
        let confirmed = report.confirmedFindings.count
        let uncertain = report.uncertainFindings.count
        if confirmed > 0 {
            return "\(confirmed) confirmed \(issueLabel(for: confirmed))"
        }
        if uncertain > 0 {
            return "\(uncertain) \(issueLabel(for: uncertain)) requiring manual review"
        }
        if report.categorizationSummary == nil {
            return "categorization unavailable"
        }
        return "no confirmed or uncertain issues"
    }

    private func issueLabel(for count: Int) -> String {
        count == 1 ? "issue" : "issues"
    }

    private func displayName(for category: FindingCategory) -> String {
        switch category {
        case .antiPattern: "Anti-pattern"
        case .architecture: "Architecture"
        case .style: "Style"
        case .teamConvention: "Team convention"
        case .general: "General"
        case .uncategorized: "Uncategorized"
        }
    }

    private func terminalLocations(
        in candidates: [FindingCandidate]
    ) -> [TerminalLocation] {
        candidates.reduce(into: []) { locations, candidate in
            let value = TerminalLocation(
                filePath: candidate.filePath,
                lineRange: candidate.range.map {
                    $0.startLine == $0.endLine
                        ? "\($0.startLine)"
                        : "\($0.startLine)–\($0.endLine)"
                }
            )
            if !locations.contains(value) { locations.append(value) }
        }
    }

    private struct TerminalLocation: Equatable {
        let filePath: String
        let lineRange: String?
    }

    private func agreementDescription(
        for candidates: [FindingCandidate]
    ) -> String {
        let kinds = Set(candidates.map(candidateKind))
        if kinds == [.staticAnalyzer, .llmAnalyzer] {
            return "Static analyzer + LLM analyzer"
        }
        if kinds == [.staticAnalyzer] { return "Static analyzer only" }
        if kinds == [.llmAnalyzer] { return "LLM analyzer only" }
        return "Unavailable"
    }

    private func analyzerNames(for candidate: FindingCandidate) -> [String] {
        candidate.sourceIdentifiers.filter {
            !$0.hasPrefix("llm-provider:") && !$0.hasPrefix("llm-model:")
        }
    }

    private func sourceValue(
        prefix: String,
        in candidate: FindingCandidate
    ) -> String? {
        candidate.sourceIdentifiers.first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private func candidateKind(
        for candidate: FindingCandidate
    ) -> CandidateKind {
        candidate.sourceIdentifiers.contains("llm-code-analysis")
            ? .llmAnalyzer
            : .staticAnalyzer
    }

    private enum CandidateKind {
        case staticAnalyzer
        case llmAnalyzer

        var heading: String {
            switch self {
            case .staticAnalyzer: "STATIC ANALYZER"
            case .llmAnalyzer: "LLM ANALYZER"
            }
        }
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
        indentation: String = "",
        to lines: inout [String]
    ) {
        guard !evidence.isEmpty else { return }

        lines.append("\(indentation)Evidence:")
        for item in evidence {
            switch item {
            case .metric(let metric):
                lines.append(
                    "\(indentation)  - \(metric.metricName): \(metric.observedValue) "
                        + "(threshold: \(metric.thresholdValue))"
                )
            case .ratio(let ratio):
                lines.append(
                    "\(indentation)  - \(ratio.metricName): \(ratio.observedValue) "
                        + "(threshold: \(ratio.thresholdValue))"
                )
            case .analyzer(let analyzer):
                lines.append("\(indentation)  - \(analyzer.description)")
            case .sourceCode(let sourceCode):
                lines.append("\(indentation)  - \(sourceCode.description)")
            }
        }
    }
}
