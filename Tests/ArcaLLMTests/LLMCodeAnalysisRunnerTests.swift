import ArcaDomain
import ArcaKnowledge
import ArcaLLM
import Foundation
import Testing

@Suite("Isolated LLM code-analysis runner")
struct LLMCodeAnalysisRunnerTests {
    @Test("one prompt run records findings, provenance, usage, and settings")
    func recordsSuccessfulRun() async throws {
        let provider = ExperimentProvider(result: .success(LLMResponse(
            text: validResponse,
            usage: LLMUsageMetadata(
                inputTokens: 40,
                outputTokens: 20,
                totalTokens: 60
            ),
            durationMilliseconds: 12
        )))

        let result = await runner(provider: provider).run(
            context: context,
            reviewType: .godObject,
            promptVariant: .baseline,
            runID: runID
        )

        #expect(result.runID == runID)
        #expect(
            result.schemaVersion
                == LLMCodeAnalysisRunResult.currentSchemaVersion
        )
        #expect(result.promptVariant == .baseline)
        #expect(result.findings.count == 1)
        #expect(result.diagnostics.isEmpty)
        #expect(result.seed == 17)
        #expect(result.temperature == 0)
        #expect(result.executionMetadata == LLMExecutionMetadata(
            providerID: "mock-experiment",
            modelID: "mock-model",
            requestCount: 1,
            usage: LLMTokenUsageMetadata(
                inputTokens: 40,
                outputTokens: 20,
                totalTokens: 60
            ),
            providerDurationMilliseconds: 12
        ))
        #expect(result.findings[0].sourceIdentifiers == [
            "llm-code-analysis",
            "llm-provider:mock-experiment",
            "llm-model:mock-model"
        ])
        let requests = await provider.requests
        #expect(requests.count == 1)
        #expect(requests[0].prompt.contains("Variant: baseline"))
        #expect(!requests[0].prompt.contains(knowledge.definition))
    }

    @Test("malformed output becomes a diagnostic with provider metrics")
    func recordsParserFailure() async {
        let provider = ExperimentProvider(result: .success(LLMResponse(
            text: "not JSON",
            usage: LLMUsageMetadata(totalTokens: 4),
            durationMilliseconds: 6
        )))

        let result = await runner(provider: provider).run(
            context: context,
            reviewType: .godObject,
            promptVariant: .guided
        )

        #expect(result.findings.isEmpty)
        #expect(result.diagnostics.map(\.code) == [
            "ARCA-LLM-ANALYSIS-INVALID-JSON"
        ])
        #expect(result.executionMetadata.requestCount == 1)
        #expect(result.executionMetadata.usage.totalTokens == 4)
        #expect(result.executionMetadata.providerDurationMilliseconds == 6)
    }

    @Test("experiment retains a finding with mismatched evidence")
    func retainsFindingForHumanEvaluation() async throws {
        let response = validResponse.replacingOccurrences(
            of: "    let value = 1",
            with: "    let value = 2"
        )
        let provider = ExperimentProvider(result: .success(LLMResponse(
            text: response,
            usage: LLMUsageMetadata(),
            durationMilliseconds: 4
        )))

        let result = await runner(provider: provider).run(
            context: context,
            reviewType: .godObject,
            promptVariant: .baseline
        )

        let finding = try #require(result.findings.first)
        #expect(result.findings.count == 1)
        #expect(finding.evidence.count == 1)
        #expect(result.diagnostics.map(\.code) == [
            "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-MISMATCH"
        ])
        #expect(
            result.diagnostics[0].message
                == "Evidence 1 could not be matched exactly to source lines 2–2."
        )
    }

    @Test("provider failure becomes a diagnostic after one request")
    func recordsProviderFailure() async {
        let provider = ExperimentProvider(
            result: .failure(.unavailable)
        )

        let result = await runner(provider: provider).run(
            context: context,
            reviewType: .godObject,
            promptVariant: .guided
        )

        #expect(result.findings.isEmpty)
        #expect(result.diagnostics.map(\.code) == [
            "ARCA-LLM-ANALYSIS-PROVIDER-FAILED"
        ])
        #expect(result.executionMetadata.requestCount == 1)
        #expect(result.executionMetadata.usage == LLMTokenUsageMetadata())
        #expect(result.executionMetadata.providerDurationMilliseconds == 0)
        #expect(await provider.requests.count == 1)
    }

    private func runner(
        provider: ExperimentProvider
    ) -> LLMCodeAnalysisRunner {
        LLMCodeAnalysisRunner(
            provider: provider,
            knowledgeProvider: ExperimentKnowledgeProvider(),
            modelID: "mock-model",
            timeout: .seconds(30),
            seed: 17,
            temperature: 0
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
        {"findings":[{"ruleID":"ARCA-GOD-001","filePath":"Example.swift","explanation":"The type may own too many responsibilities.","severity":"warning","startLine":1,"endLine":3,"evidence":[{"description":"The type owns state directly.","startLine":2,"endLine":2,"excerpt":"    let value = 1"}]}]}
        """
    }

    private var runID: UUID {
        UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    }

    private var knowledge: RuleKnowledge {
        ExperimentKnowledgeProvider().allKnowledge[0]
    }
}

private actor ExperimentProvider: LLMProvider {
    nonisolated let id = "mock-experiment"
    private let result: Result<LLMResponse, ExperimentProviderError>
    private(set) var requests: [LLMRequest] = []

    init(result: Result<LLMResponse, ExperimentProviderError>) {
        self.result = result
    }

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        requests.append(request)
        return try result.get()
    }
}

private enum ExperimentProviderError: Error, Sendable {
    case unavailable
}

private struct ExperimentKnowledgeProvider: RuleKnowledgeProviding {
    let allKnowledge = [RuleKnowledge(
        ruleID: "ARCA-GOD-001",
        title: "God Object candidate",
        group: .codeSmellsAndAntiPatterns,
        category: .antiPattern,
        defaultSeverity: .warning,
        definition: "A type owns multiple unrelated responsibilities.",
        evidenceCriteria: ["Several responsibility signals are visible."],
        classificationGuidance: ["Do not classify from size alone."],
        severityGuidance: ["Use warning for a credible candidate."],
        refactoringGuardrails: []
    )]

    func knowledge(for ruleID: String) -> RuleKnowledge? {
        allKnowledge.first { $0.ruleID == ruleID }
    }

    func knowledge(in group: RuleKnowledgeGroup) -> [RuleKnowledge] {
        allKnowledge.filter { $0.group == group }
    }
}
