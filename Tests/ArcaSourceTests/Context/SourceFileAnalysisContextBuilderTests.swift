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

    let context = SourceFileAnalysisContextBuilder().build(
      sourceFile: source,
      repositoryRoot: "/tmp/Shop",
      changes: [selectedChange, unrelatedChange]
    )

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

    let context = SourceFileAnalysisContextBuilder().build(
      sourceFile: source,
      repositoryRoot: "/tmp/Shop"
    )

    #expect(context.filePath == "Outside.swift")
    #expect(context.change == nil)
  }
}
