import ArcanDomain
import ArcanLLM
import Foundation
import Testing

@Suite("Issue-categorization response parser")
struct IssueCategorizationResponseParserTests {
    @Test("valid grouped response becomes a grounded categorization")
    func parsesValidResponse() throws {
        let result = parser.parse(
            response(decisions: [decisionJSON(candidateIDs: candidateIDs)]),
            candidates: candidates,
            allowedRuleIDs: allowedRuleIDs
        )
        let categorization = try #require(result.categorization)
        let decision = try #require(categorization.decisions.first)

        #expect(result.diagnostics.isEmpty)
        #expect(categorization.summary == "The analyzers agree on one issue.")
        #expect(categorization.decisions.count == 1)
        #expect(decision.candidateIDs == candidateIDs)
        #expect(decision.assessment == .confirmed)
        #expect(decision.category == .antiPattern)
        #expect(decision.severity == .warning)
        #expect(decision.canonicalRuleID == "ARCAN-GOD-001")
        #expect(decision.title == "God Object")
        #expect(decision.rationale == "Both candidates describe the same issue.")
    }

    @Test("summary is required, nonblank, and bounded")
    func validatesSummary() {
        let missing = #"{"decisions":[]}"#
        expectDiagnostic(
            parser.parse(
                missing,
                candidates: candidates,
                allowedRuleIDs: allowedRuleIDs
            ),
            code: "ARCAN-LLM-CATEGORIZATION-INVALID-SCHEMA"
        )
        expectDiagnostic(
            parser.parse(
                response(
                    summary: "   ",
                    decisions: [decisionJSON(candidateIDs: candidateIDs)]
                ),
                candidates: candidates,
                allowedRuleIDs: allowedRuleIDs
            ),
            code: "ARCAN-LLM-CATEGORIZATION-INVALID-SUMMARY"
        )

        let limited = IssueCategorizationResponseParser(
            limits: IssueCategorizationResponseLimits(
                maximumSummaryUTF8Bytes: 5
            )
        )
        expectDiagnostic(
            limited.parse(
                response(decisions: [decisionJSON(candidateIDs: candidateIDs)]),
                candidates: candidates,
                allowedRuleIDs: allowedRuleIDs
            ),
            code: "ARCAN-LLM-CATEGORIZATION-INVALID-SUMMARY"
        )
    }

    @Test("unknown candidate IDs reject the complete response")
    func rejectsUnknownCandidate() {
        let unknown = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let result = parser.parse(
            response(decisions: [decisionJSON(candidateIDs: [unknown])]),
            candidates: candidates,
            allowedRuleIDs: allowedRuleIDs
        )

        expectDiagnostic(
            result,
            code: "ARCAN-LLM-CATEGORIZATION-UNKNOWN-CANDIDATE"
        )
        #expect(result.diagnostics[0].message.contains(unknown.uuidString))
    }

    @Test("candidate IDs cannot repeat within or across decisions")
    func rejectsDuplicateCandidates() {
        let first = candidateIDs[0]
        let second = candidateIDs[1]
        let withinGroup = response(decisions: [
            decisionJSON(candidateIDs: [first, first]),
            decisionJSON(candidateIDs: [second])
        ])
        let acrossGroups = response(decisions: [
            decisionJSON(candidateIDs: [first]),
            decisionJSON(candidateIDs: [first, second])
        ])

        for value in [withinGroup, acrossGroups] {
            expectDiagnostic(
                parser.parse(
                    value,
                    candidates: candidates,
                    allowedRuleIDs: allowedRuleIDs
                ),
                code: "ARCAN-LLM-CATEGORIZATION-DUPLICATE-CANDIDATE"
            )
        }
    }

    @Test("unsupported assessment, category, and severity are rejected")
    func rejectsUnsupportedEnums() {
        let valid = response(decisions: [
            decisionJSON(candidateIDs: candidateIDs)
        ])
        let invalidValues = [
            valid.replacingOccurrences(
                of: #""assessment":"confirmed""#,
                with: #""assessment":"ignored""#
            ),
            valid.replacingOccurrences(
                of: #""category":"antiPattern""#,
                with: #""category":"security""#
            ),
            valid.replacingOccurrences(
                of: #""severity":"warning""#,
                with: #""severity":"high""#
            )
        ]

        for value in invalidValues {
            expectDiagnostic(
                parser.parse(
                    value,
                    candidates: candidates,
                    allowedRuleIDs: allowedRuleIDs
                ),
                code: "ARCAN-LLM-CATEGORIZATION-INVALID-SCHEMA"
            )
        }

        let uncategorized = valid.replacingOccurrences(
            of: #""category":"antiPattern""#,
            with: #""category":"uncategorized""#
        )
        expectDiagnostic(
            parser.parse(
                uncategorized,
                candidates: candidates,
                allowedRuleIDs: allowedRuleIDs
            ),
            code: "ARCAN-LLM-CATEGORIZATION-INVALID-DECISION"
        )
    }

