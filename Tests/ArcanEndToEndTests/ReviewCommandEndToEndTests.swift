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
        let process = Process()
        process.executableURL = try arcanExecutableURL()
        process.arguments = ["review", "--file", fixture.path]

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let output = String(
            decoding: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        let errorOutput = String(
            decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )

        #expect(process.terminationStatus == 0, Comment(rawValue: errorOutput))
        #expect(output.contains("ARCAN-GOD-001"))
        #expect(
            output.contains(
                "File: \(fixture.standardizedFileURL.path):1:1-"
            )
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

private enum EndToEndTestError: Error {
    case executableNotFound
}
