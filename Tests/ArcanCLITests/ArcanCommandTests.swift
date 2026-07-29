import ArcanDomain
import ArcanLLM
import Foundation
import Testing
@testable import ArcanCLI

@Suite("Arcan command")
struct ArcanCommandTests {
    @Test("configured clean review returns a categorized report")
    func configuredCleanReviewReturnsStableReport() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("Small.swift")
            try "struct Small {}\n".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
            try writeLLMConfiguration(to: directory)
            let provider = CLINoFindingLLMProvider()

            let result = await ArcanCommand.execute(
                arguments: [
                    "review", "--file", file.path,
                    "--review", "god-object",
                    "--format", "json"
                ],
                currentDirectory: directory.path,
                swiftLintAvailability: .unavailable(.executableNotFound),
                llmProvider: provider
            )
            let report = try JSONDecoder().decode(
                ReviewReport.self,
                from: Data(result.output.utf8)
            )

            #expect(result.exitStatus == .success)
            #expect(await provider.requestCount == 1)
            #expect(report.candidates.isEmpty)
            #expect(report.counts.totalCandidates == 0)
            #expect(report.categorizationDecisions.isEmpty)
            #expect(
                report.categorizationSummary
                    == "No candidate findings were detected."
            )
            #expect(
                report.categorizationExecutionMetadata.requestCount == 0
            )
        }
    }

    @Test("configured file review runs detection, categorization, and reporting")
    func runsConfiguredFilePipeline() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {\n    let value = 1\n    func run() {}\n}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
            try writeLLMConfiguration(
                to: directory,
                godObjectThresholds: true
            )
            let provider = CLIPipelineLLMProvider(filePath: "App.swift")

            let result = await ArcanCommand.execute(
                arguments: [
                    "review", "--file", file.path,
                    "--review", "god-object",
                    "--format", "json"
                ],
                currentDirectory: directory.path,
                swiftLintAvailability: .unavailable(.executableNotFound),
                llmProvider: provider
            )
            let report = try JSONDecoder().decode(
                ReviewReport.self,
                from: Data(result.output.utf8)
            )
            let prompts = await provider.prompts

            #expect(
                result.exitStatus == .findingsDetected,
                Comment(rawValue: result.output)
            )
            #expect(prompts.count == 2)
            #expect(prompts[0].contains("arcan.code-analysis/v1"))
            #expect(prompts[1].contains("arcan.issue-categorization/v1"))
            #expect(report.candidates.count == 2)
            let confirmedFinding = try #require(
                report.confirmedFindings.first,
                Comment(rawValue: result.output)
            )
            #expect(
                confirmedFinding.candidateIDs
                    == report.candidates.map(\.candidateID)
            )
            #expect(confirmedFinding.sources == [
                "god-object",
                "llm-code-analysis",
                "llm-provider:mock-pipeline",
                "llm-model:mock-model"
            ])
            #expect(report.counts.totalCandidates == 2)
            #expect(report.counts.confirmed == 2)
            #expect(
                report.categorizationExecutionMetadata.providerID
                    == "mock-pipeline"
            )
        }
    }

    @Test("configured changed review runs the complete pipeline")
    func runsConfiguredChangedPipeline() async throws {
        try await withTemporaryDirectory { directory in
            try initializeGitRepository(at: directory)
            let file = directory.appendingPathComponent("Changed.swift")
            try "struct Changed {\n    let value = 1\n}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
            try writeLLMConfiguration(to: directory)
            let provider = CLIPipelineLLMProvider(filePath: "Changed.swift")

            let result = await ArcanCommand.execute(
                arguments: [
                    "review", "--changed",
                    "--review", "god-object",
                    "--format", "json"
                ],
                currentDirectory: directory.path,
                swiftLintAvailability: .unavailable(.executableNotFound),
                llmProvider: provider
            )
            let report = try JSONDecoder().decode(
                ReviewReport.self,
                from: Data(result.output.utf8)
            )
            let prompts = await provider.prompts

            #expect(result.exitStatus == .findingsDetected)
            #expect(result.reviewRequest?.selectedFiles == [
                file.standardizedFileURL.resolvingSymlinksInPath().path
            ])
            #expect(prompts.count == 2)
            #expect(prompts[0].contains(#""addedLineRanges""#))
            #expect(report.confirmedFindings.count == 1)
        }
    }

    @Test("configured provider failure returns a structured failed report")
    func reportsConfiguredProviderFailure() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("Large.swift")
            try "class Large {\n    var value = 1\n    func run() {}\n}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
            try writeLLMConfiguration(
                to: directory,
                godObjectThresholds: true
            )

            let result = await ArcanCommand.execute(
                arguments: [
                    "review", "--file", file.path,
                    "--review", "god-object",
                    "--format", "json"
                ],
                currentDirectory: directory.path,
                swiftLintAvailability: .unavailable(.executableNotFound),
                llmProvider: CLIFailingLLMProvider()
            )
            let report = try JSONDecoder().decode(
                ReviewReport.self,
                from: Data(result.output.utf8)
            )

            #expect(result.exitStatus == .executionFailure)
            #expect(report.candidates.count == 1)
            #expect(report.confirmedFindings.isEmpty)
            #expect(report.diagnostics.map(\.code).contains(
                "ARCAN-LLM-ANALYSIS-PROVIDER-FAILED"
            ))
            #expect(report.diagnostics.map(\.code).contains(
                "ARCAN-LLM-CATEGORIZATION-PROVIDER-FAILED"
            ))
        }
    }

    @Test("a rejected categorization keeps candidates but exits cleanly")
    func rejectedCategorizationIsNotAReportedFinding() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {\n    let value = 1\n}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
            try writeLLMConfiguration(to: directory)
            let provider = CLIPipelineLLMProvider(
                filePath: "App.swift",
                assessment: .rejected
            )

            let result = await ArcanCommand.execute(
                arguments: [
                    "review", "--file", file.path,
                    "--review", "god-object",
                    "--format", "json"
                ],
                currentDirectory: directory.path,
                swiftLintAvailability: .unavailable(.executableNotFound),
                llmProvider: provider
            )
            let report = try JSONDecoder().decode(
                ReviewReport.self,
                from: Data(result.output.utf8)
            )

            #expect(result.exitStatus == .success)
            #expect(report.candidates.count == 1)
            #expect(report.categorizationDecisions.first?.assessment == .rejected)
            #expect(report.confirmedFindings.isEmpty)
            #expect(report.uncertainFindings.isEmpty)
            #expect(report.counts.rejected == 1)
        }
    }

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

        EXIT STATUS:
          0  Review completed without findings.
          1  Review completed with findings.
          2  Invalid input or configuration.
          3  Analyzer or internal execution failure.
        """

        let result = await ArcanCommand.run(arguments: ["review", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.exitStatus == .success)
        #expect(result.outputDestination == .standardOutput)
        #expect(result.output == expected)
    }

    @Test("review supports the short help flag")
    func reviewShortHelp() async {
        let result = await ArcanCommand.run(arguments: ["review", "-h"])

        #expect(
            result == CommandResult(
                output: ArcanCommand.reviewHelp,
                exitStatus: .success
            )
        )
    }

    @Test("review without a source is an input error")
    func reviewWithoutSourceReturnsInputError() async {
        let result = await ArcanCommand.run(arguments: ["review"])

        #expect(result.exitStatus == .invalidInput)
        #expect(result.exitCode == 2)
        #expect(result.outputDestination == .standardError)
        #expect(
            result.output
                == "Error: No review source selected. Use --file or --changed."
        )
    }

    @Test("review with a Swift file includes it in the request")
    func reviewFileBuildsRequest() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(to: file, atomically: true, encoding: .utf8)

            let result = await ArcanCommand.run(
                arguments: ["review", "--file", file.path],
                currentDirectory: directory.path
            )

            #expect(result.exitCode == 0)
            #expect(result.exitStatus == .success)
            #expect(result.outputDestination == .standardOutput)
            #expect(result.reviewRequest?.selectedFiles == [file.path])
            #expect(result.reviewRequest?.repositoryRoot == nil)
            #expect(result.output.hasPrefix("ARCAN Review Analysis"))
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

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--file", file.path,
                    "--format", "json"
                ],
                currentDirectory: directory.path
            )
            let report = try JSONDecoder().decode(
                ReviewAnalysisResult.self,
                from: Data(result.output.utf8)
            )

            #expect(result.exitCode == 0)
            #expect(
                report.schemaVersion
                    == ReviewAnalysisResult.currentSchemaVersion
            )
            #expect(
                report.analyzerResults.map(\.analyzerID)
                    == ["god-object", "swiftlint"]
            )
            #expect(
                report.analyzerResults.map(\.executionStatus)
                    == [.completed, .skipped]
            )
            #expect(!result.output.contains("ARCAN Review Analysis"))
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
                currentDirectory: directory.path,
                swiftLintAvailability: .available(executable)
            )
            let report = try JSONDecoder().decode(
                ReviewAnalysisResult.self,
                from: Data(result.output.utf8)
            )
            let analyzerResult = try #require(
                report.analyzerResults.first
            )
            let candidate = try #require(analyzerResult.candidates.first)

            #expect(result.exitCode == 1)
            #expect(result.exitStatus == .findingsDetected)
            #expect(result.outputDestination == .standardOutput)
            #expect(
                result.reviewRequest?.selectedReviewTypes == [.style]
            )
            #expect(analyzerResult.analyzerID == "swiftlint")
            #expect(analyzerResult.tool?.version == "test-version")
            #expect(candidate.ruleID == "swiftlint.trailing_semicolon")
            #expect(
                candidate.analyzerMetadata["rule_id"]
                    == .string("trailing_semicolon")
            )
            #expect(candidate.sourceIdentifiers == ["swiftlint"])
            #expect(
                report.candidates.first?.sourceIdentifiers == ["swiftlint"]
            )
        }
    }

    @Test("unsupported output format returns a clear error")
    func unsupportedOutputFormatReturnsError() async {
        let result = await ArcanCommand.run(arguments: [
            "review",
            "--format", "xml"
        ])

        #expect(result.exitCode == 2)
        #expect(result.outputDestination == .standardError)
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

        #expect(result.exitCode == 2)
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

            #expect(result.exitCode == 2)
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

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--review", "god-object",
                    "--file", file.path
                ],
                currentDirectory: directory.path
            )

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

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--file", file.path,
                    "--review", "all"
                ],
                currentDirectory: directory.path
            )

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

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--file", file.path,
                    "--review", "god-object",
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

    @Test("all takes precedence when review types are repeated")
    func allTakesPrecedence() async throws {
        try await withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: file,
                atomically: true,
                encoding: .utf8
            )

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--file", file.path,
                    "--review", "god-object",
                    "--review", "all"
                ],
                currentDirectory: directory.path
            )

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

            #expect(result.exitCode == 2)
            #expect(
                result.output
                    == "Error: Unsupported review type 'security'."
            )
            #expect(result.reviewRequest == nil)
        }
    }

    @Test("LLM is an analyzer mechanism, not a review type")
    func generalLLMReviewTypeIsRejected() async throws {
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
                "--review", "general-llm"
            ])

            #expect(result.exitCode == 2)
            #expect(
                result.output
                    == "Error: Unsupported review type 'general-llm'."
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

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--file", file.path,
                    "--review", "style"
                ],
                currentDirectory: directory.path
            )

            #expect(result.exitCode == 0)
            #expect(
                result.reviewRequest?.selectedReviewTypes == [.style]
            )
            #expect(result.output.contains("0 candidates"))
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

            let result = await ArcanCommand.run(
                arguments: [
                    "review",
                    "--file", file.path,
                    "--review", "style",
                    "--format", "json"
                ],
                currentDirectory: directory.path
            )
            let report = try JSONDecoder().decode(
                ReviewAnalysisResult.self,
                from: Data(result.output.utf8)
            )
            let analyzerResult = try #require(
                report.analyzerResults.first
            )

            #expect(result.exitCode == 0)
            #expect(analyzerResult.executionStatus == .skipped)
            #expect(analyzerResult.candidates.isEmpty)
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

            #expect(result.exitCode == 3)
            #expect(result.exitStatus == .executionFailure)
            #expect(result.outputDestination == .standardError)
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

            #expect(result.exitCode == 2)
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
                result.reviewRequest?.repositoryRoot
                    == directory.standardizedFileURL
                        .resolvingSymlinksInPath().path
            )
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

            #expect(result.exitCode == 1)
            #expect(result.output.contains("ARCAN-GOD-001"))
            #expect(result.output.contains("File: Sources/LargeType.swift:"))
            #expect(
                result.reviewRequest?.repositoryRoot
                    == repository.standardizedFileURL
                        .resolvingSymlinksInPath().path
            )
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

            #expect(result.exitCode == 2)
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

    private func writeLLMConfiguration(
        to directory: URL,
        godObjectThresholds: Bool = false
    ) throws {
        let godObject = godObjectThresholds
            ? """
              ,"godObject": {
                "maximumLines": 1,
                "maximumMethods": 0,
                "maximumStoredProperties": 0,
                "minimumTriggeredSignals": 3
              }
            """
            : ""
        try """
        {
          "schemaVersion": 1\(godObject),
          "llm": {
            "providerID": "mock-pipeline",
            "baseURL": "http://127.0.0.1:11434",
            "modelID": "mock-model",
            "timeoutSeconds": 30,
            "temperature": 0,
            "seed": 7
          }
        }
        """.write(
            to: directory.appendingPathComponent(".arcan.json"),
            atomically: true,
            encoding: .utf8
        )
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

private actor CLINoFindingLLMProvider: LLMProvider {
    nonisolated let id = "mock-pipeline"
    private(set) var requestCount = 0

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        requestCount += 1
        return LLMResponse(
            text: #"{"findings":[]}"#,
            usage: LLMUsageMetadata(
                inputTokens: 10,
                outputTokens: 2,
                totalTokens: 12
            ),
            durationMilliseconds: 2
        )
    }
}

private actor CLIPipelineLLMProvider: LLMProvider {
    nonisolated let id = "mock-pipeline"
    private let filePath: String
    private let assessment: FindingAssessment
    private(set) var prompts: [String] = []

    init(
        filePath: String,
        assessment: FindingAssessment = .confirmed
    ) {
        self.filePath = filePath
        self.assessment = assessment
    }

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        prompts.append(request.prompt)
        if request.prompt.contains("arcan.code-analysis/v1") {
            return response(text: """
            {"findings":[{"ruleID":"ARCAN-GOD-001","filePath":"\(filePath)","explanation":"The type owns unrelated responsibilities.","severity":"warning","startLine":1,"endLine":3,"evidence":[{"description":"The type owns state directly.","startLine":2,"endLine":2,"excerpt":"    let value = 1"}]}]}
            """)
        }

        let ids = candidateIDs(in: request.prompt)
        let encodedIDs = ids.map { "\"\($0)\"" }.joined(separator: ",")
        return response(text: """
        {"summary":"The candidates were assessed.","decisions":[{"candidateIDs":[\(encodedIDs)],"assessment":"\(assessment.rawValue)","category":"antiPattern","severity":"warning","canonicalRuleID":"ARCAN-GOD-001","title":"God Object","rationale":"The supplied evidence was evaluated."}]}
        """)
    }

    private func candidateIDs(in prompt: String) -> [String] {
        let expression = try! NSRegularExpression(
            pattern: #""candidateID"\s*:\s*"([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})""#
        )
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        var encountered: Set<String> = []
        return expression.matches(in: prompt, range: range).compactMap {
            guard let matchRange = Range(
                $0.range(at: 1),
                in: prompt
            ) else {
                return nil
            }
            let value = String(prompt[matchRange])
            return encountered.insert(value).inserted ? value : nil
        }
    }

    private func response(text: String) -> LLMResponse {
        LLMResponse(
            text: text,
            usage: LLMUsageMetadata(
                inputTokens: 20,
                outputTokens: 10,
                totalTokens: 30
            ),
            durationMilliseconds: 4
        )
    }
}

private actor CLIRecordingLLMProvider: LLMProvider {
    let id = "mock"
    private let responseText: String
    private(set) var requestCount = 0

    init(responseText: String) {
        self.responseText = responseText
    }

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        requestCount += 1
        return LLMResponse(
            text: responseText,
            usage: LLMUsageMetadata(),
            durationMilliseconds: 1
        )
    }
}

private struct CLIFailingLLMProvider: LLMProvider {
    let id = "failing"

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        throw CLILLMProviderError.unavailable
    }
}

private enum CLILLMProviderError: Error {
    case unavailable
}
