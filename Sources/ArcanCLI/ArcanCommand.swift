public struct CommandResult: Equatable {
    public let output: String
    public let exitCode: Int32

    init(output: String, exitCode: Int32) {
        self.output = output
        self.exitCode = exitCode
    }
}

public enum ArcanCommand {
    static let reviewHelp = """
    OVERVIEW: Review Swift code for anti-patterns and convention violations.

    USAGE: arcan review [options]

    OPTIONS:
      -h, --help              Show help information.
    """

    static let rootHelp = """
    OVERVIEW: A code review tool for Swift.

    USAGE: arcan <command>

    COMMANDS:
      review                  Review Swift code.

    OPTIONS:
      -h, --help              Show help information.
    """

    public static func run(arguments: [String]) -> CommandResult {
        switch arguments {
        case [], ["--help"], ["-h"]:
            return CommandResult(output: rootHelp, exitCode: 0)
        case ["review", "--help"], ["review", "-h"]:
            return CommandResult(output: reviewHelp, exitCode: 0)
        case ["review"]:
            return CommandResult(
                output: "No review options are available yet. Run 'arcan review --help' for usage.",
                exitCode: 0
            )
        default:
            return CommandResult(
                output: "Error: unknown command or option. Run 'arcan --help' for usage.",
                exitCode: 64
            )
        }
    }
}
