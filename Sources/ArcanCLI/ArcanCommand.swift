import ArcanDomain
import ArcanSource
import Foundation

public struct CommandResult: Equatable {
    public let output: String
    public let exitCode: Int32
    public let reviewRequest: ReviewRequest?

    init(
        output: String,
        exitCode: Int32,
        reviewRequest: ReviewRequest? = nil
    ) {
        self.output = output
        self.exitCode = exitCode
        self.reviewRequest = reviewRequest
    }
}

public enum ArcanCommand {
    static let reviewHelp = """
    OVERVIEW: Review Swift code for anti-patterns and convention violations.

    USAGE: arcan review [options]

    OPTIONS:
      --file <path>           Review an explicit Swift file.
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
        if arguments.count == 3,
           arguments[0] == "review",
           arguments[1] == "--file" {
            return reviewFile(at: arguments[2])
        }

        switch arguments {
        case [], ["--help"], ["-h"]:
            return CommandResult(output: rootHelp, exitCode: 0)
        case ["review", "--help"], ["review", "-h"]:
            return CommandResult(output: reviewHelp, exitCode: 0)
        case ["review"]:
            return CommandResult(
                output: "No Swift file selected. Run 'arcan review --help' for usage.",
                exitCode: 0
            )
        default:
            return CommandResult(
                output: "Error: unknown command or option. Run 'arcan --help' for usage.",
                exitCode: 64
            )
        }
    }

    private static func reviewFile(at path: String) -> CommandResult {
        do {
            let selectedFile = try ExplicitSwiftFileSelector().select(path: path)
            let request = ReviewRequest(
                id: UUID(),
                selectedFiles: [selectedFile]
            )
            return CommandResult(
                output: "Selected Swift file: \(selectedFile)",
                exitCode: 0,
                reviewRequest: request
            )
        } catch let error as SourceSelectionError {
            return CommandResult(
                output: "Error: \(error.localizedDescription)",
                exitCode: 64
            )
        } catch {
            return CommandResult(
                output: "Error: Unable to select Swift file: \(path)",
                exitCode: 64
            )
        }
    }
}
