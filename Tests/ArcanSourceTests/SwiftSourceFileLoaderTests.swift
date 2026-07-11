import ArcanDomain
import ArcanSource
import Foundation
import Testing

@Suite("Swift source file loading")
struct SwiftSourceFileLoaderTests {
    @Test("loads Unicode source with normalized path and line count")
    func loadsUnicodeSource() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("Unicode.swift")
            let content = """
            struct Café {
                let greeting = "👋🏽"
            }

            """
            try content.write(to: file, atomically: true, encoding: .utf8)
            let pathWithDotComponent = directory.path + "/./Unicode.swift"

            let source = try SwiftSourceFileLoader().load(
                path: pathWithDotComponent
            )

            #expect(source.path == file.standardizedFileURL.path)
            #expect(source.content == content)
            #expect(source.lineCount == 3)
        }
    }

    @Test("reports an explicit error for invalid UTF-8")
    func rejectsInvalidUTF8() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("Invalid.swift")
            try Data([0xC3, 0x28]).write(to: file)
            let normalizedPath = file.standardizedFileURL.path

            expectError(.invalidUTF8(path: normalizedPath)) {
                _ = try SwiftSourceFileLoader().load(path: file.path)
            }
        }
    }

    @Test("rejects an unreadable source file")
    func rejectsUnreadableSource() throws {
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

            expectError(.unreadable(path: file.standardizedFileURL.path)) {
                _ = try SwiftSourceFileLoader().load(path: file.path)
            }
        }
    }

    private func expectError(
        _ expected: SourceLoadingError,
        performing operation: () throws -> Void
    ) {
        do {
            try operation()
            Issue.record("Expected source loading to fail")
        } catch let error as SourceLoadingError {
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
