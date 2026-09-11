import ArcaDomain
import ArcaLLM
import Testing

@Suite("Baseline code-analysis response parser")
struct BaselineCodeAnalysisResponseParserTests {
  @Test("compact response becomes an unclassified grounded finding")
  func acceptsCompactFinding() throws {
    let result = parser.parse(
      validResponse,
      context: context,
      metadata: ["promptVariant": .string("baseline")]
    )

    let finding = try #require(result.candidates.first)
    let range = try #require(finding.range)
    let evidence = try #require(finding.evidence.first)
    #expect(result.diagnostics.isEmpty)
    #expect(finding.ruleID == nil)
    #expect(finding.title == "Large Class")
    #expect(finding.issueType == nil)
    #expect(finding.category == nil)
    #expect(finding.filePath == "Example.swift")
    #expect(range.startLine == 2)
    #expect(range.endLine == 2)
    #expect(evidence.excerpt == "    let value = 1")
    #expect(finding.sourceIdentifiers == ["llm-code-analysis"])
  }

  @Test("fields from the old response schema are rejected")
  func rejectsLegacyFields() {
    let response = validResponse.replacingOccurrences(
      of: #""title":"Large Class""#,
      with: #""title":"Large Class","severity":"warning""#
    )

    expectDiagnostic(
      parser.parse(response, context: context),
      code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA"
    )
  }

  @Test("invalid evidence lines are diagnosed")
  func rejectsInvalidEvidenceRange() {
    let response = validResponse.replacingOccurrences(
      of: #""startLine":2"#,
      with: #""startLine":0"#
    )

    expectDiagnostic(
      parser.parse(response, context: context),
      code: "ARCA-LLM-ANALYSIS-EVIDENCE-INVALID-RANGE"
    )
  }

  @Test("malformed JSON becomes a diagnostic")
  func rejectsMalformedJSON() {
    expectDiagnostic(
      parser.parse("not JSON", context: context),
      code: "ARCA-LLM-ANALYSIS-INVALID-JSON"
    )
  }

  private var parser: BaselineCodeAnalysisResponseParser {
    BaselineCodeAnalysisResponseParser(
      sourceIdentifiers: ["llm-code-analysis"]
    )
  }

  private var context: SourceFileAnalysisContext {
    SourceFileAnalysisContext(
      filePath: "Example.swift",
      sourceContent: "struct Example {\n    let value = 1\n}",
      lineCount: 3
    )
  }

  private var validResponse: String {
    #"{"findings":[{"title":"Large Class","explanation":"The type combines too many responsibilities.","evidence":[{"description":"The type owns state directly.","startLine":2,"endLine":2}]}]}"#
  }

  private func expectDiagnostic(
    _ result: CodeAnalysisResponseParsingResult,
    code: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    #expect(result.candidates.isEmpty, sourceLocation: sourceLocation)
    #expect(result.diagnostics.first?.code == code, sourceLocation: sourceLocation)
  }
}
