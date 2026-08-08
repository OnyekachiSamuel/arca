import ArcaDomain
import ArcaLLM
import Testing

@Suite("Baseline code-analysis response parser")
struct BaselineCodeAnalysisResponseParserTests {
    @Test("accepts an independently named issue without a rule ID")
    func acceptsRuleFreeFinding() throws {
        let result = parser.parse(
            validResponse,
            context: context,
            metadata: ["promptVariant": .string("baseline")]
        )

        let finding = try #require(result.findings.first)
        #expect(result.diagnostics.isEmpty)
        #expect(finding.canonicalRuleID == nil)
        #expect(finding.title == "Large Class")
        #expect(finding.issueType == .codeSmell)
        #expect(finding.filePath == "Example.swift")
        #expect(finding.range.startLine == 1)
        #expect(finding.range.endLine == 3)
        #expect(finding.sourceIdentifiers == ["llm-code-analysis"])
        #expect(finding.metadata["promptVariant"] == .string("baseline"))
    }

    @Test("does not validate a model-invented identifier as an ARCA rule")
    func ignoresNonCanonicalModelIdentifier() throws {
        let response = validResponse.replacingOccurrences(
            of: #""title":"Large Class""#,
            with: #""ruleID":"ARCA001","title":"Large Class""#
        )

        let result = parser.parse(response, context: context)

        let finding = try #require(result.findings.first)
        #expect(finding.canonicalRuleID == nil)
        #expect(!result.diagnostics.map(\.code).contains(
            "ARCA-LLM-ANALYSIS-UNKNOWN-RULE"
        ))
    }

    @Test("retains a finding when only its excerpt cannot be matched")
    func retainsExcerptMismatch() throws {
        let response = validResponse.replacingOccurrences(
            of: "    let value = 1",
            with: "    let value = 2"
        )

        let result = parser.parse(response, context: context)

        #expect(result.findings.count == 1)
        #expect(result.diagnostics.map(\.code) == [
            "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-MISMATCH"
        ])
    }

    @Test("malformed JSON becomes a diagnostic")
    func rejectsMalformedJSON() {
        let result = parser.parse("not JSON", context: context)

        #expect(result.findings.isEmpty)
        #expect(result.diagnostics.map(\.code) == [
            "ARCA-LLM-ANALYSIS-INVALID-JSON"
        ])
    }

    private var parser: BaselineCodeAnalysisResponseParser {
        BaselineCodeAnalysisResponseParser(
            sourceIdentifiers: ["llm-code-analysis"],
            retainsEvidenceExcerptMismatches: true
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
        """
        {"findings":[{"title":"Large Class","issueType":"codeSmell","filePath":"Example.swift","explanation":"The type has accumulated substantial state and behavior.","severity":"warning","startLine":1,"endLine":3,"evidence":[{"description":"The type owns state directly.","startLine":2,"endLine":2,"excerpt":"    let value = 1"}]}]}
        """
    }
}
