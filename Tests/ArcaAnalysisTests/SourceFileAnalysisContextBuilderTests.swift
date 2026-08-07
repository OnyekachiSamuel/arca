import ArcaAnalysis
import ArcaDomain
import Foundation
import Testing

@Suite("Complete source-file analysis context")
struct SourceFileAnalysisContextBuilderTests {
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

        let result = SourceFileAnalysisContextBuilder().build(
            from: analysisContext
        )
        let context = try #require(result.contexts.first)

        #expect(result.contexts.count == 1)
        #expect(result.diagnostics.isEmpty)
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

        let result = SourceFileAnalysisContextBuilder().build(
            from: analysisContext
        )

        #expect(result.contexts.map(\.filePath) == [
            "Sources/Renamed.swift",
            "Sources/New File.swift"
        ])
        #expect(result.contexts.map(\.sourceContent) == [
            renamedSource.content,
            newSource.content
        ])
        #expect(
            result.contexts[0].change?.previousFilePath
                == "Sources/Original.swift"
        )
        #expect(
            result.contexts[0].change?.modifiedLineRanges == [
                ChangedLineRange(startLine: 2, endLine: 2)
            ]
        )
        #expect(
            result.contexts[0].change?.deletedLineRanges == [
                DeletedLineRange(
                    originalStartLine: 3,
                    originalEndLine: 4
                )
            ]
        )
        #expect(
            result.contexts[1].change?.addedLineRanges == [
                ChangedLineRange(startLine: 1, endLine: 1)
            ]
        )
        #expect(result.diagnostics.isEmpty)
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

        let result = SourceFileAnalysisContextBuilder().build(
            from: analysisContext
        )
        let context = try #require(result.contexts.first)

        #expect(context.filePath == "Greeting.swift")
        #expect(context.sourceContent == content)
        #expect(context.sourceContent.utf8.count == content.utf8.count)
        #expect(context.lineCount == 3)
    }

    @Test("oversized files are skipped explicitly without blocking small files")
    func oversizedFile() throws {
        let oversized = SourceFile(
            path: "/tmp/Shop/Sources/Large.swift",
            content: String(repeating: "x", count: 11),
            lineCount: 1
        )
        let small = SourceFile(
            path: "/tmp/Shop/Sources/Small.swift",
            content: "let x = 1",
            lineCount: 1
        )
        let analysisContext = makeAnalysisContext(
            sourceFiles: [oversized, small],
            repositoryRoot: "/tmp/Shop"
        )
        let builder = SourceFileAnalysisContextBuilder(
            limits: SourceFileAnalysisContextLimits(
                maximumSourceUTF8Bytes: 10
            )
        )

        let result = builder.build(from: analysisContext)
        let diagnostic = try #require(result.diagnostics.first)

        #expect(result.contexts.map(\.filePath) == ["Sources/Small.swift"])
        #expect(result.diagnostics.count == 1)
        #expect(diagnostic.code == "ARCA-LLM-SOURCE-FILE-TOO-LARGE")
        #expect(diagnostic.severity == .warning)
        #expect(diagnostic.message.contains("Sources/Large.swift"))
        #expect(diagnostic.message.contains("11 UTF-8 bytes"))
        #expect(diagnostic.message.contains("limit is 10"))
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

        let result = SourceFileAnalysisContextBuilder().build(
            from: analysisContext
        )

        #expect(result.contexts.map(\.filePath) == [
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
