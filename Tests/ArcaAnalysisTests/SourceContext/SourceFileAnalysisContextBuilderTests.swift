import ArcaAnalysis
import ArcaDomain
import Foundation
import Testing

@Suite("Complete source-file analysis context")
struct SourceFileAnalysisContextBuilderTests {
    @Test("context paths can be shared with reporting")
    func sharedContextPath() {
        let builder = SourceFileAnalysisContextBuilder()

        #expect(
            builder.contextPath(
                for: "/tmp/Shop/Sources/App.swift",
                repositoryRoot: "/tmp/Shop"
            ) == "Sources/App.swift"
        )
        #expect(
            builder.contextPath(
                for: "/tmp/Other/App.swift",
                repositoryRoot: "/tmp/Shop"
            ) == "App.swift"
        )
    }

    @Test("explicit file includes its complete current contents")
    func explicitFile() throws {
        let repositoryRoot = "/tmp/Shop"
        let source = SourceFile(
            path: "/tmp/Shop/Sources/App.swift",
            content: """
            struct App {
                let name: String
            }
            """,
            lineCount: 3
        )
        let analysisContext = makeAnalysisContext(
            sourceFiles: [source],
            repositoryRoot: repositoryRoot
        )

        let contexts = SourceFileAnalysisContextBuilder().build(
            from: analysisContext
        )
        let context = try #require(contexts.first)

        #expect(contexts.count == 1)
        #expect(context.filePath == "Sources/App.swift")
        #expect(context.sourceContent == source.content)
        #expect(context.lineCount == 3)
        #expect(context.change == nil)
    }

    @Test("changed files retain complete contents and their own ranges")
    func changedFiles() throws {
        let repositoryRoot = "/tmp/Shop"
        let renamedSource = SourceFile(
            path: "/tmp/Shop/Sources/Renamed.swift",
            content: "struct Renamed {\n    var value = 1\n}",
            lineCount: 3
        )
        let newSource = SourceFile(
            path: "/tmp/Shop/Sources/New File.swift",
            content: "let value = 1",
            lineCount: 1
        )
        let changes = [
            CodeChange(
                filePath: renamedSource.path,
                previousFilePath: "/tmp/Shop/Sources/Original.swift",
                modifiedLineRanges: [
                    ChangedLineRange(startLine: 2, endLine: 2)
                ],
                deletedLineRanges: [
                    DeletedLineRange(
                        originalStartLine: 3,
                        originalEndLine: 4
                    )
                ]
            ),
            CodeChange(
                filePath: newSource.path,
                addedLineRanges: [
                    ChangedLineRange(startLine: 1, endLine: 1)
                ]
            )
        ]
        let analysisContext = makeAnalysisContext(
            sourceFiles: [renamedSource, newSource],
            changes: changes,
            repositoryRoot: repositoryRoot
        )

        let contexts = SourceFileAnalysisContextBuilder().build(
            from: analysisContext
        )

        #expect(contexts.map(\.filePath) == [
            "Sources/Renamed.swift",
            "Sources/New File.swift"
        ])
        #expect(contexts.map(\.sourceContent) == [
            renamedSource.content,
            newSource.content
        ])
        #expect(
            contexts[0].change?.previousFilePath
                == "Sources/Original.swift"
        )
        #expect(
            contexts[0].change?.modifiedLineRanges == [
                ChangedLineRange(startLine: 2, endLine: 2)
            ]
        )
        #expect(
            contexts[0].change?.deletedLineRanges == [
                DeletedLineRange(
                    originalStartLine: 3,
                    originalEndLine: 4
                )
            ]
        )
        #expect(
            contexts[1].change?.addedLineRanges == [
                ChangedLineRange(startLine: 1, endLine: 1)
            ]
        )
    }

    @Test("Unicode source is preserved without exposing its local directory")
    func unicodeFile() throws {
        let content = """
        struct Greeting {
            let message = "Grüße 👋"
        }
        """
        let source = SourceFile(
            path: "/Users/developer/Desktop/Greeting.swift",
            content: content,
            lineCount: 3
        )
        let analysisContext = makeAnalysisContext(sourceFiles: [source])

        let contexts = SourceFileAnalysisContextBuilder().build(
            from: analysisContext
        )
        let context = try #require(contexts.first)

        #expect(context.filePath == "Greeting.swift")
        #expect(context.sourceContent == content)
        #expect(context.sourceContent.utf8.count == content.utf8.count)
        #expect(context.lineCount == 3)
    }

    @Test("source context construction does not filter files by size")
    func retainsLargeFile() throws {
        let largeContent = String(repeating: "x", count: 64_001)
        let large = SourceFile(
            path: "/tmp/Shop/Sources/Large.swift",
            content: largeContent,
            lineCount: 1
        )
        let analysisContext = makeAnalysisContext(
            sourceFiles: [large],
            repositoryRoot: "/tmp/Shop"
        )
        let contexts = SourceFileAnalysisContextBuilder().build(
            from: analysisContext
        )
        let context = try #require(contexts.first)

        #expect(contexts.count == 1)
        #expect(context.filePath == "Sources/Large.swift")
        #expect(context.sourceContent == largeContent)
    }

    @Test("unselected repository changes are never added to the context")
    func selectedFilesOnly() {
        let selected = SourceFile(
            path: "/tmp/Shop/Sources/Selected.swift",
            content: "struct Selected {}",
            lineCount: 1
        )
        let changes = [
            CodeChange(
                filePath: selected.path,
                modifiedLineRanges: [
                    ChangedLineRange(startLine: 1, endLine: 1)
                ]
            ),
            CodeChange(
                filePath: "/tmp/Shop/Sources/Unselected.swift",
                modifiedLineRanges: [
                    ChangedLineRange(startLine: 1, endLine: 1)
                ]
            )
        ]
        let analysisContext = makeAnalysisContext(
            sourceFiles: [selected],
            changes: changes,
            repositoryRoot: "/tmp/Shop"
        )

        let contexts = SourceFileAnalysisContextBuilder().build(
            from: analysisContext
        )

        #expect(contexts.map(\.filePath) == [
            "Sources/Selected.swift"
        ])
    }

    private func makeAnalysisContext(
        sourceFiles: [SourceFile],
        changes: [CodeChange] = [],
        repositoryRoot: String? = nil
    ) -> AnalysisContext {
        let request = ReviewRequest(
            id: UUID(
                uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
            )!,
            repositoryRoot: repositoryRoot,
            selectedFiles: sourceFiles.map(\.path),
            changes: changes
        )
        return AnalysisContext(
            request: request,
            sourceFiles: sourceFiles
        )
    }
}
