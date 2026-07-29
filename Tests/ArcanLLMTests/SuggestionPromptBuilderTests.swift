import ArcanDomain
import ArcanKnowledge
import ArcanLLM
import Foundation
import Testing

@Suite("Suggestion prompt builder")
struct SuggestionPromptBuilderTests {
    @Test("version 1 prompt matches the golden fixture")
    func buildsGoldenPrompt() throws {
        let builder = SuggestionPromptBuilder(
            knowledgeProvider: StubRuleKnowledgeProvider(
                knowledge: godObjectKnowledge
            )
        )

        let prompt = try builder.build(
            finding: godObjectFinding,
            sourceContext: sourceContext
        )
        let expectedPrompt = try goldenPrompt()

        #expect(prompt.templateID == "arcan.suggestion")
        #expect(prompt.templateVersion == 1)
        #expect(prompt.text == expectedPrompt)
        #expect(!prompt.text.contains("sk-live-super-secret-value"))
        #expect(prompt.text.contains("[REDACTED]"))
        #expect(!prompt.text.contains("UNRELATED_METADATA"))
        #expect(!prompt.text.contains("PREVIOUS_SUGGESTION"))
        #expect(!prompt.text.contains("/Users/alice/Developer/Shop"))
    }

    @Test("building the same input produces identical output")
    func buildsDeterministically() throws {
        let builder = SuggestionPromptBuilder(
            knowledgeProvider: StubRuleKnowledgeProvider(
                knowledge: godObjectKnowledge
            )
        )

        let firstPrompt = try builder.build(
            finding: godObjectFinding,
            sourceContext: sourceContext
        )
        let secondPrompt = try builder.build(
            finding: godObjectFinding,
            sourceContext: sourceContext
        )

        #expect(firstPrompt == secondPrompt)
    }

    @Test("common credentials are removed from source context")
    func redactsCommonCredentials() throws {
        let context = makeSourceContext(
            sourceText: """
            let password = "open-sesame"
            let authorization = "Bearer abcdefghijklmnopqrstuvwxyz"
            let githubToken = "ghp_abcdefghijklmnopqrstuvwxyz123456"
            """
        )
        let builder = SuggestionPromptBuilder(
            knowledgeProvider: StubRuleKnowledgeProvider(
                knowledge: godObjectKnowledge
            )
        )

        let prompt = try builder.build(
            finding: godObjectFinding,
            sourceContext: context
        )

        #expect(!prompt.text.contains("open-sesame"))
        #expect(!prompt.text.contains("abcdefghijklmnopqrstuvwxyz"))
        #expect(prompt.text.contains("[REDACTED]"))
    }

    @Test("unknown rules cannot produce an ungrounded prompt")
    func rejectsUnknownRule() {
        let builder = SuggestionPromptBuilder(
            knowledgeProvider: StubRuleKnowledgeProvider(knowledge: nil)
        )

        expectBuildingError(.unknownRuleID("ARCAN-GOD-001")) {
            _ = try builder.build(
                finding: godObjectFinding,
                sourceContext: sourceContext
            )
        }
    }

    @Test("source excerpts exceeding the configured byte limit are rejected")
    func rejectsOversizedSourceExcerpt() {
        let builder = SuggestionPromptBuilder(
            knowledgeProvider: StubRuleKnowledgeProvider(
                knowledge: godObjectKnowledge
            ),
            limits: SuggestionPromptLimits(
                maximumSourceUTF8Bytes: 10,
                maximumPromptUTF8Bytes: 10_000
            )
        )
        let actualBytes = sourceContext.sourceText.utf8.count

        expectBuildingError(
            .sourceExcerptTooLarge(
                actualBytes: actualBytes,
                maximumBytes: 10
            )
        ) {
            _ = try builder.build(
                finding: godObjectFinding,
                sourceContext: sourceContext
            )
        }
    }