    @Test("malformed JSON and unknown properties are rejected")
    func rejectsMalformedAndExpandedSchema() {
        expectDiagnostic(
            parser.parse(
                #"{"summary":"Broken","decisions":[}"#,
                candidates: candidates,
                allowedRuleIDs: allowedRuleIDs
            ),
            code: "ARCAN-LLM-CATEGORIZATION-INVALID-JSON"
        )

        let expanded = response(decisions: [
            decisionJSON(candidateIDs: candidateIDs)
        ]).replacingOccurrences(
            of: #""summary":"The analyzers agree on one issue.""#,
            with: #""summary":"The analyzers agree on one issue.","extra":true"#
        )
        expectDiagnostic(
            parser.parse(
                expanded,
                candidates: candidates,
                allowedRuleIDs: allowedRuleIDs
            ),
            code: "ARCAN-LLM-CATEGORIZATION-INVALID-SCHEMA"
        )
    }

    @Test("summary cannot replace individual candidate decisions")
    func rejectsEmptyDecisions() {
        expectDiagnostic(
            parser.parse(
                response(decisions: []),
                candidates: candidates,
                allowedRuleIDs: allowedRuleIDs
            ),
            code: "ARCAN-LLM-CATEGORIZATION-INVALID-DECISION"
        )
    }

    @Test("every supplied candidate must be assessed")
    func rejectsMissingCandidate() {
        let result = parser.parse(
            response(decisions: [
                decisionJSON(candidateIDs: [candidateIDs[0]])
            ]),
            candidates: candidates,
            allowedRuleIDs: allowedRuleIDs
        )

        expectDiagnostic(
            result,
            code: "ARCAN-LLM-CATEGORIZATION-MISSING-CANDIDATE"
        )
        #expect(result.diagnostics[0].message.contains(candidateIDs[1].uuidString))
    }

    @Test("canonical rule IDs must come from supplied knowledge")
    func rejectsUnknownRule() {
        let value = response(decisions: [
            decisionJSON(
                candidateIDs: candidateIDs,
                canonicalRuleID: "ARCAN-INVENTED-001"
            )
        ])
        expectDiagnostic(
            parser.parse(
                value,
                candidates: candidates,
                allowedRuleIDs: allowedRuleIDs
            ),
            code: "ARCAN-LLM-CATEGORIZATION-UNKNOWN-RULE"
        )
    }

    @Test("valid JSON may be wrapped in one Markdown fence")
    func acceptsMarkdownFence() throws {
        let value = response(decisions: [
            decisionJSON(candidateIDs: candidateIDs)
        ])
        let result = parser.parse(
            "```json\n\(value)\n```",
            candidates: candidates,
            allowedRuleIDs: allowedRuleIDs
        )

        #expect(try #require(result.categorization).decisions.count == 1)
        #expect(result.diagnostics.isEmpty)
    }

    private var parser: IssueCategorizationResponseParser {
        IssueCategorizationResponseParser()
    }

    private var candidateIDs: [UUID] {
        candidates.map(\.candidateID)
    }

    private var allowedRuleIDs: Set<String> {
        ["ARCAN-GOD-001"]
    }

    private var candidates: [FindingCandidate] {
        [
            try! candidate(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                source: "god-object"
            ),
            try! candidate(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                source: "llm-code-analysis"
            )
        ]
    }

    private func candidate(
        id: UUID,
        source: String
    ) throws -> FindingCandidate {
        try FindingCandidate(
            candidateID: id,
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            explanation: "The type has too many responsibilities.",
            filePath: "Sources/Checkout.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 10,
                endColumn: 2
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [.metric(MetricEvidence(
                metricName: "methodCount",
                observedValue: 40,
                thresholdValue: 30
            ))],
            sourceIdentifiers: [source]
        )
    }

    private func response(
        summary: String = "The analyzers agree on one issue.",
        decisions: [String]
    ) -> String {
        """
        {"summary":"\(summary)","decisions":[\(decisions.joined(separator: ","))]}
        """
    }

    private func decisionJSON(
        candidateIDs: [UUID],
        canonicalRuleID: String = "ARCAN-GOD-001"
    ) -> String {
        let ids = candidateIDs.map { "\"\($0.uuidString)\"" }
            .joined(separator: ",")
        return """
        {"candidateIDs":[\(ids)],"assessment":"confirmed","category":"antiPattern","severity":"warning","canonicalRuleID":"\(canonicalRuleID)","title":"God Object","rationale":"Both candidates describe the same issue."}
        """
    }

    private func expectDiagnostic(
        _ result: IssueCategorizationParsingResult,
        code: String
    ) {
        #expect(result.categorization == nil)
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics.first?.code == code)
    }
}
