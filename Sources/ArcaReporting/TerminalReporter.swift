import ArcaDomain
import Darwin
import Foundation

public struct TerminalReporter: Reporter {
  private let outputIsTTY: @Sendable () -> Bool

  public init(outputIsTTY: (@Sendable () -> Bool)? = nil) {
    self.outputIsTTY =
      outputIsTTY ?? {
        Darwin.isatty(STDOUT_FILENO) == 1
      }
  }

  public func render(
    detectionReport: LLMIssueDetectionReport
  ) throws -> String {
    let usesColor = outputIsTTY()
    let analysis = detectionReport.analysis
    let metadata =
      analysis.llmExecutionMetadata
      ?? LLMExecutionMetadata(
        providerID: "unknown",
        modelID: "unknown",
        requestCount: 0,
        providerDurationMilliseconds: 0
      )
    var lines = [
      "ARCA LLM Detection Experiment",
      "Overall result: \(resultDescription(analysis.candidates.count))",
      "",
      "Run configuration",
      "-----------------",
      "Prompt: \(promptDescription(detectionReport.promptVariant))",
      scopeDescription(for: detectionReport),
      "File: \(detectionReport.filePath)",
      "Provider: \(metadata.providerID)",
      "Model: \(metadata.modelID)",
      "Requests: \(metadata.requestCount)",
      "Duration: \(metadata.providerDurationMilliseconds) ms",
      "Token usage: \(tokenSummary(metadata.usage))",
    ]

    if analysis.candidates.isEmpty {
      lines += [
        "",
        "Detection results",
        "-----------------",
        "No candidates were returned by the model.",
      ]
    }

    for (index, finding) in analysis.candidates.enumerated() {
      lines += [
        "",
        "Candidate \(index + 1) — \(finding.title)",
        "----------------------------------",
      ]
      if let category = finding.category {
        lines.append("Category: \(humanized(category))")
      }
      if let issueType = finding.issueType {
        lines.append("Issue type: \(issueTypeDescription(issueType))")
      }
      if let ruleID = finding.ruleID {
        lines.append("Canonical rule: \(ruleID)")
      }
      lines.append("Location: \(finding.filePath)")
      if let range = finding.range {
        lines.append(
          "Lines: "
            + (range.startLine == range.endLine
              ? "\(range.startLine)"
              : "\(range.startLine)–\(range.endLine)")
        )
      }
      lines += [
        "",
        "LLM detection",
        "-------------",
        "Explanation: \(finding.explanation)",
      ]
      appendEvidence(finding.evidence, to: &lines)
    }

    if !analysis.diagnostics.isEmpty {
      lines += ["", "Validation notes", "----------------"]
      lines.append(
        contentsOf: analysis.diagnostics.map {
          "\(severityLabel($0.severity, usesColor: usesColor)) \($0.code): \($0.message)"
        })
    }
    return lines.joined(separator: "\n")
  }

  private func resultDescription(_ count: Int) -> String {
    switch count {
    case 0: "No candidates detected"
    case 1: "1 candidate detected"
    default: "\(count) candidates detected"
    }
  }

  private func promptDescription(_ variant: CodeAnalysisPromptVariant) -> String {
    switch variant {
    case .baseline: "Baseline — source and general instructions only"
    case .guided: "Guided — rules and knowledge included"
    }
  }

  private func reviewDescription(_ type: ReviewType) -> String {
    switch type {
    case .swift: "Swift"
    case .swiftUI: "SwiftUI"
    case .tca: "TCA"
    case .security: "Security"
    case .godObject: "God Object"
    case .all: "All rule sets"
    }
  }

  private func scopeDescription(
    for report: LLMIssueDetectionReport
  ) -> String {
    if let reviewType = report.reviewType {
      return "Review: \(reviewDescription(reviewType))"
    }
    return "Analysis scope: General, without rules"
  }

  private func issueTypeDescription(_ issueType: IssueType) -> String {
    switch issueType {
    case .antiPattern: "Anti-pattern"
    case .codeSmell: "Code smell"
    case .unsafeCode: "Unsafe code"
    case .deprecatedAPI: "Deprecated API"
    case .securityWeakness: "Security weakness"
    case .conventionViolation: "Convention violation"
    }
  }

  private func humanized(_ value: String) -> String {
    value
      .replacingOccurrences(
        of: "([a-z0-9])([A-Z])",
        with: "$1 $2",
        options: .regularExpression
      )
      .replacingOccurrences(of: "-", with: " ")
      .split(separator: " ")
      .map { $0.capitalized }
      .joined(separator: " ")
  }

  private func tokenSummary(_ usage: LLMTokenUsageMetadata) -> String {
    "\(usage.inputTokens.map(String.init) ?? "unknown") input, "
      + "\(usage.outputTokens.map(String.init) ?? "unknown") output, "
      + "\(usage.totalTokens.map(String.init) ?? "unknown") total"
  }

  private func severityLabel(
    _ severity: Severity,
    usesColor: Bool
  ) -> String {
    let label = "[\(severity.rawValue.uppercased())]"
    guard usesColor else { return label }
    let code =
      switch severity {
      case .info: "36"
      case .warning: "33"
      case .error: "31"
      case .critical: "1;31"
      }
    return "\u{001B}[\(code)m\(label)\u{001B}[0m"
  }

  private func appendEvidence(
    _ evidence: [SourceCodeEvidence],
    to lines: inout [String]
  ) {
    guard !evidence.isEmpty else { return }
    lines.append("Evidence:")
    for item in evidence {
      lines.append("  - \(item.description)")
    }
  }
}
