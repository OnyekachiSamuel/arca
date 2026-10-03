import ArcaDomain
import Foundation

public struct TerminalReporter {
  public init() {}

  public func render(
    detectionReport: LLMIssueDetectionReport
  ) throws -> String {
    let analysis = detectionReport.analysis
    let metadata = analysis.executionMetadata
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
        "The model did not identify any candidate code issues in the analysed file.",
      ]
    }

    for (index, finding) in analysis.candidates.enumerated() {
      lines += [
        "",
        "Candidate \(index + 1) — \(finding.title)",
        "----------------------------------",
      ]
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
          "\($0.code): \($0.message)"
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

  private func tokenSummary(_ usage: LLMTokenUsageMetadata) -> String {
    "\(usage.inputTokens.map(String.init) ?? "unknown") input, "
      + "\(usage.outputTokens.map(String.init) ?? "unknown") output, "
      + "\(usage.totalTokens.map(String.init) ?? "unknown") total"
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
