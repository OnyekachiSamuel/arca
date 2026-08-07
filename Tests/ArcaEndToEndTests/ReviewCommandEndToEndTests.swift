import ArcaAnalyzers
@testable import ArcaCLI
import ArcaDomain
import ArcaLLM
import Foundation
import Testing

@Suite("arca review end to end")
struct ReviewCommandEndToEndTests {
    @Test("complete combined-analysis flow produces a categorized JSON report")
    func reviewsFixtureThroughCompleteCombinedPipeline() async throws {
        let fixture = try #require(
            Bundle.module.url(
                forResource: "LargeCoordinator",
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )

        try await withTemporaryDirectoryAsync { directory in
            try writeLLMConfiguration(to: directory)
            let provider = VerticalSliceLLMProvider(
                filePath: fixture.lastPathComponent
            )

            let result = await ArcaCommand.execute(
                arguments: [
                    "review",
                    "--file", fixture.path,
                    "--review", "god-object",
                    "--format", "json"
                ],
                currentDirectory: directory.path,
                swiftLintAvailability: .unavailable(.executableNotFound),
                llmProvider: provider
            )
            let report = try JSONDecoder().decode(
                CategorizedReviewReport.self,
                from: Data(result.output.utf8)
            )
            let prompts = await provider.prompts

            #expect(
                result.exitStatus == .findingsDetected,
                Comment(rawValue: result.output)
            )
            #expect(prompts.count == 2)
            #expect(prompts[0].contains("arca.code-analysis/v1"))
            #expect(prompts[1].contains("arca.issue-categorization/v1"))
            #expect(
                report.candidates.count == 2,
                Comment(rawValue: result.output)
            )
            let staticCandidate = try #require(
                report.candidates.first {
                    $0.sourceIdentifiers == ["god-object"]
                },
                Comment(rawValue: result.output)
            )
            let llmCandidate = try #require(
                report.candidates.first {
                    $0.sourceIdentifiers.first == "llm-code-analysis"
                },
                Comment(rawValue: result.output)
            )
            #expect(staticCandidate.ruleID == "ARCA-GOD-001")
            #expect(llmCandidate.ruleID == "ARCA-GOD-001")
            #expect(llmCandidate.sourceIdentifiers == [
                "llm-code-analysis",
                "llm-provider:vertical-slice-mock",
                "llm-model:vertical-slice-model"
            ])
            let finding = try #require(report.confirmedFindings.first)
            #expect(finding.ruleID == "ARCA-GOD-001")
            #expect(finding.candidateIDs == report.candidates.map(\.candidateID))
            #expect(finding.sources == [
                "god-object",
                "llm-code-analysis",
                "llm-provider:vertical-slice-mock",
                "llm-model:vertical-slice-model"
            ])
            #expect(
                report.categorizationSummary
                    == "Static and LLM analysis agree on a God Object issue."
            )
            #expect(report.counts.totalCandidates == 2)
            #expect(report.counts.confirmed == 2)
        }
    }

    @Test("compiled CLI reports the God Object rule and file location")
    func reviewsKnownGodObjectFixture() throws {
        let fixture = try #require(
            Bundle.module.url(
                forResource: "LargeCoordinator",
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )
        let result = try runArca(arguments: [
            "review",
            "--file", fixture.path,
            "--review", "god-object"
        ])
        let output = String(decoding: result.standardOutput, as: UTF8.self)
        let errorOutput = String(decoding: result.standardError, as: UTF8.self)
        let expectedPath = repositoryRelativePath(for: fixture)

        #expect(result.exitCode == 1, Comment(rawValue: errorOutput))
        #expect(result.standardError.isEmpty)
        #expect(output.contains("ARCA-GOD-001"))
        #expect(
            output.contains(
                "File: \(expectedPath):1:1-"
            )
        )
    }

    @Test("compiled CLI writes a decodable versioned JSON report")
    func exportsJSONReport() throws {
        let fixture = try #require(
            Bundle.module.url(
                forResource: "LargeCoordinator",
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )
        let result = try runArca(arguments: [
            "review",
            "--file", fixture.path,
            "--review", "god-object",
            "--format", "json"
        ])
        let report = try JSONDecoder().decode(
            ReviewAnalysisResult.self,
            from: result.standardOutput
        )
        let output = String(decoding: result.standardOutput, as: UTF8.self)
        let errorOutput = String(
            decoding: result.standardError,
            as: UTF8.self
        )
        let expectedPath = repositoryRelativePath(for: fixture)

        #expect(result.exitCode == 1, Comment(rawValue: errorOutput))
        #expect(result.standardError.isEmpty)
        #expect(
            report.schemaVersion == ReviewAnalysisResult.currentSchemaVersion
        )
        #expect(report.candidates.first?.ruleID == "ARCA-GOD-001")
        #expect(report.candidates.first?.filePath == expectedPath)
        #expect(report.candidates.first?.proposedCategory == .antiPattern)
        #expect(report.candidates.first?.sourceIdentifiers == ["god-object"])
        #expect(
            report.analyzerResults.first?.candidates.first?.sourceIdentifiers
                == ["god-object"]
        )
        #expect(
            report.candidates.first?.analyzerMetadata["typeName"]
                == .string("LargeCoordinator")
        )
        #expect(
            report.analyzerResults.first?.analyzerID == "god-object"
        )
        #expect(
            report.analyzerResults.first?.durationMilliseconds ?? -1 >= 0
        )
        #expect(!output.contains("ARCA Review Report"))
        #expect(!output.contains("\u{001B}["))
    }

    @Test("compiled CLI reports skipped style analysis when SwiftLint is missing")
    func reportsUnavailableSwiftLint() throws {
        let fixture = try #require(
            Bundle.module.url(
                forResource: "LargeCoordinator",
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )
        let result = try runArca(
            arguments: [
                "review",
                "--file", fixture.path,
                "--review", "style",
                "--format", "json"
            ],
            environment: [
                "ARCA_SWIFTLINT_EXECUTABLE":
                    "/definitely/missing/swiftlint"
            ]
        )
        let report = try JSONDecoder().decode(
            ReviewAnalysisResult.self,
            from: result.standardOutput
        )
        let analyzerResult = try #require(
            report.analyzerResults.first
        )

        #expect(result.exitCode == 0)
        #expect(result.standardError.isEmpty)
        #expect(analyzerResult.analyzerID == "swiftlint")
        #expect(analyzerResult.executionStatus == .skipped)
        #expect(
            analyzerResult.diagnostics.map(\.code)
                == ["ARCA-SWIFTLINT-UNAVAILABLE"]
        )
    }

    @Test("compiled CLI returns success for a clean review")
    func returnsSuccessForCleanReview() throws {
        let fixture = try #require(
            Bundle.module.url(
                forResource: "SmallType",
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )
        let result = try runArca(arguments: [
            "review",
            "--file", fixture.path,
            "--review", "god-object"
        ])

        #expect(result.exitCode == 0)
        #expect(
            String(decoding: result.standardOutput, as: UTF8.self)
                .contains("0 candidates")
        )
        #expect(result.standardError.isEmpty)
    }

    @Test("compiled CLI returns input error for an invalid option")
    func returnsInputErrorForInvalidOption() throws {
        let result = try runArca(arguments: ["review", "--unknown"])

        #expect(result.exitCode == 2)
        #expect(result.standardOutput.isEmpty)
        #expect(
            String(decoding: result.standardError, as: UTF8.self)
                .lowercased()
                .contains("unknown review option")
        )
    }

    @Test("compiled CLI returns execution failure when required SwiftLint is missing")
    func returnsExecutionFailureForRequiredTool() throws {
        try withTemporaryDirectory { directory in
            let source = directory.appendingPathComponent("App.swift")
            try "struct App {}".write(
                to: source,
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
                to: directory.appendingPathComponent(".arca.json"),
                atomically: true,
                encoding: .utf8
            )

            let result = try runArca(
                arguments: [
                    "review",
                    "--file", source.path,
                    "--review", "style"
                ],
                environment: [
                    "ARCA_SWIFTLINT_EXECUTABLE":
                        "/definitely/missing/swiftlint"
                ],
                currentDirectoryURL: directory
            )

            #expect(result.exitCode == 3)
            #expect(result.standardOutput.isEmpty)
            #expect(
                String(decoding: result.standardError, as: UTF8.self)
                    .contains("SwiftLint is required but unavailable")
            )
        }
    }

    private func runArca(
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectoryURL: URL? = nil
    ) throws -> SubprocessResult {
        let isolatedDirectory: URL?
        if currentDirectoryURL == nil {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            isolatedDirectory = directory
        } else {
            isolatedDirectory = nil
        }
        defer {
            if let isolatedDirectory {
                try? FileManager.default.removeItem(at: isolatedDirectory)
            }
        }

        let process = Process()
        process.executableURL = try arcaExecutableURL()
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL ?? isolatedDirectory
        process.environment = ProcessInfo.processInfo.environment.merging(
            environment,
            uniquingKeysWith: { _, override in override }
        )

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        return SubprocessResult(
            exitCode: process.terminationStatus,
            standardOutput:
                standardOutput.fileHandleForReading.readDataToEndOfFile(),
            standardError:
                standardError.fileHandleForReading.readDataToEndOfFile()
        )
    }

    private func repositoryRelativePath(for file: URL) -> String {
        file.standardizedFileURL.resolvingSymlinksInPath().path
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

    private func withTemporaryDirectoryAsync<Result>(
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

    private func writeLLMConfiguration(to directory: URL) throws {
        try """
        {
          "schemaVersion": 1,
          "llm": {
            "providerID": "vertical-slice-mock",
            "baseURL": "http://127.0.0.1:11434",
            "modelID": "vertical-slice-model",
            "timeoutSeconds": 30,
            "temperature": 0,
            "seed": 44
          }
        }
        """.write(
            to: directory.appendingPathComponent(".arca.json"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func arcaExecutableURL() throws -> URL {
        var packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()

        for _ in 0..<8 {
            let manifest = packageRoot.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: manifest.path) {
                break
            }
            packageRoot.deleteLastPathComponent()
        }

        let buildDirectory = packageRoot.appendingPathComponent(".build")
        let files = FileManager.default.enumerator(
            at: buildDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        while let candidate = files?.nextObject() as? URL {
            if candidate.lastPathComponent == "arca",
               !candidate.path.contains("/checkouts/"),
               FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw EndToEndTestError.executableNotFound
    }
}

private actor VerticalSliceLLMProvider: LLMProvider {
    nonisolated let id = "vertical-slice-mock"
    private let filePath: String
    private(set) var prompts: [String] = []

    init(filePath: String) {
        self.filePath = filePath
    }

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        prompts.append(request.prompt)

        let text: String
        if request.prompt.contains("arca.code-analysis/v1") {
            text = """
            {"findings":[{"ruleID":"ARCA-GOD-001","filePath":"\(filePath)","explanation":"The coordinator owns too many responsibilities.","severity":"warning","startLine":1,"endLine":1,"evidence":[{"description":"The type combines extensive state and behavior.","startLine":1,"endLine":1,"excerpt":"final class LargeCoordinator {"}]}]}
            """
        } else {
            let candidateIDs = candidateIDs(in: request.prompt)
            let encodedIDs = candidateIDs.map { "\"\($0)\"" }
                .joined(separator: ",")
            text = """
            {"summary":"Static and LLM analysis agree on a God Object issue.","decisions":[{"candidateIDs":[\(encodedIDs)],"assessment":"confirmed","category":"antiPattern","severity":"warning","canonicalRuleID":"ARCA-GOD-001","title":"God Object candidate","rationale":"Both analyzers identify excessive responsibilities in the same type."}]}
            """
        }

        return LLMResponse(
            text: text,
            usage: LLMUsageMetadata(
                inputTokens: 40,
                outputTokens: 20,
                totalTokens: 60
            ),
            durationMilliseconds: 5
        )
    }

    private func candidateIDs(in prompt: String) -> [String] {
        let expression = try! NSRegularExpression(
            pattern: #""candidateID"\s*:\s*"([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})""#
        )
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        var encountered: Set<String> = []
        return expression.matches(in: prompt, range: range).compactMap {
            guard let matchRange = Range($0.range(at: 1), in: prompt) else {
                return nil
            }
            let candidateID = String(prompt[matchRange])
            return encountered.insert(candidateID).inserted
                ? candidateID
                : nil
        }
    }
}

private struct SubprocessResult {
    let exitCode: Int32
    let standardOutput: Data
    let standardError: Data
}

private enum EndToEndTestError: Error {
    case executableNotFound
}
