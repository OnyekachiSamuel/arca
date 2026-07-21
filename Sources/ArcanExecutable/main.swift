import ArcanAnalyzers
import ArcanCLI
import Foundation

let result = await ArcanCommand.run(
    arguments: Array(CommandLine.arguments.dropFirst()),
    swiftLintAvailability: SwiftLintExecutableLocator().locate()
)
let stream: FileHandle
switch result.outputDestination {
case .standardOutput:
    stream = .standardOutput
case .standardError:
    stream = .standardError
}

if let data = (result.output + "\n").data(using: .utf8) {
    stream.write(data)
}

if result.exitCode != 0 {
    exit(result.exitCode)
}
