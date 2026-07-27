import ArcanDomain
import Foundation
import Testing

@Suite("arcan review end to end")
struct ReviewCommandEndToEndTests {
    @Test("compiled CLI reports the God Object rule and file location")
    func reviewsKnownGodObjectFixture() throws {
        let fixture = try #require(
            Bundle.module.url(
                forResource: "LargeCoordinator",
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )
        let result = try runArcan(arguments: [
            "review",
            "--file", fixture.path,
            "--review", "god-object"
        ])
        let output = String(decoding: result.standardOutput, as: UTF8.self)
        let errorOutput = String(decoding: result.standardError, as: UTF8.self)
        let expectedPath = repositoryRelativePath(for: fixture)

        #expect(result.exitCode == 1, Comment(rawValue: errorOutput))
        #expect(result.standardError.isEmpty)
        #expect(output.contains("ARCAN-GOD-001"))
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
        let result = try runArcan(arguments: [
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
        #expect(report.candidates.first?.ruleID == "ARCAN-GOD-001")
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
        #expect(!output.contains("ARCAN Review Report"))
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
        let result = try runArcan(
            arguments: [
                "review",
                "--file", fixture.path,
                "--review", "style",
                "--format", "json"
            ],
            environment: [
                "ARCAN_SWIFTLINT_EXECUTABLE":
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
                == ["ARCAN-SWIFTLINT-UNAVAILABLE"]
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
        let result = try runArcan(arguments: [
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
        let result = try runArcan(arguments: ["review", "--unknown"])

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
                to: directory.appendingPathComponent(".arcan.json"),
                atomically: true,
                encoding: .utf8
            )

            let result = try runArcan(
                arguments: [
                    "review",
                    "--file", source.path,
                    "--review", "style"
                ],
                environment: [
                    "ARCAN_SWIFTLINT_EXECUTABLE":
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

    private func runArcan(
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectoryURL: URL? = nil
    ) throws -> SubprocessResult {
        let process = Process()
        process.executableURL = try arcanExecutableURL()
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
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
        let repository = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        ).standardizedFileURL.resolvingSymlinksInPath()
        let normalizedFile = file.standardizedFileURL.resolvingSymlinksInPath()
        let repositoryComponents = repository.pathComponents
        let fileComponents = normalizedFile.pathComponents
        #expect(fileComponents.starts(with: repositoryComponents))
        return fileComponents
            .dropFirst(repositoryComponents.count)
            .joined(separator: "/")
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

    private func arcanExecutableURL() throws -> URL {
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
            if candidate.lastPathComponent == "arcan",
               !candidate.path.contains("/checkouts/"),
               FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw EndToEndTestError.executableNotFound
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
