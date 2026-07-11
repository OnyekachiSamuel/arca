import Foundation
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
          --file <path>           Review an explicit Swift file.
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

    @Test("review with a Swift file includes it in the request")
    func reviewFileBuildsRequest() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(to: file, atomically: true, encoding: .utf8)

            let result = ArcanCommand.run(
                arguments: ["review", "--file", file.path]
            )

            #expect(result.exitCode == 0)
            #expect(result.reviewRequest?.selectedFiles == [file.path])
        }
    }

    @Test("review with a missing file returns a clear error")
    func reviewMissingFile() throws {
        try withTemporaryDirectory { directory in
            let path = directory.appendingPathComponent("Missing.swift").path

            let result = ArcanCommand.run(
                arguments: ["review", "--file", path]
            )

            #expect(result.exitCode != 0)
            #expect(result.output == "Error: Swift file does not exist: \(path)")
            #expect(result.reviewRequest == nil)
        }
    }

    private func withTemporaryDirectory<Result>(
        _ body: (URL) throws -> Result
    ) throws -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        return try body(directory)
    }
}
