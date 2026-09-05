import ArcaDomain
import ArcaLLM
import Foundation
import Testing

@testable import ArcaCLI

@Suite("Arca LLM command")
struct ArcaCommandTests {
  @Test("baseline sends one broad prompt without rule knowledge")
  func runsBaseline() async throws {
    try await withFixture { directory, file in
      let provider = RecordingProvider()
      let result = await run(
        directory: directory,
        file: file,
        review: nil,
        prompt: "baseline",
        provider: provider
      )
      let report = try decode(result)
      let prompts = await provider.prompts

      #expect(result.exitStatus == .success)
      #expect(report.promptVariant == .baseline)
      #expect(report.reviewType == nil)
      #expect(result.reviewRequest?.selectedReviewTypes.isEmpty == true)
      #expect(prompts.count == 1)
      #expect(prompts[0].contains("Variant: baseline"))
      #expect(!prompts[0].contains("RULES_AND_KNOWLEDGE"))
      #expect(!prompts[0].contains("ARCA-SWIFT-CONCURRENCY-001"))
    }
  }

  @Test("guided sends the selected rule definitions and Markdown knowledge")
  func runsGuided() async throws {
    try await withFixture { directory, file in
      let provider = RecordingProvider()
      let result = await run(
        directory: directory,
        file: file,
        review: "god-object",
        prompt: "guided",
        provider: provider
      )
      let report = try decode(result)
      let prompt = try #require(await provider.prompts.first)

      #expect(result.exitStatus == .success)
      #expect(report.promptVariant == .guided)
      #expect(report.reviewType == .godObject)
      #expect(prompt.contains("ARCA-GOD-Object-001"))
      #expect(prompt.contains("Problem context:"))
      #expect(prompt.contains("Violation criteria:"))
      #expect(prompt.contains("# God Object"))
      #expect(prompt.contains("```swift"))
      #expect(!prompt.contains("ARCA-SWIFT-CONCURRENCY-001"))
      #expect(!prompt.contains("arca.issue-categorization"))
    }
  }

  @Test("guided all runs each rule set separately and aggregates usage")
  func runsAllGuidedRuleSets() async throws {
    try await withFixture { directory, file in
      let provider = RecordingProvider()
      let result = await run(
        directory: directory,
        file: file,
        review: "all",
        prompt: "guided",
        provider: provider
      )
      let report = try decode(result)
      let prompts = await provider.prompts

      #expect(report.reviewType == .all)
      #expect(prompts.count == ReviewType.analysisTypes.count)
      #expect(report.analysis.llmExecutionMetadata?.requestCount == 5)
      #expect(report.analysis.llmExecutionMetadata?.usage.totalTokens == 15)
      #expect(report.analysis.candidates.isEmpty)
      #expect(report.analysis.diagnostics.isEmpty)
      #expect(
        prompts.allSatisfy { $0.contains("RULE APPLICABILITY") }
      )
      for reviewType in ReviewType.analysisTypes {
        #expect(
          prompts.contains {
            $0.contains("Review type: \(reviewType.commandLineName)")
          })
      }
    }
  }

  @Test("baseline rejects any review selection")
  func rejectsReviewForBaseline() async throws {
    try await withFixture { directory, file in
      let provider = RecordingProvider()
      let result = await run(
        directory: directory,
        file: file,
        review: "swift",
        prompt: "baseline",
        provider: provider
      )

      #expect(result.exitStatus == .invalidInput)
      #expect(result.output.contains("must not be provided with the baseline prompt"))
      #expect(await provider.prompts.isEmpty)
    }
  }

  @Test("legacy combined review command is not exposed by the LLM-only MVP")
  func rejectsLegacyReviewCommand() async {
    let result = await ArcaCommand.run(arguments: ["review", "--help"])

    #expect(result.exitStatus == .invalidInput)
    #expect(!ArcaCommand.rootHelp.contains("review                  "))
  }

  @Test("help describes the experiment variants and rule sets")
  func describesCommand() async {
    let result = await ArcaCommand.run(arguments: ["llm", "--help"])

    #expect(result.exitStatus == .success)
    #expect(result.output.contains("baseline"))
    #expect(result.output.contains("guided"))
    #expect(result.output.contains("swiftui"))
    #expect(result.output.contains("security"))
    #expect(result.output.contains("all"))
  }

  private func run(
    directory: URL,
    file: URL,
    review: String?,
    prompt: String,
    provider: RecordingProvider
  ) async -> CommandResult {
    var arguments = ["llm", "--file", file.path]
    if let review {
      arguments += ["--review", review]
    }
    arguments += ["--prompt", prompt, "--format", "json"]
    return await ArcaCommand.execute(
      arguments: arguments,
      currentDirectory: directory.path,
      llmProvider: provider
    )
  }

  private func decode(_ result: CommandResult) throws -> LLMIssueDetectionReport {
    try JSONDecoder().decode(
      LLMIssueDetectionReport.self,
      from: Data(result.output.utf8)
    )
  }

  private func withFixture(
    _ body: (URL, URL) async throws -> Void
  ) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("Example.swift")
    try "struct Example {}\n".write(
      to: file,
      atomically: true,
      encoding: .utf8
    )
    try """
    {
      "schemaVersion": 1,
      "llm": {
        "providerID": "mock",
        "baseURL": "http://127.0.0.1:1234",
        "modelID": "mock-model",
        "timeoutSeconds": 30,
        "temperature": 0,
        "seed": 7
      }
    }
    """.write(
      to: directory.appendingPathComponent(".arca.json"),
      atomically: true,
      encoding: .utf8
    )
    try await body(directory, file)
  }
}

private actor RecordingProvider: LLMProvider {
  nonisolated let id = "mock"
  private(set) var prompts: [String] = []

  func submit(_ request: LLMRequest) async throws -> LLMResponse {
    prompts.append(request.prompt)
    return LLMResponse(
      text: #"{"findings":[]}"#,
      usage: LLMTokenUsageMetadata(
        inputTokens: 1,
        outputTokens: 1,
        totalTokens: 3
      ),
      durationMilliseconds: 2
    )
  }
}
