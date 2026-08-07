import ArcaGit
import Foundation
import Testing

@Suite("Changed Swift file discovery")
struct GitChangedSwiftFileFinderTests {
    @Test("selects staged Swift files")
    func selectsStagedSwiftFiles() throws {
        try withTemporaryGitRepository { repository in
            let swiftFile = try repository.write(
                "struct Staged {}",
                to: "Staged.swift"
            )
            _ = try repository.write("notes", to: "Notes.txt")
            try repository.runGit(["add", "--", "Staged.swift", "Notes.txt"])

            let files = try GitChangedSwiftFileFinder()
                .find(from: repository.root.path)

            #expect(files == [normalizedPath(swiftFile)])
        }
    }

    @Test("selects unstaged Swift files")
    func selectsUnstagedSwiftFiles() throws {
        try withTemporaryGitRepository { repository in
            let swiftFile = try repository.write(
                "struct Feature {}",
                to: "Feature.swift"
            )
            try repository.commitAll()
            try "struct Feature { let value = 1 }".write(
                to: swiftFile,
                atomically: true,
                encoding: .utf8
            )

            let files = try GitChangedSwiftFileFinder()
                .find(from: repository.root.path)

            #expect(files == [normalizedPath(swiftFile)])
        }
    }

    @Test("selects untracked Swift files")
    func selectsUntrackedSwiftFiles() throws {
        try withTemporaryGitRepository { repository in
            let swiftFile = try repository.write(
                "struct Untracked {}",
                to: "Sources/Untracked.swift"
            )

            let files = try GitChangedSwiftFileFinder()
                .find(from: repository.root.path)

            #expect(files == [normalizedPath(swiftFile)])
        }
    }

    @Test("ignores deleted Swift files")
    func ignoresDeletedSwiftFiles() throws {
        try withTemporaryGitRepository { repository in
            let swiftFile = try repository.write(
                "struct Removed {}",
                to: "Removed.swift"
            )
            try repository.commitAll()
            try FileManager.default.removeItem(at: swiftFile)

            let files = try GitChangedSwiftFileFinder()
                .find(from: repository.root.path)

            #expect(files.isEmpty)
        }
    }

    @Test("selects a renamed Swift file using its new path")
    func selectsRenamedSwiftFileWithSpaces() throws {
        try withTemporaryGitRepository { repository in
            _ = try repository.write(
                "struct Renamed {}",
                to: "Old Feature.swift"
            )
            try repository.commitAll()
            let newName = "New Feature;echo unsafe.swift"
            try repository.runGit([
                "mv",
                "--",
                "Old Feature.swift",
                newName
            ])

            let files = try GitChangedSwiftFileFinder()
                .find(from: repository.root.path)

            let renamedFile = repository.root.appendingPathComponent(newName)
            #expect(files == [normalizedPath(renamedFile)])
        }
    }

    private func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func withTemporaryGitRepository<Result>(
        _ body: (TemporaryGitRepository) throws -> Result
    ) throws -> Result {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = TemporaryGitRepository(root: root)
        try repository.runGit(["init", "--quiet"])
        return try body(repository)
    }
}

struct TemporaryGitRepository {
    let root: URL

    func write(_ content: String, to relativePath: String) throws -> URL {
        let file = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    func write(_ data: Data, to relativePath: String) throws -> URL {
        let file = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: file)
        return file
    }

    func commitAll() throws {
        try runGit(["add", "--all"])
        try runGit([
            "-c", "user.name=ARCA Tests",
            "-c", "user.email=arca@example.test",
            "commit", "--quiet", "-m", "Baseline"
        ])
    }

    func runGit(_ arguments: [String]) throws {
        let process = Process()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(
                decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
            throw GitTestError.commandFailed(message)
        }
    }
}

private enum GitTestError: Error {
    case commandFailed(String)
}