    @Test("complete prompts exceeding the configured byte limit are rejected")
    func rejectsOversizedPrompt() {
        let builder = SuggestionPromptBuilder(
            knowledgeProvider: StubRuleKnowledgeProvider(
                knowledge: godObjectKnowledge
            ),
            limits: SuggestionPromptLimits(
                maximumSourceUTF8Bytes: 10_000,
                maximumPromptUTF8Bytes: 100
            )
        )

        do {
            _ = try builder.build(
                finding: godObjectFinding,
                sourceContext: sourceContext
            )
            Issue.record("Expected prompt construction to fail.")
        } catch let error as SuggestionPromptBuildingError {
            guard case let .promptTooLarge(actualBytes, maximumBytes) = error else {
                Issue.record("Unexpected prompt error: \(error)")
                return
            }

            #expect(actualBytes > maximumBytes)
            #expect(maximumBytes == 100)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private var godObjectKnowledge: RuleKnowledge {
        RuleKnowledge(
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern,
            defaultSeverity: .warning,
            definition: "A type centralizes multiple unrelated responsibilities.",
            evidenceCriteria: [
                "Multiple configured structural thresholds are exceeded."
            ],
            classificationGuidance: [
                "Require evidence of multiple responsibilities."
            ],
            severityGuidance: [
                "Use warning when multiple signals are present."
            ],
            refactoringGuardrails: [
                "Separate unrelated responsibilities.",
                "Preserve observable behavior."
            ]
        )
    }

    private var godObjectFinding: SuggestionFinding {
        SuggestionFinding(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            category: .antiPattern,
            severity: .warning,
            filePath: "/Users/alice/Developer/Shop/Sources/Checkout/CheckoutCoordinator.swift",
            range: SourceRange(
                startLine: 10,
                startColumn: 1,
                endLine: 90,
                endColumn: 2
            ),
            explanation: "The type exceeds multiple structural thresholds.",
            evidence: [
                Evidence(
                    metric: "methods",
                    observedValue: 24,
                    thresholdValue: 15
                ),
                Evidence(
                    metric: "lines",
                    observedValue: 420,
                    thresholdValue: 300
                )
            ],
            suggestion: Suggestion(
                summary: "PREVIOUS_SUGGESTION",
                steps: ["Do not place this in the prompt."]
            ),
            sources: ["god-object"],
            metadata: ["raw": .string("UNRELATED_METADATA")]
        )
    }

    private var sourceContext: SourceContextWindow {
        makeSourceContext(
            sourceText: """
            func validateOrder() throws {
                try validator.validate(order)
            }
            func submitOrder() async throws {
                let apiToken = "sk-live-super-secret-value"
                try await apiClient.submit(order, token: apiToken)
            }
            notifyCustomer()
            """
        )
    }

    private func makeSourceContext(sourceText: String) -> SourceContextWindow {
        SourceContextWindow(
            filePath: "/Users/alice/Developer/Shop/Sources/Checkout/CheckoutCoordinator.swift",
            changedLineRange: ChangedLineRange(startLine: 42, endLine: 45),
            includedLineRange: SourceLineRange(startLine: 40, endLine: 47),
            sourceText: sourceText,
            containingType: nil
        )
    }

    private func goldenPrompt() throws -> String {
        let url = try #require(
            Bundle.module.url(
                forResource: "god-object-suggestion-v1",
                withExtension: "txt",
                subdirectory: "Fixtures"
            )
        )

        return try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .newlines)
    }

    private func expectBuildingError(
        _ expectedError: SuggestionPromptBuildingError,
        operation: () throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        do {
            try operation()
            Issue.record(
                "Expected prompt construction to fail with \(expectedError).",
                sourceLocation: sourceLocation
            )
        } catch let error as SuggestionPromptBuildingError {
            #expect(error == expectedError, sourceLocation: sourceLocation)
        } catch {
            Issue.record(
                "Unexpected error: \(error)",
                sourceLocation: sourceLocation
            )
        }
    }
}

private struct StubRuleKnowledgeProvider: RuleKnowledgeProviding {
    let knowledge: RuleKnowledge?

    var allKnowledge: [RuleKnowledge] {
        knowledge.map { [$0] } ?? []
    }

    func knowledge(for ruleID: String) -> RuleKnowledge? {
        guard knowledge?.ruleID == ruleID else { return nil }
        return knowledge
    }

    func knowledge(
        in group: RuleKnowledgeGroup
    ) -> [RuleKnowledge] {
        allKnowledge.filter { $0.group == group }
    }
}
