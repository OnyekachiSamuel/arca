import ArcanAnalysis
import ArcanAnalyzers
import ArcanDomain
import ArcanProcess
import Foundation
import Testing

@Suite("SwiftLint analyzer")
struct SwiftLintAnalyzerTests {
    @Test("normalizes JSON violations and records tool metadata")
    func normalizesViolations() async throws {
        let executable = URL(fileURLWithPath: "/tools/swiftlint")
        let project = URL(fileURLWithPath: "/project", isDirectory: true)
        let runner = StubProcessRunner(results: [
            processResult(output: "0.63.2\n"),
            processResult(output: """
            [
              {
                "character": 12,
                "file": "/project/Sources/Zeta.swift",
                "line": 8,
                "reason": "Lines should not have trailing semicolons.",
                "rule_id": "trailing_semicolon",
                "severity": "Warning",
                "type": "Trailing Semicolon"
              },
              {
                "character": 5,
                "file": "/project/Sources/Alpha.swift",
                "line": 3,
                "reason": "Force casts should be avoided.",
                "rule_id": "force_cast",
                "severity": "Error",
                "type": "Force Cast"
              }
            ]
            """)
        ])
        let analyzer = SwiftLintAnalyzer(
            executableURL: executable,
            workingDirectoryURL: project,
            timeout: .seconds(10),
            processRunner: runner
        )
        let context = analysisContext(paths: [
            "/project/Sources/Zeta.swift",
            "/project/Sources/Alpha.swift"
        ])

        let result = try await analyzer.analyze(context: context)

        #expect(result.analyzerID == "swiftlint")
        #expect(result.tool == ToolMetadata(
            name: "SwiftLint",
            version: "0.63.2"
        ))
        #expect(result.findings.count == 2)
        let first = try #require(result.findings.first)
        #expect(first.ruleID == "swiftlint.force_cast")
        #expect(first.externalRuleID == "force_cast")
        #expect(first.title == "Force Cast")
        #expect(first.severity == .error)
        #expect(first.filePath == "/project/Sources/Alpha.swift")
        #expect(first.range == SourceRange(
            startLine: 3,
            startColumn: 5,
            endLine: 3,
            endColumn: 5
        ))
        #expect(first.explanation == "Force casts should be avoided.")
        #expect(first.evidence.isEmpty)
        #expect(first.suggestion == nil)

        let requests = await runner.recordedRequests
        #expect(requests == [
            ProcessRequest(
                executableURL: executable,
                arguments: ["version"],
                workingDirectoryURL: project,
                timeout: .seconds(10)
            ),
            ProcessRequest(
                executableURL: executable,
                arguments: [
                    "lint",
                    "--reporter", "json",
                    "--quiet",
                    "--force-exclude",
                    "/project/Sources/Alpha.swift",
                    "/project/Sources/Zeta.swift"
                ],
                workingDirectoryURL: project,
                timeout: .seconds(10)
            )
        ])
    }

    @Test("keeps valid findings returned with a non-zero status")
    func acceptsValidJSONForNonZeroStatus() async throws {
        let runner = StubProcessRunner(results: [
            processResult(output: "0.63.2"),
            processResult(
                output: """
                [{
                  "character": 1,
                  "file": "/project/App.swift",
                  "line": 1,
                  "reason": "Example violation.",
                  "rule_id": "example_rule",
                  "severity": "Error",
                  "type": "Example Rule"
                }]
                """,
                status: .exited(code: 2)
            )
        ])
        let analyzer = makeAnalyzer(processRunner: runner)

        let result = try await analyzer.analyze(
            context: analysisContext(paths: ["/project/App.swift"])
        )

        #expect(result.findings.map(\.externalRuleID) == ["example_rule"])
    }

    @Test("continues when the tool version is unavailable")
    func toleratesUnavailableVersion() async throws {
        let runner = StubProcessRunner(results: [
            processResult(
                error: "version unavailable",
                status: .exited(code: 1)
            ),
            processResult(output: "[]")
        ])
        let analyzer = makeAnalyzer(processRunner: runner)

        let result = try await analyzer.analyze(
            context: analysisContext(paths: ["/project/App.swift"])
        )

        #expect(result.tool == ToolMetadata(
            name: "SwiftLint",
            version: nil
        ))
        #expect(result.findings.isEmpty)
    }

    @Test("reports malformed SwiftLint JSON")
    func rejectsMalformedJSON() async {
        let runner = StubProcessRunner(results: [
            processResult(output: "0.63.2"),
            processResult(output: "not json")
        ])
        let analyzer = makeAnalyzer(processRunner: runner)

        await expectError(.invalidJSON) {
            _ = try await analyzer.analyze(
                context: analysisContext(paths: ["/project/App.swift"])
            )
        }
    }

    @Test("reports a SwiftLint timeout")
    func reportsTimeout() async {
        let runner = StubProcessRunner(results: [
            processResult(output: "0.63.2"),
            processResult(status: .timedOut)
        ])
        let analyzer = makeAnalyzer(processRunner: runner)

        await expectError(.timedOut) {
            _ = try await analyzer.analyze(
                context: analysisContext(paths: ["/project/App.swift"])
            )
        }
    }

    @Test("optional policy skips SwiftLint when it disappears before execution")
    func optionalRuntimeUnavailabilityIsSkipped() async throws {
        let path = "/tools/swiftlint"
        let analyzer = SwiftLintAnalyzer(
            executableURL: URL(fileURLWithPath: path),
            workingDirectoryURL: URL(
                fileURLWithPath: "/project",
                isDirectory: true
            ),
            availabilityPolicy: .optional,
            processRunner: FailingProcessRunner(
                error: .executableNotFound(path: path)
            )
        )

        let result = try await analyzer.analyze(
            context: analysisContext(paths: ["/project/App.swift"])
        )

        #expect(result.executionStatus == .skipped)
        #expect(
            result.diagnostics.map(\.code)
                == ["ARCAN-SWIFTLINT-UNAVAILABLE"]
        )
    }

    @Test("real SwiftLint reports the fixture violation when configured")
    func runsRealSwiftLintWhenConfigured() async throws {
        guard let executablePath = ProcessInfo.processInfo.environment[
            "ARCAN_SWIFTLINT_EXECUTABLE"
        ] else {
            return
        }
        let executable = URL(fileURLWithPath: executablePath)
        let fixture = try #require(
            Bundle.module.url(
                forResource: "StyleViolation",
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )
        let analyzer = SwiftLintAnalyzer(
            executableURL: executable,
            workingDirectoryURL: fixture.deletingLastPathComponent(),
            timeout: .seconds(30),
            processRunner: ProcessRunner(
                approvedExecutableURLs: [executable]
            )
        )

        let result = try await analyzer.analyze(
            context: analysisContext(paths: [fixture.path])
        )

        #expect(
            result.findings.contains {
                $0.externalRuleID == "trailing_semicolon"
            }
        )
        #expect(result.tool?.version?.isEmpty == false)
    }

    @Test("locates an explicitly configured SwiftLint executable")
    func locatesConfiguredExecutable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("swiftlint")
        try Data().write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        let locator = SwiftLintExecutableLocator(environment: [
            "ARCAN_SWIFTLINT_EXECUTABLE": executable.path,
            "PATH": ""
        ])

        let result = locator.locate()

        #expect(result == .available(executable.standardizedFileURL))
    }

    @Test("locates SwiftLint on PATH")
    func locatesExecutableOnPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("swiftlint")
        try Data().write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        let locator = SwiftLintExecutableLocator(environment: [
            "PATH": directory.path
        ])

        let result = locator.locate()

        #expect(result == .available(executable.standardizedFileURL))
    }

    @Test("an invalid configured path is reported without PATH fallback")
    func configuredPathIsAuthoritative() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let pathExecutable = directory.appendingPathComponent("swiftlint")
        try Data().write(to: pathExecutable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: pathExecutable.path
        )
        let configuredPath = directory
            .appendingPathComponent("missing-swiftlint").path
        let locator = SwiftLintExecutableLocator(environment: [
            "ARCAN_SWIFTLINT_EXECUTABLE": configuredPath,
            "PATH": directory.path
        ])

        let result = locator.locate()

        #expect(
            result == .unavailable(
                .configuredExecutableNotFound(configuredPath)
            )
        )
    }

    @Test("optional unavailable SwiftLint returns a skipped result")
    func optionalUnavailableSwiftLintIsSkipped() async throws {
        let analyzer = UnavailableSwiftLintAnalyzer(
            reason: .executableNotFound,
            policy: .optional
        )

        let result = try await analyzer.analyze(
            context: analysisContext(paths: ["/project/App.swift"])
        )

        #expect(result.analyzerID == "swiftlint")
        #expect(result.executionStatus == .skipped)
        #expect(result.findings.isEmpty)
        #expect(result.tool == ToolMetadata(name: "SwiftLint"))
        #expect(
            result.diagnostics.map(\.code)
                == ["ARCAN-SWIFTLINT-UNAVAILABLE"]
        )
        #expect(result.diagnostics.first?.severity == .warning)
    }

    @Test("required unavailable SwiftLint fails")
    func requiredUnavailableSwiftLintFails() async {
        let analyzer = UnavailableSwiftLintAnalyzer(
            reason: .executableNotFound,
            policy: .required
        )

        do {
            _ = try await analyzer.analyze(
                context: analysisContext(paths: ["/project/App.swift"])
            )
            Issue.record("Expected required SwiftLint to fail.")
        } catch let error as SwiftLintAvailabilityError {
            #expect(error == .requiredToolUnavailable(.executableNotFound))
            #expect(error.errorDescription?.contains("required") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makeAnalyzer(
        processRunner: any ProcessRunning
    ) -> SwiftLintAnalyzer {
        SwiftLintAnalyzer(
            executableURL: URL(fileURLWithPath: "/tools/swiftlint"),
            workingDirectoryURL: URL(
                fileURLWithPath: "/project",
                isDirectory: true
            ),
            timeout: .seconds(10),
            processRunner: processRunner
        )
    }

    private func analysisContext(paths: [String]) -> AnalysisContext {
        let sourceFiles = paths.map {
            SourceFile(path: $0, content: "", lineCount: 0)
        }
        return AnalysisContext(
            request: ReviewRequest(
                id: UUID(),
                selectedFiles: paths,
                selectedReviewTypes: [.style]
            ),
            sourceFiles: sourceFiles
        )
    }

    private func processResult(
        output: String = "",
        error: String = "",
        status: ProcessStatus = .exited(code: 0)
    ) -> ProcessResult {
        ProcessResult(
            standardOutput: Data(output.utf8),
            standardError: Data(error.utf8),
            status: status,
            durationMilliseconds: 1
        )
    }

    private func expectError(
        _ expected: SwiftLintAnalyzerError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected SwiftLint analysis to fail.")
        } catch let error as SwiftLintAnalyzerError {
            #expect(error == expected)
            #expect(error.errorDescription?.isEmpty == false)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private actor StubProcessRunner: ProcessRunning {
    private var results: [ProcessResult]
    private(set) var recordedRequests: [ProcessRequest] = []

    init(results: [ProcessResult]) {
        self.results = results
    }

    func run(_ request: ProcessRequest) async throws -> ProcessResult {
        recordedRequests.append(request)
        guard !results.isEmpty else {
            throw StubProcessRunnerError.missingResult
        }
        return results.removeFirst()
    }
}

private enum StubProcessRunnerError: Error {
    case missingResult
}

private struct FailingProcessRunner: ProcessRunning {
    let error: ProcessExecutionError

    func run(_ request: ProcessRequest) async throws -> ProcessResult {
        throw error
    }
}
