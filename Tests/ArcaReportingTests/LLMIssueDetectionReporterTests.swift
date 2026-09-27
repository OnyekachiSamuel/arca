import ArcaDomain
import ArcaReporting
import Foundation
import Testing

@Suite("LLM issue-detection reporters")
struct LLMIssueDetectionReporterTests {
  @Test("baseline output identifies an unconstrained analysis scope")
  func rendersBaselineScope() throws {
    let report = try makeReport(
      candidates: [],
      reviewType: nil,
      promptVariant: .baseline
    )
    let output = try TerminalReporter()
      .render(detectionReport: report)

    #expect(output.contains("Analysis scope: General, without rules"))
    #expect(
      output.contains(
        "The model did not identify any candidate code issues in the analysed file."
      )
    )
    #expect(!output.contains("Review:"))
  }

  @Test("terminal output explains the run and guided finding")
  func rendersTerminalReport() throws {
    let report = try makeReport(candidates: [candidate])
    let output = try TerminalReporter()
      .render(detectionReport: report)

    #expect(output.contains("ARCA LLM Detection Experiment"))
    #expect(output.contains("Prompt: Guided — rules and knowledge included"))
    #expect(output.contains("Category: Architecture"))
    #expect(output.contains("Issue type: Anti-pattern"))
    #expect(output.contains("Canonical rule: ARCA-GOD-Object-001"))
    #expect(output.contains("Provider: lm-studio"))
    #expect(!output.contains("Severity:"))
  }

  @Test("JSON output is versioned and decodes to the report")
  func rendersJSONReport() throws {
    let report = try makeReport(candidates: [candidate])
    let output = try JSONReporter().render(detectionReport: report)
    let decoded = try JSONDecoder().decode(
      LLMIssueDetectionReport.self,
      from: Data(output.utf8)
    )

    #expect(decoded == report)
    #expect(decoded.schemaVersion == 1)
    #expect(!output.contains(#""severity""#))
  }

  private var candidate: FindingCandidate {
    get throws {
      try FindingCandidate(
        ruleID: "ARCA-GOD-Object-001",
        title: "God Object",
        explanation: "The type owns unrelated responsibilities.",
        filePath: "Sources/App.swift",
        range: SourceRange(
          startLine: 1,
          startColumn: 1,
          endLine: 10,
          endColumn: 2
        ),
        issueType: .antiPattern,
        category: "architecture",
        evidence: [
          SourceCodeEvidence(
            description: "Networking and persistence are both owned.",
            range: SourceRange(
              startLine: 2,
              startColumn: 1,
              endLine: 4,
              endColumn: 2
            ),
            excerpt: "let client: Client"
          )
        ]
      )
    }
  }

  private func makeReport(
    candidates: [FindingCandidate],
    reviewType: ReviewType? = .godObject,
    promptVariant: CodeAnalysisPromptVariant = .guided
  ) throws -> LLMIssueDetectionReport {
    LLMIssueDetectionReport(
      requestID: UUID(),
      filePath: "Sources/App.swift",
      reviewType: reviewType,
      promptVariant: promptVariant,
      analysis: LLMIssueDetectionResult(
        candidates: candidates,
        executionMetadata: LLMExecutionMetadata(
          providerID: "lm-studio",
          modelID: "qwen",
          requestCount: 1,
          usage: LLMTokenUsageMetadata(totalTokens: 10),
          providerDurationMilliseconds: 20
        )
      ),
      seed: 42,
      temperature: 0
    )
  }
}
