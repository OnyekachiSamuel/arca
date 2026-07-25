import ArcanDomain
import ArcanKnowledge
import ArcanLLM
import Foundation
import Testing

@Suite("LLM suggestion generator")
struct LLMSuggestionGeneratorTests {
    @Test("builds a grounded request and parses a targeted suggestion")
    func generatesTargetedSuggestion() async throws {
        let provider = RecordingLLMProvider(
            response: LLMResponse(
                text: """
                {
                  "summary": "Extract persistence from CheckoutCoordinator.",
                  "steps": [
                    "Create a CheckoutRepository.",
                    "Move storage methods into the repository."
                  ],
                  "codeExample": "struct CheckoutRepository {}"
                }
                """,
                usage: LLMUsageMetadata(
                    inputTokens: 100,
                    outputTokens: 40,
                    totalTokens: 140
                ),
                durationMilliseconds: 25
            )
        )
        let generator = LLMSuggestionGenerator(
            provider: provider,
            promptBuilder: SuggestionPromptBuilder(
                knowledgeProvider: StubKnowledgeProvider()
            ),
            modelID: "qwen2.5-coder",
            timeout: .seconds(120),
            seed: 42,
            temperature: 0.2
        )

        let result = try await generator.generate(
            for: finding,
            sourceContext: sourceContext
        )
        let request = try #require(await provider.recordedRequests.first)

        #expect(
            result == .parsed(
                Suggestion(
                    summary: "Extract persistence from CheckoutCoordinator.",
                    steps: [
                        "Create a CheckoutRepository.",
                        "Move storage methods into the repository."
                    ],
                    codeExample: "struct CheckoutRepository {}"
                )
            )
        )
        #expect(request.modelID == "qwen2.5-coder")
        #expect(request.timeout == .seconds(120))
        #expect(request.seed == 42)
        #expect(request.temperature == 0.2)
        #expect(request.prompt.contains("ARCAN-GOD-001"))
        #expect(request.prompt.contains("CheckoutCoordinator"))
        #expect(request.prompt.contains("saveOrder"))
        #expect(await provider.recordedRequests.count == 1)
    }

    @Test("returns parser diagnostics for invalid model output")
    func returnsInvalidResponseDiagnostic() async throws {
        let provider = RecordingLLMProvider(
            response: LLMResponse(
                text: "not-json",
                usage: LLMUsageMetadata(),
                durationMilliseconds: 1
            )
        )
        let generator = LLMSuggestionGenerator(
            provider: provider,
            promptBuilder: SuggestionPromptBuilder(
                knowledgeProvider: StubKnowledgeProvider()
            ),
            modelID: "test-model",
            timeout: .seconds(30)
        )

        let result = try await generator.generate(
            for: finding,
            sourceContext: sourceContext
        )

        guard case let .rejected(diagnostic) = result else {
            Issue.record("Expected invalid model output to be rejected.")
            return
        }
        #expect(diagnostic.code == "ARCAN-LLM-SUGGESTION-INVALID")
    }

    private var finding: Finding {
        Finding(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            category: .antiPattern,
            severity: .warning,
            filePath: "Sources/CheckoutCoordinator.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 40,
                endColumn: 2
            ),
            explanation: "The type exceeds multiple thresholds.",
            evidence: [
                Evidence(
                    metric: "methods",
                    observedValue: 30,
                    thresholdValue: 25
                )
            ],
            suggestion: Suggestion(
                summary: "Split the type.",
                steps: ["Identify responsibilities."]
            ),
            sources: ["god-object"]
        )
    }

    private var sourceContext: SourceContextWindow {
        SourceContextWindow(
            filePath: "Sources/CheckoutCoordinator.swift",
            changedLineRange: ChangedLineRange(startLine: 20, endLine: 22),
            includedLineRange: SourceLineRange(startLine: 18, endLine: 24),
            sourceText: """
            final class CheckoutCoordinator {
                func saveOrder() {}
            }
            """,
            containingType: nil
        )
    }
}

private actor RecordingLLMProvider: LLMProvider {
    let id = "mock-provider"
    private let response: LLMResponse
    private(set) var recordedRequests: [LLMRequest] = []

    init(response: LLMResponse) {
        self.response = response
    }

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        recordedRequests.append(request)
        return response
    }
}

private struct StubKnowledgeProvider: RuleKnowledgeProviding {
    var allKnowledge: [RuleKnowledge] {
        [godObjectKnowledge]
    }

    func knowledge(for ruleID: String) -> RuleKnowledge? {
        guard ruleID == "ARCAN-GOD-001" else { return nil }
        return godObjectKnowledge
    }

    func knowledge(
        in group: RuleKnowledgeGroup
    ) -> [RuleKnowledge] {
        allKnowledge.filter { $0.group == group }
    }

    private var godObjectKnowledge: RuleKnowledge {
        RuleKnowledge(
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern,
            defaultSeverity: .warning,
            definition: "A type has too many responsibilities.",
            evidenceCriteria: ["Multiple structural thresholds are exceeded."],
            classificationGuidance: [
                "Require evidence of multiple responsibilities."
            ],
            severityGuidance: [
                "Use warning when multiple signals are present."
            ],
            refactoringGuardrails: ["Preserve observable behaviour."]
        )
    }
}
