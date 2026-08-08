import ArcaDomain
import Testing
@testable import ArcaCLI

@Suite("LLM command parser")
struct LLMCommandParserTests {
    @Test("parses one explicit LLM prompt run")
    func parsesRun() throws {
        let options = try LLMCommandParser().parse(arguments: [
            "--file", "Example.swift",
            "--review", "god-object",
            "--prompt", "baseline",
            "--format", "json"
        ])

        #expect(options.filePath == "Example.swift")
        #expect(options.reviewType == .godObject)
        #expect(options.promptVariant == .baseline)
        #expect(options.outputFormat == .json)
    }

    @Test("terminal output is the default")
    func defaultsToTerminal() throws {
        let options = try LLMCommandParser().parse(arguments: [
            "--file", "Example.swift",
            "--review", "god-object",
            "--prompt", "guided"
        ])

        #expect(options.outputFormat == .terminal)
    }

    @Test("file, review, and prompt are required")
    func requiresExperimentalInputs() {
        expectError(.missingOption("--file"), arguments: [])
        expectError(
            .missingOption("--review"),
            arguments: ["--file", "Example.swift"]
        )
        expectError(
            .missingOption("--prompt"),
            arguments: [
                "--file", "Example.swift",
                "--review", "god-object"
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
                "--prompt", "both"
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
