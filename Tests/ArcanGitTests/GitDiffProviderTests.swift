import ArcanDomain
import ArcanGit
import Foundation
import Testing

@Suite("Git diff extraction")
struct GitDiffProviderTests {
    @Test("extracts added and modified ranges from multiple zero-context hunks")
    func extractsMultipleChangedHunks() throws {
        try withTemporaryGitRepository { repository in
            let file = try repository.write(
                """
                struct Feature {
                    let first = 1
                    let second = 2
                    let third = 3
                    func run() {
                        print(first)
                        print(second)
                        print(third)
                    }
                }
                """,
                to: "Feature.swift"
            )
            try repository.commitAll()
            try """
            struct Feature {
                let first = 10
                let second = 2
                let third = 3
                let fourth = 4
                func run() {
                    print(first)
                    print(second)
                    print(third + fourth)
                }
            }
            """.write(to: file, atomically: true, encoding: .utf8)
            try repository.runGit(["add", "--", "Feature.swift"])

            let diffs = try GitDiffProvider().extract(from: repository.root.path)
            let diff = try #require(diffs.first)

            #expect(diffs.count == 1)
            #expect(diff.filePath == normalizedPath(file))
            #expect(diff.previousFilePath == nil)
            #expect(
                diff.addedLineRanges
                    == [ChangedLineRange(startLine: 5, endLine: 5)]
            )
            #expect(
                diff.modifiedLineRanges
                    == [
                        ChangedLineRange(startLine: 2, endLine: 2),
                        ChangedLineRange(startLine: 9, endLine: 9)
                    ]
            )
            #expect(diff.deletedLineRanges.isEmpty)
        }
    }

    @Test("models deleted lines in the original file separately")
    func extractsDeletedRanges() throws {
        try withTemporaryGitRepository { repository in
            let file = try repository.write(
                """
                struct Feature {
                    let first = 1
                    let removedOne = 2
                    let removedTwo = 3
                    let last = 4
                }
                """,
                to: "Feature.swift"
            )
            try repository.commitAll()
            try """
            struct Feature {
                let first = 1
                let last = 4
            }
            """.write(to: file, atomically: true, encoding: .utf8)

            let diffs = try GitDiffProvider().extract(from: repository.root.path)
            let diff = try #require(diffs.first)

            #expect(diff.addedLineRanges.isEmpty)
            #expect(diff.modifiedLineRanges.isEmpty)
            #expect(
                diff.deletedLineRanges
                    == [
                        DeletedLineRange(
                            originalStartLine: 3,
                            originalEndLine: 4
                        )
                    ]
            )
        }
    }

    @Test("preserves old and new paths when a modified file is renamed")
    func extractsRenamedFileDiff() throws {
        try withTemporaryGitRepository { repository in
            let oldFile = try repository.write(
                """
                struct Feature {
                    let value = 1
                }
                """,
                to: "Old Feature.swift"
            )
            try repository.commitAll()
            let newFile = repository.root
                .appendingPathComponent("New Feature.swift")
            try repository.runGit([
                "mv", "--", "Old Feature.swift", "New Feature.swift"
            ])
            try """
            struct Feature {
                let value = 2
            }
            """.write(to: newFile, atomically: true, encoding: .utf8)

            let diffs = try GitDiffProvider().extract(from: repository.root.path)
            let diff = try #require(diffs.first)

            #expect(diffs.count == 1)
            #expect(diff.filePath == normalizedPath(newFile))
            #expect(diff.previousFilePath == normalizedPath(oldFile))
            #expect(
                diff.modifiedLineRanges
                    == [ChangedLineRange(startLine: 2, endLine: 2)]
            )
        }
    }

    @Test("excludes binary Swift files")
    func excludesBinaryDiffs() throws {
        try withTemporaryGitRepository { repository in
            let file = try repository.write(
                Data([0x00, 0x01, 0x02]),
                to: "Generated.swift"
            )
            try repository.commitAll()
            try Data([0x00, 0x01, 0x03]).write(to: file)

            let diffs = try GitDiffProvider().extract(from: repository.root.path)

            #expect(diffs.isEmpty)
        }
    }

    @Test("treats every line in an untracked Swift file as added")
    func extractsUntrackedFileRanges() throws {
        try withTemporaryGitRepository { repository in
            let file = try repository.write(
                """
                struct NewFeature {
                    let value = 1
                }
                """,
                to: "New Feature.swift"
            )

            let diffs = try GitDiffProvider().extract(from: repository.root.path)
            let diff = try #require(diffs.first)

            #expect(diff.filePath == normalizedPath(file))
            #expect(
                diff.addedLineRanges
                    == [ChangedLineRange(startLine: 1, endLine: 3)]
            )
            #expect(diff.modifiedLineRanges.isEmpty)
            #expect(diff.deletedLineRanges.isEmpty)
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
