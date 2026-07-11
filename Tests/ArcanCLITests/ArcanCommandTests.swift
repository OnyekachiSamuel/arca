import Testing
@testable import ArcanCLI

@Suite("Arcan command")
struct ArcanCommandTests {
    @Test("review help matches the command snapshot")
    func reviewHelpSnapshot() {
        let expected = """
        OVERVIEW: Review Swift code for anti-patterns and convention violations.

        USAGE: arcan review [options]

        OPTIONS:
          -h, --help              Show help information.
        """

        let result = ArcanCommand.run(arguments: ["review", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.output == expected)
    }

    @Test("review supports the short help flag")
    func reviewShortHelp() {
        #expect(
            ArcanCommand.run(arguments: ["review", "-h"])
                == CommandResult(output: ArcanCommand.reviewHelp, exitCode: 0)
        )
    }
}
