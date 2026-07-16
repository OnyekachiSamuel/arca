import ArcanGit
import Foundation
import Testing

@Suite("Git repository root discovery")
struct GitRepositoryFinderTests {
    @Test("returns the repository root from a nested directory")
    func discoversRootFromNestedDirectory() throws {
        try withTemporaryDirectory { repositoryRoot in
            try initializeGitRepository(at: repositoryRoot)
            let nestedDirectory = repositoryRoot
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent("Feature Work;echo unsafe", isDirectory: true)
            try FileManager.default.createDirectory(
                at: nestedDirectory,
                withIntermediateDirectories: true
            )

            let discoveredRoot = try GitRepositoryFinder()
                .discover(from: nestedDirectory.path)

            #expect(discoveredRoot == normalizedPath(repositoryRoot))
        }
    }

    @Test("reports a path outside a Git repository")
    func rejectsDirectoryOutsideRepository() throws {
        try withTemporaryDirectory { directory in
            do {
                _ = try GitRepositoryFinder().discover(from: directory.path)
                Issue.record("Expected repository discovery to fail")
            } catch let error as GitRepositoryFinderError {
                #expect(error == .notRepository(path: directory.path))
                #expect(error.errorDescription?.isEmpty == false)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    private func initializeGitRepository(at directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init", "--quiet", directory.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    private func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
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
