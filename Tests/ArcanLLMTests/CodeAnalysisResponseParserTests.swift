import ArcanDomain
import ArcanKnowledge
import ArcanLLM
import Testing

@Suite("Code-analysis response parser")
struct CodeAnalysisResponseParserTests {
    @Test("valid JSON becomes a grounded candidate finding")
    func parsesValidResponse() throws {
        let result = parser.parse(
            validResponse,
            context: context,
            analyzerMetadata: [
                "providerID": .string("local-qwen"),
                "modelID": .string("qwen2.5-coder")
            ]
        )
        let candidate = try #require(result.candidates.first)

        #expect(result.candidates.count == 1)
        #expect(result.diagnostics.isEmpty)
        #expect(candidate.ruleID == godObjectKnowledge.ruleID)
        #expect(candidate.title == godObjectKnowledge.title)
        #expect(candidate.explanation == "The type coordinates several responsibilities.")
        #expect(candidate.filePath == context.filePath)
        #expect(
            candidate.range == SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 6,
                endColumn: 2
            )
        )
        #expect(candidate.proposedSeverity == .warning)
        #expect(candidate.proposedCategory == .antiPattern)
        #expect(candidate.sourceIdentifiers == ["llm-code-analysis"])
        #expect(
            candidate.analyzerMetadata["providerID"]
                == .string("local-qwen")
        )
        #expect(
            candidate.analyzerMetadata["modelID"]
                == .string("qwen2.5-coder")
        )

        guard case let .sourceCode(evidence) = candidate.evidence.first else {
            Issue.record("Expected source-code evidence.")
            return
        }
        #expect(evidence.description == "The type owns persistence behavior.")
        #expect(evidence.excerpt == "    func submit() {\n        repository.save()\n    }")
        #expect(
            evidence.range == SourceRange(
                startLine: 3,
                startColumn: 1,
                endLine: 5,
                endColumn: 6
            )
        )
    }

    @Test("an empty findings array is a successful empty result")
    func acceptsEmptyResponse() {
        let result = parser.parse(
            #"{"findings":[]}"#,
            context: context
        )

        #expect(result.candidates.isEmpty)
        #expect(result.diagnostics.isEmpty)
    }

    @Test("candidate preserves stable analyzer provider and model sources")
    func preservesMultipleSources() throws {
        let parser = CodeAnalysisResponseParser(
            knowledgeProvider: knowledgeProvider,
            sourceIdentifiers: [
                "llm-code-analysis",
                "llm-provider:ollama",
                "llm-model:qwen",
                "llm-code-analysis"
            ]
        )

        let result = parser.parse(validResponse, context: context)
        let candidate = try #require(result.candidates.first)

        #expect(
            candidate.sourceIdentifiers == [
                "llm-code-analysis",
                "llm-provider:ollama",
                "llm-model:qwen"
            ]
        )
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

        #expect(result.candidates.isEmpty)
        #expect(result.diagnostics.isEmpty)
    }

    @Test("malformed JSON is rejected with a diagnostic")
    func rejectsMalformedJSON() {
        let result = parser.parse(
            #"{"findings":[}"#,
            context: context
        )

        expectDiagnostic(
            result,
            code: "ARCAN-LLM-ANALYSIS-INVALID-JSON"
        )
    }

    @Test("missing and unknown fields do not satisfy the response schema")
    func rejectsInvalidSchema() {
        let missingExplanation = validResponse.replacingOccurrences(
            of: #""explanation": "The type coordinates several responsibilities.","#,
            with: ""
        )
        let unknownProperty = validResponse.replacingOccurrences(
            of: #""ruleID": "ARCAN-GOD-001","#,
            with: """
            "ruleID": "ARCAN-GOD-001",
                  "unexpected": true,
            """
        )

        expectDiagnostic(
            parser.parse(missingExplanation, context: context),
            code: "ARCAN-LLM-ANALYSIS-INVALID-SCHEMA"
        )
        expectDiagnostic(
            parser.parse(unknownProperty, context: context),
            code: "ARCAN-LLM-ANALYSIS-INVALID-SCHEMA"
        )
    }

    @Test("unknown rules are skipped while recognized findings remain")
    func diagnosesUnknownRule() {
        let unknownFinding = findingJSON(
            ruleID: "ARCAN-UNKNOWN-001",
            filePath: context.filePath,
            startLine: 1,
            endLine: 6
        )
        let result = parser.parse(
            """
            {"findings":[\(unknownFinding),\(validFindingJSON)]}
            """,
            context: context
        )

        #expect(result.candidates.count == 1)
        #expect(result.candidates[0].ruleID == "ARCAN-GOD-001")
        #expect(result.diagnostics.count == 1)
        #expect(
            result.diagnostics[0].code
                == "ARCAN-LLM-ANALYSIS-UNKNOWN-RULE"
        )
        #expect(result.diagnostics[0].message.contains("ARCAN-UNKNOWN-001"))
    }

    @Test("mismatched and unsafe file paths are rejected")
    func rejectsInvalidPaths() {
        let paths = [
            "Sources/Other.swift",
            "/tmp/Checkout.swift",
            "../Checkout.swift"
        ]

        for path in paths {
            let result = parser.parse(
                """
                {"findings":[\(findingJSON(
                    ruleID: "ARCAN-GOD-001",
                    filePath: path,
                    startLine: 1,
                    endLine: 6
                ))]}
                """,
                context: context
            )

            expectDiagnostic(
                result,
                code: "ARCAN-LLM-ANALYSIS-INVALID-PATH"
            )
        }
    }

    @Test("finding and evidence ranges must belong to the supplied file")
    func rejectsInvalidRanges() {
        let ranges = [
            (start: 0, end: 1),
            (start: 5, end: 4),
            (start: 1, end: 7)
        ]

        for range in ranges {
            let result = parser.parse(
                """
                {"findings":[\(findingJSON(
                    ruleID: "ARCAN-GOD-001",
                    filePath: context.filePath,
                    startLine: range.start,
                    endLine: range.end
                ))]}
                """,
                context: context
            )

            expectDiagnostic(
                result,
                code: "ARCAN-LLM-ANALYSIS-INVALID-RANGE"
            )
        }

        let evidenceOutsideFinding = validResponse
            .replacingOccurrences(
                of: #""startLine": 1,"#,
                with: #""startLine": 4,"#,
                maxReplacements: 1
            )
        expectDiagnostic(
            parser.parse(evidenceOutsideFinding, context: context),
            code: "ARCAN-LLM-ANALYSIS-INVALID-EVIDENCE"
        )
    }

    @Test("evidence excerpts must occur inside their declared source range")
    func rejectsInventedEvidence() {
        let response = validResponse.replacingOccurrences(
            of: "repository.save()",
            with: "repository.deleteEverything()"
        )
        let result = parser.parse(response, context: context)

        expectDiagnostic(
            result,
            code: "ARCAN-LLM-ANALYSIS-INVALID-EVIDENCE"
        )
    }

    @Test("responses exceeding their configured byte limit are rejected")
    func rejectsOversizedResponse() {
        let limitedParser = CodeAnalysisResponseParser(
            knowledgeProvider: knowledgeProvider,
            sourceIdentifier: "llm-code-analysis",
            limits: CodeAnalysisResponseLimits(
                maximumResponseUTF8Bytes: 10
            )
        )
        let result = limitedParser.parse(validResponse, context: context)

        expectDiagnostic(
            result,
            code: "ARCAN-LLM-ANALYSIS-RESPONSE-TOO-LARGE"
        )
    }

    @Test("generated commands remain inert response text")
    func neverExecutesGeneratedCode() throws {
        let generatedCommand = "$(touch /tmp/arcan-must-not-execute)"
        let response = validResponse.replacingOccurrences(
            of: "The type coordinates several responsibilities.",
            with: generatedCommand
        )

        let result = parser.parse(response, context: context)
        let candidate = try #require(result.candidates.first)

        #expect(candidate.explanation == generatedCommand)
        #expect(result.diagnostics.isEmpty)
    }

    private var parser: CodeAnalysisResponseParser {
        CodeAnalysisResponseParser(
            knowledgeProvider: knowledgeProvider,
            sourceIdentifier: "llm-code-analysis"
        )
    }

    private var knowledgeProvider: StubCodeAnalysisKnowledgeProvider {
        StubCodeAnalysisKnowledgeProvider(knowledge: [godObjectKnowledge])
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
        """
        {"findings":[\(validFindingJSON)]}
        """
    }

    private var validFindingJSON: String {
        """
        {
          "ruleID": "ARCAN-GOD-001",
          "filePath": "Sources/Checkout.swift",
          "explanation": "The type coordinates several responsibilities.",
          "severity": "warning",
          "startLine": 1,
          "endLine": 6,
          "evidence": [
            {
              "description": "The type owns persistence behavior.",
              "startLine": 3,
              "endLine": 5,
              "excerpt": "    func submit() {\\n        repository.save()\\n    }"
            }
          ]
        }
        """
    }

    private func findingJSON(
        ruleID: String,
        filePath: String,
        startLine: Int,
        endLine: Int
    ) -> String {
        """
        {
          "ruleID": "\(ruleID)",
          "filePath": "\(filePath)",
          "explanation": "Visible evidence supports this candidate.",
          "severity": "warning",
          "startLine": \(startLine),
          "endLine": \(endLine),
          "evidence": [
            {
              "description": "The complete type is visible.",
              "startLine": 1,
              "endLine": 1,
              "excerpt": "final class Checkout {"
            }
          ]
        }
        """
    }

    private var godObjectKnowledge: RuleKnowledge {
        RuleKnowledge(
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern,
            defaultSeverity: .warning,
            definition: "A type owns multiple unrelated responsibilities.",
            evidenceCriteria: ["Several responsibilities are visible."],
            classificationGuidance: ["Require visible evidence."],
            severityGuidance: ["Use warning for several responsibilities."],
            refactoringGuardrails: ["Preserve behavior."]
        )
    }

    private func expectDiagnostic(
        _ result: CodeAnalysisResponseParsingResult,
        code: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(result.candidates.isEmpty, sourceLocation: sourceLocation)
        #expect(result.diagnostics.count == 1, sourceLocation: sourceLocation)
        #expect(
            result.diagnostics.first?.code == code,
            sourceLocation: sourceLocation
        )
        #expect(
            result.diagnostics.first?.severity == .warning,
            sourceLocation: sourceLocation
        )
        #expect(
            result.diagnostics.first?.message.isEmpty == false,
            sourceLocation: sourceLocation
        )
    }
}

private struct StubCodeAnalysisKnowledgeProvider: RuleKnowledgeProviding {
    let knowledge: [RuleKnowledge]

    var allKnowledge: [RuleKnowledge] {
        knowledge
    }

    func knowledge(for ruleID: String) -> RuleKnowledge? {
        knowledge.first { $0.ruleID == ruleID }
    }

    func knowledge(in group: RuleKnowledgeGroup) -> [RuleKnowledge] {
        knowledge.filter { $0.group == group }
    }
}

private extension String {
    func replacingOccurrences(
        of target: String,
        with replacement: String,
        maxReplacements: Int
    ) -> String {
        guard maxReplacements > 0,
              let range = range(of: target) else {
            return self
        }

        return replacingCharacters(in: range, with: replacement)
    }
}
