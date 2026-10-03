import ArcaDomain
import ArcaKnowledge
import ArcaLLM
import Foundation
import Testing

@Suite("Guided code-analysis response parser")
struct CodeAnalysisResponseParserTests {
  @Test("compact response becomes a grounded finding with its canonical rule")
  func parsesCompactResponse() throws {
    let result = parser.parse(
      validResponse,
      context: context
    )

    let candidate = try #require(result.candidates.first)
    let candidateData = try JSONEncoder().encode(candidate)
    let candidateJSON = try #require(
      JSONSerialization.jsonObject(with: candidateData) as? [String: Any]
    )
    let range = try #require(candidate.range)
    let evidence = try #require(candidate.evidence.first)
    #expect(result.diagnostics.isEmpty)
    #expect(candidate.ruleID == "ARCA-GOD-001")
    #expect(candidate.title == "God Object candidate")
    #expect(candidateJSON["issueType"] == nil)
    #expect(candidateJSON["category"] == nil)
    #expect(candidate.filePath == context.filePath)
    #expect(range.startLine == 3)
    #expect(range.endLine == 5)
    #expect(evidence.description == "The type owns persistence behavior.")
    #expect(evidence.excerpt == "    func submit() {\n        repository.save()\n    }")
  }

  @Test("an empty findings array is a successful empty result")
  func acceptsEmptyResponse() {
    let result = parser.parse(#"{"findings":[]}"#, context: context)
    #expect(result.candidates.isEmpty)
    #expect(result.diagnostics.isEmpty)
  }

  @Test("one JSON document may be wrapped in a Markdown fence")
  func acceptsMarkdownWrappedJSON() {
    let result = parser.parse(
      """
      ```json
      {"findings":[]}
      ```
      """,
      context: context
    )
    #expect(result.diagnostics.isEmpty)
  }

  @Test("unknown rules are diagnosed while recognized findings remain")
  func diagnosesUnknownRule() {
    let result = parser.parse(
      """
      {"findings":[\(findingJSON(ruleID: "ARCA-UNKNOWN-001")),\(validFindingJSON)]}
      """,
      context: context
    )

    #expect(result.candidates.count == 1)
    #expect(result.diagnostics.map(\.code) == ["ARCA-LLM-ANALYSIS-UNKNOWN-RULE"])
  }

  @Test("unexpected response fields are rejected")
  func rejectsUnexpectedFields() {
    for field in [
      #", "filePath": "Sources/Checkout.swift""#,
      #", "severity": "warning""#,
      #", "startLine": 1"#,
      #", "excerpt": "invented""#,
    ] {
      let response = validResponse.replacingOccurrences(
        of: #""explanation": "The type coordinates several responsibilities.""#,
        with: "\"explanation\": \"The type coordinates several responsibilities.\"\(field)"
      )
      expectDiagnostic(
        parser.parse(response, context: context),
        code: "ARCA-LLM-ANALYSIS-INVALID-SCHEMA"
      )
    }
  }

  @Test("invalid evidence lines are diagnosed")
  func rejectsInvalidEvidenceRange() {
    for (start, end) in [(0, 1), (5, 4), (1, 7)] {
      let result = parser.parse(
        "{\"findings\":[\(findingJSON(startLine: start, endLine: end))]}",
        context: context
      )
      expectDiagnostic(
        result,
        code: "ARCA-LLM-ANALYSIS-EVIDENCE-INVALID-RANGE"
      )
    }
  }

  @Test("empty evidence descriptions are diagnosed")
  func rejectsEmptyEvidenceDescription() {
    let response = validResponse.replacingOccurrences(
      of: "The type owns persistence behavior.",
      with: ""
    )
    expectDiagnostic(
      parser.parse(response, context: context),
      code: "ARCA-LLM-ANALYSIS-EVIDENCE-EMPTY-DESCRIPTION"
    )
  }

  @Test("more than five findings are rejected")
  func rejectsTooManyFindings() {
    let findings = Array(repeating: validFindingJSON, count: 6)
      .joined(separator: ",")
    expectDiagnostic(
      parser.parse("{\"findings\":[\(findings)]}", context: context),
      code: "ARCA-LLM-ANALYSIS-RESPONSE-TOO-LARGE"
    )
  }

  @Test("malformed JSON is rejected")
  func rejectsMalformedJSON() {
    expectDiagnostic(
      parser.parse(#"{"findings":[}"#, context: context),
      code: "ARCA-LLM-ANALYSIS-INVALID-JSON"
    )
  }

  @Test("generated commands remain inert response text")
  func neverExecutesGeneratedCode() throws {
    let command = "$(touch /tmp/arca-must-not-execute)"
    let response = validResponse.replacingOccurrences(
      of: "The type coordinates several responsibilities.",
      with: command
    )
    let result = parser.parse(response, context: context)
    #expect(try #require(result.candidates.first).explanation == command)
    #expect(result.diagnostics.isEmpty)
  }

  @Test("evidence excerpts preserve the original source text")
  func preservesSourceEvidence() throws {
    let source = #"let apiToken = "sk-live-super-secret-value""#
    let result = parser.parse(
      "{\"findings\":[\(findingJSON(startLine: 1, endLine: 1))]}",
      context: SourceFileAnalysisContext(
        filePath: "Secrets.swift",
        sourceContent: source,
        lineCount: 1
      )
    )

    #expect(result.diagnostics.isEmpty)
    #expect(result.candidates.first?.evidence.first?.excerpt == source)
  }

  private var parser: CodeAnalysisResponseParser {
    CodeAnalysisResponseParser(
      rules: [godObjectKnowledge]
    )
  }

  private var context: SourceFileAnalysisContext {
    SourceFileAnalysisContext(
      filePath: "Sources/Checkout.swift",
      sourceContent: """
        final class Checkout {
            let repository: Repository
            func submit() {
                repository.save()
            }
        }
        """,
      lineCount: 6
    )
  }

  private var validResponse: String {
    "{\"findings\":[\(validFindingJSON)]}"
  }

  private var validFindingJSON: String {
    findingJSON()
  }

  private func findingJSON(
    ruleID: String = "ARCA-GOD-001",
    startLine: Int = 3,
    endLine: Int = 5
  ) -> String {
    """
    {
      "ruleID": "\(ruleID)",
      "explanation": "The type coordinates several responsibilities.",
      "evidence": [
        {
          "description": "The type owns persistence behavior.",
          "startLine": \(startLine),
          "endLine": \(endLine)
        }
      ]
    }
    """
  }

  private var godObjectKnowledge: RuleKnowledge {
    RuleKnowledge(
      ruleID: "ARCA-GOD-001",
      reviewType: .godObject,
      category: "architecture",
      title: "God Object candidate",
      problemContext: "A type owns multiple unrelated responsibilities.",
      expectedBehavior: "Keep types focused.",
      violationCriteria: "Several responsibilities are visible.",
      knowledgeFile: "references/ARCA-GOD-001.md",
      supportingKnowledge: "# God Object"
    )
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
