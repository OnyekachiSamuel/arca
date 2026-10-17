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
    #expect(output.contains("Canonical rule: ARCA-GOD-Object-001"))
    #expect(output.contains("Provider: lm-studio"))
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
    #expect(!output.contains(#""startColumn""#))
    #expect(!output.contains(#""endColumn""#))
    #expect(!output.contains(#""excerpt""#))
  }

  @Test("JSON reports are stored by prompt variant with unique descriptive names")
  func writesJSONReports() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let writer = JSONReportWriter()
    let timestamp = Date(timeIntervalSince1970: 1_790_512_212)

    let baseline = try makeReport(
      candidates: [],
      reviewType: nil,
      promptVariant: .baseline
    )
    let baselineJSON = try JSONReporter().render(detectionReport: baseline)
    let baselineURL = try writer.write(
      baselineJSON,
      report: baseline,
      resultsRoot: directory,
      timestamp: timestamp
    )

    let guided = try makeReport(candidates: [candidate])
    let guidedJSON = try JSONReporter().render(detectionReport: guided)
    let guidedURL = try writer.write(
      guidedJSON,
      report: guided,
      resultsRoot: directory,
      timestamp: timestamp
    )

    #expect(baselineURL.deletingLastPathComponent().lastPathComponent == "baseline")
    #expect(guidedURL.deletingLastPathComponent().lastPathComponent == "guided-analysis")
    #expect(baselineURL.lastPathComponent.hasPrefix("App-"))
    #expect(guidedURL.lastPathComponent.hasPrefix("App-god-object-"))
    #expect(baselineURL.pathExtension == "json")
    #expect(guidedURL.pathExtension == "json")
    #expect(baselineURL != guidedURL)

    let decoded = try JSONDecoder().decode(
      LLMIssueDetectionReport.self,
      from: Data(contentsOf: guidedURL)
    )
    #expect(decoded == guided)
    #expect(throws: JSONReportWritingError.self) {
      try writer.write(
        guidedJSON,
        report: guided,
        resultsRoot: directory,
        timestamp: timestamp
      )
    }
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
          endLine: 10
        ),
        evidence: [
          SourceCodeEvidence(
            description: "Networking and persistence are both owned.",
            range: SourceRange(
              startLine: 2,
              endLine: 4
            )
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
