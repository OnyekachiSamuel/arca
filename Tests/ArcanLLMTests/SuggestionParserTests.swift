import ArcanDomain
import ArcanLLM
import Testing

@Suite("Suggestion parser")
struct SuggestionParserTests {
    @Test("parses a valid structured suggestion")
    func parsesValidJSON() {
        let parser = SuggestionParser()

        let result = parser.parse(
            """
            {
              "summary": "Extract networking responsibilities.",
              "steps": [
                "Create a focused API client.",
                "Move request methods into the client."
              ]
            }
            """
        )

        #expect(
            result == .parsed(
                Suggestion(
                    summary: "Extract networking responsibilities.",
                    steps: [
                        "Create a focused API client.",
                        "Move request methods into the client."
                    ]
                )
            )
        )
    }

    @Test("parses one JSON object wrapped in a Markdown fence")
    func parsesMarkdownWrappedJSON() {
        let parser = SuggestionParser()

        let result = parser.parse(
            """
            ```json
            {
              "summary": "Extract persistence.",
              "steps": ["Move storage methods into a repository."]
            }
            ```
            """
        )

        #expect(
            result == .parsed(
                Suggestion(
                    summary: "Extract persistence.",
                    steps: ["Move storage methods into a repository."]
                )
            )
        )
    }

    @Test("rejects missing required fields")
    func rejectsMissingFields() {
        let parser = SuggestionParser()

        let missingSummary = parser.parse(
            #"{"steps":["Extract a service."]}"#
        )
        let missingSteps = parser.parse(
            #"{"summary":"Extract a service."}"#
        )

        expectRejected(missingSummary)
        expectRejected(missingSteps)
    }

    @Test("rejects malformed JSON and surrounding prose")
    func rejectsMalformedOutput() {
        let parser = SuggestionParser()

        let malformed = parser.parse(
            #"{"summary":"Extract a service.","steps":["Move methods."]"#
        )
        let surroundedByProse = parser.parse(
            """
            Here is the suggestion:
            ```json
            {"summary":"Extract a service.","steps":["Move methods."]}
            ```
            """
        )

        expectRejected(malformed)
        expectRejected(surroundedByProse)
    }

    @Test("rejects empty summaries and steps")
    func rejectsEmptyFields() {
        let parser = SuggestionParser()

        let emptySummary = parser.parse(
            #"{"summary":"   ","steps":["Move methods."]}"#
        )
        let emptySteps = parser.parse(
            #"{"summary":"Extract a service.","steps":[]}"#
        )
        let blankStep = parser.parse(
            #"{"summary":"Extract a service.","steps":["  "]}"#
        )

        expectRejected(emptySummary)
        expectRejected(emptySteps)
        expectRejected(blankStep)
    }

    @Test("rejects responses and fields beyond their fixed safety limits")
    func rejectsOversizedContent() {
        let parser = SuggestionParser()
        let oversizedResponse = String(repeating: "x", count: 16_001)
        let oversizedSummary = String(repeating: "s", count: 501)
        let oversizedStep = String(repeating: "x", count: 2_001)
        let tooManySteps = Array(repeating: "\"step\"", count: 21)
            .joined(separator: ",")

        expectRejected(parser.parse(oversizedResponse))
        expectRejected(
            parser.parse(
                #"{"summary":"\#(oversizedSummary)","steps":["step"]}"#
            )
        )
        expectRejected(
            parser.parse(
                #"{"summary":"Summary","steps":["\#(oversizedStep)"]}"#
            )
        )
        expectRejected(
            parser.parse(
                #"{"summary":"Summary","steps":[\#(tooManySteps)]}"#
            )
        )
    }

    @Test("generated instructions remain inert text")
    func preservesGeneratedTextWithoutInterpretingIt() {
        let parser = SuggestionParser()
        let generatedInstruction = "$(touch /tmp/arcan-must-not-execute)"

        let result = parser.parse(
            #"{"summary":"Review manually.","steps":["\#(generatedInstruction)"]}"#
        )

        #expect(
            result == .parsed(
                Suggestion(
                    summary: "Review manually.",
                    steps: [generatedInstruction]
                )
            )
        )
    }

    private func expectRejected(
        _ result: SuggestionParsingResult,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard case let .rejected(diagnostic) = result else {
            Issue.record(
                "Expected the suggestion response to be rejected.",
                sourceLocation: sourceLocation
            )
            return
        }

        #expect(
            diagnostic.code == "ARCAN-LLM-SUGGESTION-INVALID",
            sourceLocation: sourceLocation
        )
        #expect(
            diagnostic.severity == .warning,
            sourceLocation: sourceLocation
        )
        #expect(!diagnostic.message.isEmpty, sourceLocation: sourceLocation)
    }
}
