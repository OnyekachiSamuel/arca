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

        #expect(result.exitCode == 0, Comment(rawValue: errorOutput))
        #expect(output.contains("ARCAN-GOD-001"))
        #expect(
            output.contains(
                "File: \(fixture.standardizedFileURL.path):1:1-"
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
            ReviewReport.self,
            from: result.standardOutput
        )
        let output = String(decoding: result.standardOutput, as: UTF8.self)
        let errorOutput = String(
            decoding: result.standardError,
            as: UTF8.self
        )

        #expect(result.exitCode == 0, Comment(rawValue: errorOutput))
        #expect(result.standardError.isEmpty)
        #expect(
            report.schemaVersion == ReviewReport.currentSchemaVersion
        )
        #expect(report.findings.first?.ruleID == "ARCAN-GOD-001")
        #expect(
            report.findings.first?.filePath
                == fixture.standardizedFileURL.path
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

    private func runArcan(
        arguments: [String]
    ) throws -> SubprocessResult {
        let process = Process()
        process.executableURL = try arcanExecutableURL()
        process.arguments = arguments

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
