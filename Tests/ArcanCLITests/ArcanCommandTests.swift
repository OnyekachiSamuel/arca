import ArcanDomain
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
          --review <type>         Select a review; repeatable. Values: god-object, style, all.
          --format <format>       Select output format. Values: terminal, json.
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
            #expect(result.output.hasPrefix("ARCAN Review Report"))
            #expect(
                result.reviewRequest?.selectedReviewTypes
                    == [.godObject, .style]
            )
            #expect(result.output.contains("1 analyzer skipped"))
        }
    }

    @Test("review JSON format returns a decodable report without decoration")
    func reviewReturnsJSON() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(arguments: [
                "review",
                "--file", file.path,
                "--format", "json"
            ])
            let report = try JSONDecoder().decode(
                ReviewReport.self,
                from: Data(result.output.utf8)
            )

            #expect(result.exitCode == 0)
            #expect(
                report.schemaVersion == ReviewReport.currentSchemaVersion
            )
            #expect(
                report.analyzerResults.map(\.analyzerID)
                    == ["god-object", "swiftlint"]
            )
            #expect(
                report.analyzerResults.map(\.executionStatus)
                    == [.completed, .skipped]
            )
            #expect(!result.output.contains("ARCAN Review Report"))
            #expect(!result.output.contains("\u{001B}["))
        }
    }

    @Test("style review executes SwiftLint and returns normalized findings")
    func reviewExecutesSwiftLint() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "let value = 1;".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
            let executable = directory.appendingPathComponent("swiftlint")
            try """
            #!/bin/sh
            if [ "$1" = "version" ]; then
              printf 'test-version\\n'
              exit 0
            fi
            printf '[{"character":14,"file":"\(file.path)","line":1,"reason":"Unneeded semicolon.","rule_id":"trailing_semicolon","severity":"Warning","type":"Trailing Semicolon"}]'
            """.write(
                to: executable,
                atomically: true,
                encoding: .utf8
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executable.path
            )

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--file", file.path,
                    "--review", "style",
                    "--format", "json"
                ],
                swiftLintAvailability: .available(executable)
            )
            let report = try JSONDecoder().decode(
                ReviewReport.self,
                from: Data(result.output.utf8)
            )
            let analyzerResult = try #require(
                report.analyzerResults.first
            )
            let finding = try #require(analyzerResult.findings.first)

            #expect(result.exitCode == 0)
            #expect(
                result.reviewRequest?.selectedReviewTypes == [.style]
            )
            #expect(analyzerResult.analyzerID == "swiftlint")
            #expect(analyzerResult.tool?.version == "test-version")
            #expect(finding.ruleID == "swiftlint.trailing_semicolon")
            #expect(finding.externalRuleID == "trailing_semicolon")
        }
    }

    @Test("unsupported output format returns a clear error")
    func unsupportedOutputFormatReturnsError() async {
        let result = await ArcanCommand.run(arguments: [
            "review",
            "--format", "xml"
        ])

        #expect(result.exitCode == 64)
        #expect(
            result.output
                == "Error: Unsupported output format 'xml'. Available values: terminal, json."
        )
    }

    @Test("output format may only be specified once")
    func repeatedOutputFormatReturnsError() async {
        let result = await ArcanCommand.run(arguments: [
            "review",
            "--format", "json",
            "--format", "json"
        ])

        #expect(result.exitCode == 64)
        #expect(
            result.output
                == "Error: Option '--format' may only be specified once."
        )
    }

    @Test("JSON output cannot be combined with debug output")
    func jsonAndDebugReturnError() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(arguments: [
                "review",
                "--file", file.path,
                "--format", "json",
                "--debug"
            ])

            #expect(result.exitCode == 64)
            #expect(
                result.output
                    == "Error: Options '--debug' and '--format json' cannot be used together."
            )
        }
    }

    @Test("review accepts an explicit God Object review type")
    func reviewAcceptsGodObjectType() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(arguments: [
                "review",
                "--review", "god-object",
                "--file", file.path
            ])

            #expect(result.exitCode == 0)
            #expect(
                result.reviewRequest?.selectedReviewTypes == [.godObject]
            )
        }
    }

    @Test("review all resolves to every registered review type")
    func reviewAcceptsAllTypes() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(arguments: [
                "review",
                "--file", file.path,
                "--review", "all"
            ])

            #expect(result.exitCode == 0)
            #expect(
                result.reviewRequest?.selectedReviewTypes
                    == [.godObject, .style]
            )
        }
    }

    @Test("repeated review types are deduplicated")
    func repeatedReviewTypesAreDeduplicated() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(arguments: [
                "review",
                "--file", file.path,
                "--review", "god-object",
                "--review", "god-object"
            ])

            #expect(result.exitCode == 0)
            #expect(
                result.reviewRequest?.selectedReviewTypes == [.godObject]
            )
        }
    }

    @Test("all takes precedence when review types are repeated")
    func allTakesPrecedence() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(arguments: [
                "review",
                "--file", file.path,
                "--review", "god-object",
                "--review", "all"
            ])

            #expect(result.exitCode == 0)
            #expect(
                result.reviewRequest?.selectedReviewTypes
                    == [.godObject, .style]
            )
        }
    }

    @Test("unsupported review type returns a clear error")
    func unsupportedReviewTypeReturnsError() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(arguments: [
                "review",
                "--file", file.path,
                "--review", "security"
            ])

            #expect(result.exitCode == 64)
            #expect(
                result.output
                    == "Error: Unsupported review type 'security'."
            )
            #expect(result.reviewRequest == nil)
        }
    }

    @Test("optional unavailable SwiftLint returns a skipped style result")
    func optionalUnavailableSwiftLintIsSkipped() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(arguments: [
                "review",
                "--file", file.path,
                "--review", "style"
            ])

            #expect(result.exitCode == 0)
            #expect(
                result.reviewRequest?.selectedReviewTypes == [.style]
            )
            #expect(result.output.contains("0 findings"))
            #expect(result.output.contains("1 analyzer skipped"))
            #expect(
                result.output.contains("ARCAN-SWIFTLINT-UNAVAILABLE")
            )
        }
    }

    @Test("optional unavailable SwiftLint is explicit in JSON output")
    func optionalUnavailableSwiftLintIsJSONDiagnostic() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(arguments: [
                "review",
                "--file", file.path,
                "--review", "style",
                "--format", "json"
            ])
            let report = try JSONDecoder().decode(
                ReviewReport.self,
                from: Data(result.output.utf8)
            )
            let analyzerResult = try #require(
                report.analyzerResults.first
            )

            #expect(result.exitCode == 0)
            #expect(analyzerResult.executionStatus == .skipped)
            #expect(analyzerResult.findings.isEmpty)
            #expect(
                analyzerResult.diagnostics.map(\.code)
                    == ["ARCAN-SWIFTLINT-UNAVAILABLE"]
            )
        }
    }

    @Test("required unavailable SwiftLint fails with unavailable exit code")
    func requiredUnavailableSwiftLintFails() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
            try """
            {
              "schemaVersion": 1,
              "swiftLint": {
                "availability": "required"
              }
            }
            """.write(
                to: directory.appendingPathComponent(".arcan.json"),
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--file", file.path,
                    "--review", "style"
                ],
                currentDirectory: directory.path
            )

            #expect(result.exitCode == 69)
            #expect(result.output == "Error: SwiftLint is required but unavailable: SwiftLint executable was not found. Install SwiftLint or set ARCAN_SWIFTLINT_EXECUTABLE.")
            #expect(result.reviewRequest == nil)
        }
    }

    @Test("required SwiftLint does not block an unselected review")
    func requiredSwiftLintDoesNotBlockGodObjectReview() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
            try """
            {
              "schemaVersion": 1,
              "swiftLint": {
                "availability": "required"
              }
            }
            """.write(
                to: directory.appendingPathComponent(".arcan.json"),
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--file", file.path,
                    "--review", "god-object"
                ],
                currentDirectory: directory.path
            )

            #expect(result.exitCode == 0)
            #expect(
                result.reviewRequest?.selectedReviewTypes == [.godObject]
            )
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

    @Test("review uses configured God Object thresholds from repository root")
    func reviewUsesRepositoryConfiguration() async throws {
        try await withTemporaryDirectory { repository in
            try initializeGitRepository(at: repository)
            let sources = repository.appendingPathComponent(
                "Sources",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: sources,
                withIntermediateDirectories: true
            )
            let file = sources.appendingPathComponent("LargeType.swift")
            try """
            class LargeType {
                func first() {}
                func second() {}
            }
            """.write(to: file, atomically: true, encoding: .utf8)
            try """
            {
              "schemaVersion": 1,
              "godObject": {
                "maximumLines": 3,
                "maximumMethods": 1
              }
            }
            """.write(
                to: repository.appendingPathComponent(".arcan.json"),
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(
                arguments: ["review", "--file", file.path],
                currentDirectory: sources.path
            )

            #expect(result.exitCode == 0)
            #expect(result.output.contains("ARCAN-GOD-001"))
            #expect(
                result.reviewRequest?
                    .configuration
                    .godObjectThresholds
                    .maximumLines == 3
            )
        }
    }

    @Test("review reports invalid configuration")
    func reviewReportsInvalidConfiguration() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
            try """
            {
              "schemaVersion": 99
            }
            """.write(
                to: directory.appendingPathComponent(".arcan.json"),
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(
                arguments: ["review", "--file", file.path],
                currentDirectory: directory.path
            )

            #expect(result.exitCode == 64)
            #expect(
                result.output
                    == "Error: Unsupported configuration schema version: 99. Supported version: 1."
            )
            #expect(result.reviewRequest == nil)
        }
    }

    @Test("help remains available when configuration is invalid")
    func helpDoesNotLoadConfiguration() async throws {
        try await withTemporaryDirectory { directory in
            try "not json".write(
                to: directory.appendingPathComponent(".arcan.json"),
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(
                arguments: ["review", "--help"],
                currentDirectory: directory.path
            )

            #expect(result.exitCode == 0)
            #expect(result.output == ArcanCommand.reviewHelp)
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
