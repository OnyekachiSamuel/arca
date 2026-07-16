import Foundation
import Testing
@testable import ArcanCLI

@Suite("Arcan command")
struct ArcanCommandTests {
    @Test("review help matches the command snapshot")
    func reviewHelpSnapshot() async {
        let expected = """
        OVERVIEW: Review Swift code for anti-patterns and convention violations.

        USAGE: arcan review [options]

        OPTIONS:
          --file <path>           Review an explicit Swift file.
          --changed               Review changed Swift files in the Git repository.
          --debug                 Print loaded source and metadata.
          -h, --help              Show help information.
        """

        let result = await ArcanCommand.run(arguments: ["review", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.output == expected)
    }

    @Test("review supports the short help flag")
    func reviewShortHelp() async {
        let result = await ArcanCommand.run(arguments: ["review", "-h"])

        #expect(
            result == CommandResult(
                output: ArcanCommand.reviewHelp,
                exitCode: 0
            )
        )
    }

    @Test("review with a Swift file includes it in the request")
    func reviewFileBuildsRequest() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(to: file, atomically: true, encoding: .utf8)

            let result = await ArcanCommand.run(
                arguments: ["review", "--file", file.path]
            )

            #expect(result.exitCode == 0)
            #expect(result.reviewRequest?.selectedFiles == [file.path])
        }
    }

    @Test("review with a missing file returns a clear error")
    func reviewMissingFile() async throws {
        try await withTemporaryDirectory { directory in
            let path = directory.appendingPathComponent("Missing.swift").path

            let result = await ArcanCommand.run(
                arguments: ["review", "--file", path]
            )

            #expect(result.exitCode != 0)
            #expect(result.output == "Error: Swift file does not exist: \(path)")
            #expect(result.reviewRequest == nil)
        }
    }

    @Test("review debug mode prints loaded source and metadata")
    func reviewDebugOutput() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("Greeting.swift")
            let content = "let greeting = \"Hej 👋\""
            try content.write(to: file, atomically: true, encoding: .utf8)

            let result = await ArcanCommand.run(
                arguments: ["review", "--file", file.path, "--debug"]
            )

            let normalizedPath = file.standardizedFileURL.path
            #expect(result.exitCode == 0)
            #expect(
                result.output
                    == "Source: \(normalizedPath)\nLines: 1\n\n\(content)"
            )
        }
    }

    @Test("review changed selects current Swift changes")
    func reviewChangedBuildsRequest() async throws {
        try await withTemporaryDirectory { directory in
            try initializeGitRepository(at: directory)
            let file = directory.appendingPathComponent("Changed File.swift")
            try "struct ChangedFile {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(
                arguments: ["review", "--changed"],
                currentDirectory: directory.path
            )

            #expect(result.exitCode == 0)
            #expect(
                result.reviewRequest?.selectedFiles
                    == [file.standardizedFileURL.resolvingSymlinksInPath().path]
            )
            let change = try #require(result.reviewRequest?.changes.first)
            #expect(change.addedLineRanges.first?.startLine == 1)
            #expect(change.addedLineRanges.first?.endLine == 1)
        }
    }

    private func initializeGitRepository(at directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init", "--quiet"]
        process.currentDirectoryURL = directory
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    private func withTemporaryDirectory<Result>(
        _ body: (URL) async throws -> Result
    ) async throws -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory)
    }
}
