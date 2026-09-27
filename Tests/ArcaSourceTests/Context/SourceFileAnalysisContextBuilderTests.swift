import ArcaDomain
import ArcaSource
import Testing

@Suite("Source-file analysis context")
struct SourceFileAnalysisContextBuilderTests {
  @Test("builds complete source context with only the selected file change")
  func buildsSelectedContext() throws {
    let source = SourceFile(
      path: "/tmp/Shop/Sources/App.swift",
      content: "struct App {\n  let value = 2\n}",
      lineCount: 3
    )
    let selectedChange = CodeChange(
      filePath: source.path,
      modifiedLineRanges: [ChangedLineRange(startLine: 2, endLine: 2)]
    )
    let unrelatedChange = CodeChange(
      filePath: "/tmp/Shop/Sources/Other.swift",
      modifiedLineRanges: [ChangedLineRange(startLine: 1, endLine: 1)]
    )

    let contexts = SourceFileAnalysisContextBuilder().build(
      sourceFiles: [source],
      repositoryRoot: "/tmp/Shop",
      changes: [selectedChange, unrelatedChange]
    )
    let context = try #require(contexts.first)

    #expect(contexts.count == 1)
    #expect(context.filePath == "Sources/App.swift")
    #expect(context.sourceContent == source.content)
    #expect(context.lineCount == 3)
    #expect(context.change?.modifiedLineRanges == selectedChange.modifiedLineRanges)
  }

  @Test("does not invent change context for an unchanged file")
  func buildsUnchangedContext() throws {
    let source = SourceFile(
      path: "/tmp/Outside.swift",
      content: "struct Outside {}",
      lineCount: 1
    )

    let context = try #require(
      SourceFileAnalysisContextBuilder().build(
        sourceFiles: [source],
        repositoryRoot: "/tmp/Shop"
      ).first
    )

    #expect(context.filePath == "Outside.swift")
    #expect(context.change == nil)
  }
}
