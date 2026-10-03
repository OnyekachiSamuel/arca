import ArcaCLI
import Foundation

let result = await ArcaCommand.run(
    arguments: Array(CommandLine.arguments.dropFirst()),
    progress: { message in
        guard let data = (message + "\n").data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
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
