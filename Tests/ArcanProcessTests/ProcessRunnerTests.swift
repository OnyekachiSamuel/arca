import ArcanProcess
import Foundation
import Testing

@Suite("Process runner")
struct ProcessRunnerTests {
    @Test("captures standard output, status and duration")
    func capturesSuccessfulExecution() async throws {
        let executable = URL(fileURLWithPath: "/usr/bin/printf")
        let runner = ProcessRunner(
            approvedExecutableURLs: [executable]
        )

        let result = try await runner.run(ProcessRequest(
            executableURL: executable,
            arguments: ["%s", "hello from ARCAN"],
            timeout: .seconds(2)
        ))

        #expect(result.standardOutput == Data("hello from ARCAN".utf8))
        #expect(result.standardError.isEmpty)
        #expect(result.status == .exited(code: 0))
        #expect(result.durationMilliseconds >= 0)
    }

    @Test("returns non-zero status and captures standard error")
    func capturesNonZeroExecution() async throws {
        let executable = URL(fileURLWithPath: "/bin/ls")
        let runner = ProcessRunner(
            approvedExecutableURLs: [executable]
        )

        let result = try await runner.run(ProcessRequest(
            executableURL: executable,
            arguments: [
                "/path-that-does-not-exist/arcan-process-test"
            ],
            timeout: .seconds(2)
        ))

        #expect(result.status == .exited(code: 1))
        #expect(result.standardOutput.isEmpty)
        #expect(!result.standardError.isEmpty)
        #expect(result.durationMilliseconds >= 0)
    }

    @Test("reports a missing approved executable")
    func reportsMissingExecutable() async {
        let executable = URL(
            fileURLWithPath: "/path-that-does-not-exist/arcan-tool"
        )
        let runner = ProcessRunner(
            approvedExecutableURLs: [executable]
        )

        await expectError(.executableNotFound(path: executable.path)) {
            _ = try await runner.run(ProcessRequest(
                executableURL: executable,
                arguments: [],
                timeout: .seconds(2)
            ))
        }
    }

    @Test("stops the process and reports a timeout")
    func stopsTimedOutProcess() async throws {
        let executable = URL(fileURLWithPath: "/bin/sleep")
        let runner = ProcessRunner(
            approvedExecutableURLs: [executable]
        )
        let clock = ContinuousClock()
        let start = clock.now

        let result = try await runner.run(ProcessRequest(
            executableURL: executable,
            arguments: ["5"],
            timeout: .milliseconds(100)
        ))
        let elapsed = start.duration(to: clock.now)

        #expect(result.status == .timedOut)
        #expect(result.durationMilliseconds >= 50)
        #expect(elapsed < .seconds(2))
    }

    @Test("rejects an executable that was not approved")
    func rejectsUnapprovedExecutable() async {
        let approved = URL(fileURLWithPath: "/usr/bin/printf")
        let unapproved = URL(fileURLWithPath: "/usr/bin/false")
        let runner = ProcessRunner(
            approvedExecutableURLs: [approved]
        )

        await expectError(
            .executableNotApproved(path: unapproved.path)
        ) {
            _ = try await runner.run(ProcessRequest(
                executableURL: unapproved,
                arguments: [],
                timeout: .seconds(2)
            ))
        }
    }

    @Test("passes shell syntax as a literal argument")
    func doesNotInterpretShellSyntax() async throws {
        let executable = URL(fileURLWithPath: "/usr/bin/printf")
        let runner = ProcessRunner(
            approvedExecutableURLs: [executable]
        )
        let unexpectedFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let argument = "; touch \(unexpectedFile.path)"

        let result = try await runner.run(ProcessRequest(
            executableURL: executable,
            arguments: ["%s", argument],
            timeout: .seconds(2)
        ))

        #expect(result.status == .exited(code: 0))
        #expect(
            String(decoding: result.standardOutput, as: UTF8.self)
                == argument
        )
        #expect(!FileManager.default.fileExists(atPath: unexpectedFile.path))
    }

    private func expectError(
        _ expectedError: ProcessExecutionError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected process execution to fail.")
        } catch let error as ProcessExecutionError {
            #expect(error == expectedError)
            #expect(error.errorDescription?.isEmpty == false)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
