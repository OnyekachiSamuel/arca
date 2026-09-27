import ArcaDomain
import Testing

@testable import ArcaCLI

@Suite("LLM command parser")
struct LLMCommandParserTests {
  @Test("parses one explicit LLM prompt run")
  func parsesRun() throws {
    let options = try LLMCommandParser().parse(arguments: [
      "--file", "Example.swift",
      "--prompt", "baseline",
      "--provider", "openai",
      "--format", "json",
    ])

    #expect(options.filePath == "Example.swift")
    #expect(options.reviewType == nil)
    #expect(options.promptVariant == .baseline)
    #expect(options.providerID == "openai")
    #expect(options.outputFormat == .json)
  }

  @Test("terminal output is the default")
  func defaultsToTerminal() throws {
    let options = try LLMCommandParser().parse(arguments: [
      "--file", "Example.swift",
      "--review", "god-object",
      "--prompt", "guided",
    ])

    #expect(options.outputFormat == .terminal)
  }

  @Test("accepts every LLM-only MVP review type")
  func acceptsMVPReviewTypes() throws {
    let expected: [(String, ReviewType)] = [
      ("swift", .swift),
      ("swiftui", .swiftUI),
      ("tca", .tca),
      ("security", .security),
      ("god-object", .godObject),
      ("all", .all),
    ]

    for (value, reviewType) in expected {
      let options = try LLMCommandParser().parse(arguments: [
        "--file", "Example.swift",
        "--review", value,
        "--prompt", "guided",
      ])
      #expect(options.reviewType == reviewType)
    }
  }

  @Test("file and prompt are required, while guided also requires review")
  func requiresExperimentalInputs() {
    expectError(.missingOption("--file"), arguments: [])
    expectError(
      .missingOption("--prompt"),
      arguments: ["--file", "Example.swift"]
    )
    expectError(
      .missingReviewForGuidedPrompt,
      arguments: [
        "--file", "Example.swift",
        "--prompt", "guided",
      ]
    )
  }

  @Test("only baseline and guided prompt variants are accepted")
  func rejectsUnsupportedVariant() {
    expectError(
      .unsupportedPromptVariant("both"),
      arguments: [
        "--file", "Example.swift",
        "--review", "god-object",
        "--prompt", "both",
      ]
    )
  }

  @Test("baseline does not accept a review type")
  func rejectsReviewForBaseline() {
    expectError(
      .baselineDoesNotAcceptReview,
      arguments: [
        "--file", "Example.swift",
        "--review", "god-object",
        "--prompt", "baseline",
      ]
    )
  }

  private func expectError(
    _ expected: LLMCommandParsingError,
    arguments: [String]
  ) {
    do {
      _ = try LLMCommandParser().parse(arguments: arguments)
      Issue.record("Expected parsing to fail.")
    } catch let error as LLMCommandParsingError {
      #expect(error == expected)
    } catch {
      Issue.record("Unexpected parsing error: \(error)")
    }
  }
}
