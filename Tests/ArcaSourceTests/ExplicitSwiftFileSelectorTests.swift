import ArcaSource
import Foundation
import Testing

@Suite("Explicit Swift file selection")
struct ExplicitSwiftFileSelectorTests {
    @Test("selects an existing readable Swift file")
    func selectsSwiftFile() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("Feature.swift")
            try "struct Feature {}".write(to: file, atomically: true, encoding: .utf8)

            let selectedPath = try ExplicitSwiftFileSelector().select(path: file.path)

            #expect(selectedPath == file.path)
        }
    }

    @Test("rejects a missing path with a clear error")
    func rejectsMissingFile() throws {
        try withTemporaryDirectory { directory in
            let path = directory.appendingPathComponent("Missing.swift").path

            expectError(.missing(path: path)) {
                _ = try ExplicitSwiftFileSelector().select(path: path)
            }
        }
    }

    @Test("rejects a directory even when its name ends in swift")
    func rejectsDirectory() throws {
        try withTemporaryDirectory { directory in
            let swiftDirectory = directory.appendingPathComponent(
                "Feature.swift",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: swiftDirectory,
                withIntermediateDirectories: false
            )

            expectError(.directory(path: swiftDirectory.path)) {
                _ = try ExplicitSwiftFileSelector().select(path: swiftDirectory.path)
            }
        }
    }

    @Test("rejects an existing non-Swift file")
    func rejectsNonSwiftFile() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("Notes.txt")
            try "notes".write(to: file, atomically: true, encoding: .utf8)

            expectError(.notSwiftFile(path: file.path)) {
                _ = try ExplicitSwiftFileSelector().select(path: file.path)
            }
        }
    }

    @Test("rejects an unreadable Swift file")
    func rejectsUnreadableFile() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("Private.swift")
            try "struct Private {}".write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o000],
                ofItemAtPath: file.path
            )
            defer {
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: file.path
                )
            }

            expectError(.unreadable(path: file.path)) {
                _ = try ExplicitSwiftFileSelector().select(path: file.path)
            }
        }
    }

    private func expectError(
        _ expected: SourceSelectionError,
        performing operation: () throws -> Void
    ) {
        do {
            try operation()
            Issue.record("Expected source selection to fail")
        } catch let error as SourceSelectionError {
            #expect(error == expected)
            #expect(error.errorDescription?.isEmpty == false)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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
