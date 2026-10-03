import ArcaDomain
import ArcaLLM
import Foundation
import Testing

@testable import ArcaCLI

@Suite("Arca command")
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
      #expect(result.output.contains("JSON report written to:"))
      #expect(reportURL(from: result).path.contains("/arca-results/baseline/"))
      #expect(prompts.count == 1)
      #expect(prompts[0].contains("your existing knowledge"))
      #expect(!prompts[0].contains("RULES_AND_KNOWLEDGE"))
      #expect(!prompts[0].contains("ARCA-SWIFT-CONCURRENCY-001"))
      #expect(!prompts[0].contains(#""change" :"#))
    }
  }

  @Test("selected file changes are included as optional prompt context")
  func includesSelectedFileChanges() async throws {
    try await withFixture { directory, file in
      try runGit(["init", "--quiet"], in: directory)
      try runGit(["add", "--", file.lastPathComponent, ".arca.json"], in: directory)
      try runGit(
        [
          "-c", "user.name=ARCA Tests",
          "-c", "user.email=arca-tests@example.invalid",
          "commit", "--quiet", "-m", "Initial fixture",
        ],
        in: directory
      )
      try """
      struct Example {
        let value = 2
      }
      """.write(to: file, atomically: true, encoding: .utf8)

      let provider = RecordingProvider()
      let result = await run(
        directory: directory,
        file: file,
        review: nil,
        prompt: "baseline",
        provider: provider
      )
      let prompt = try #require(await provider.prompts.first)

      #expect(result.exitStatus == .success)
      #expect(prompt.contains(#""change" :"#))
      #expect(prompt.contains(#""modifiedLineRanges" :"#))
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
      #expect(
        reportURL(from: result).lastPathComponent.contains("-god-object-")
      )
      #expect(prompt.contains("ARCA-GOD-Object-001"))
      #expect(prompt.contains("Problem context:"))
      #expect(prompt.contains("Violation criteria:"))
      #expect(prompt.contains("# God Object"))
      #expect(prompt.contains("```swift"))
      #expect(!prompt.contains("ARCA-SWIFT-CONCURRENCY-001"))
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
      #expect(report.analysis.executionMetadata.requestCount == 5)
      #expect(report.analysis.executionMetadata.usage.totalTokens == 15)
      #expect(report.analysis.candidates.isEmpty)
      #expect(report.analysis.diagnostics.isEmpty)
      #expect(
        prompts.allSatisfy { $0.contains("RULE APPLICABILITY") }
      )
      for ruleID in [
        "ARCA-SWIFT-CONCURRENCY-001",
        "ARCA-SWIFTUI-STATE-001",
        "ARCA-TCA-DEPRECATED-001",
        "ARCA-OWASP-MASWE-0001",
        "ARCA-GOD-Object-001",
      ] {
        #expect(
          prompts.contains {
            $0.contains("Rule ID: \(ruleID)")
          })
      }
    }
  }

  @Test("help describes the experiment variants and rule sets")
  func describesCommand() async {
    let result = await ArcaCommand.run(arguments: ["--help"])

    #expect(result.exitStatus == .success)
    #expect(result.output.contains("USAGE: arca --file"))
    #expect(!result.output.contains("arca llm"))
    #expect(result.output.contains("baseline"))
    #expect(result.output.contains("guided"))
    #expect(result.output.contains("swiftui"))
    #expect(result.output.contains("security"))
    #expect(result.output.contains("all"))
    #expect(result.output.contains("--provider <id>"))
  }

  @Test("terminal output does not create a JSON report")
  func terminalDoesNotWriteJSON() async throws {
    try await withFixture { directory, file in
      let result = await ArcaCommand.execute(
        arguments: [
          "--file", file.path,
          "--prompt", "baseline",
          "--format", "terminal",
        ],
        currentDirectory: directory.path,
        llmProvider: RecordingProvider()
      )

      #expect(result.exitStatus == .success)
      #expect(result.output.contains("ARCA LLM Detection Experiment"))
      #expect(!result.output.contains("Prompt sent to LLM"))
      #expect(!result.output.contains("INPUT_DATA"))
      #expect(
        !FileManager.default.fileExists(
          atPath: directory.appendingPathComponent("arca-results").path
        )
      )
    }
  }

  @Test("show prompt displays the exact request and preserves the terminal report")
  func showsPromptAndTerminalReport() async throws {
    try await withFixture { directory, file in
      let provider = RecordingProvider()
      let result = await ArcaCommand.execute(
        arguments: [
          "--file", file.path,
          "--prompt", "baseline",
          "--format", "terminal",
          "--show-prompt",
        ],
        currentDirectory: directory.path,
        llmProvider: provider
      )
      let sentPrompt = try #require(await provider.prompts.first)

      #expect(result.exitStatus == .success)
      #expect(result.output.contains("Prompt sent to LLM"))
      #expect(result.output.contains(sentPrompt))
      #expect(result.output.contains("ARCA LLM Detection Experiment"))
    }
  }

  @Test("show prompt displays every guided request and still writes JSON")
  func showsAllPromptsAndWritesJSON() async throws {
    try await withFixture { directory, file in
      let provider = RecordingProvider()
      let result = await ArcaCommand.execute(
        arguments: [
          "--file", file.path,
          "--review", "all",
          "--prompt", "guided",
          "--format", "json",
          "--show-prompt",
        ],
        currentDirectory: directory.path,
        llmProvider: provider
      )
      let promptCount = await provider.prompts.count
      let reportMessage = try #require(result.output.split(separator: "\n").last)
      let prefix = "JSON report written to: "
      let reportPath = String(reportMessage.dropFirst(prefix.count))

      #expect(result.exitStatus == .success)
      #expect(promptCount == ReviewType.analysisTypes.count)
      #expect(result.output.contains("Prompt 1 of 5 sent to LLM"))
      #expect(result.output.contains("Prompt 5 of 5 sent to LLM"))
      #expect(reportMessage.hasPrefix(prefix))
      #expect(FileManager.default.fileExists(atPath: reportPath))
    }
  }

  @Test("explicit provider selects its model configuration")
  func selectsExplicitProvider() async throws {
    try await withFixture { directory, file in
      let provider = RecordingProvider()
      let result = await run(
        directory: directory,
        file: file,
        review: nil,
        prompt: "baseline",
        providerID: "cloud",
        provider: provider
      )
      let report = try decode(result)

      #expect(result.exitStatus == .success)
      #expect(report.analysis.executionMetadata.modelID == "cloud-model")
    }
  }

  @Test("provider failure returns exit status 3 and a diagnostic")
  func reportsProviderFailure() async throws {
    try await withFixture { directory, file in
      let result = await run(
        directory: directory,
        file: file,
        review: nil,
        prompt: "baseline",
        provider: FailingProvider()
      )
      let report = try decode(result)

      #expect(result.exitStatus == .executionFailure)
      #expect(
        report.analysis.diagnostics.map(\.code)
          == ["ARCA-LLM-ANALYSIS-PROVIDER-FAILED"]
      )
    }
  }

  @Test("reports when ARCA starts waiting for the LLM response")
  func reportsLLMWaitProgress() async throws {
    try await withFixture { directory, file in
      let progress = ProgressRecorder()

      _ = await ArcaCommand.execute(
        arguments: [
          "--file", file.path,
          "--prompt", "baseline",
          "--format", "terminal",
        ],
        currentDirectory: directory.path,
        llmProvider: RecordingProvider(),
        progress: { progress.record($0) }
      )

      #expect(progress.messages == ["Waiting for the LLM response..."])
    }
  }

  private func run(
    directory: URL,
    file: URL,
    review: String?,
    prompt: String,
    providerID: String? = nil,
    provider: any LLMProvider
  ) async -> CommandResult {
    var arguments = ["--file", file.path]
    if let review {
      arguments += ["--review", review]
    }
    arguments += ["--prompt", prompt, "--format", "json"]
    if let providerID {
      arguments += ["--provider", providerID]
    }
    return await ArcaCommand.execute(
      arguments: arguments,
      currentDirectory: directory.path,
      llmProvider: provider
    )
  }

  private func decode(_ result: CommandResult) throws -> LLMIssueDetectionReport {
    let url = reportURL(from: result)
    return try JSONDecoder().decode(
      LLMIssueDetectionReport.self,
      from: Data(contentsOf: url)
    )
  }

  private func reportURL(from result: CommandResult) -> URL {
    let prefix = "JSON report written to: "
    let path = result.output.hasPrefix(prefix)
      ? String(result.output.dropFirst(prefix.count))
      : result.output
    return URL(fileURLWithPath: path)
  }

  private func runGit(_ arguments: [String], in directory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = directory
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
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
        "defaultProvider": "local",
        "providers": [
          {
            "id": "local",
            "baseURL": "http://127.0.0.1:1234",
            "modelID": "mock-model",
            "timeoutSeconds": 30,
            "temperature": 0,
            "seed": 7
          },
          {
            "id": "cloud",
            "baseURL": "https://api.openai.com",
            "modelID": "cloud-model",
            "timeoutSeconds": 60,
            "temperature": 0,
            "seed": 9
          }
        ]
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

private final class ProgressRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var recordedMessages: [String] = []

  var messages: [String] {
    lock.lock()
    defer { lock.unlock() }
    return recordedMessages
  }

  func record(_ message: String) {
    lock.lock()
    defer { lock.unlock() }
    recordedMessages.append(message)
  }
}

private struct FailingProvider: LLMProvider {
  let id = "failing"

  func submit(_ request: LLMRequest) async throws -> LLMResponse {
    throw ProviderFailure.unavailable
  }
}

private enum ProviderFailure: Error {
  case unavailable
}
