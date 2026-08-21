import ArcaAnalysis
import ArcaAnalyzers
import ArcaDomain
import ArcaKnowledge
import ArcaLLM
import Foundation
import Testing

@Suite("LLM code analyzer")
struct LLMCodeAnalyzerTests {
    @Test("baseline analysis returns rule-free candidates through AnalyzerResult")
    func analyzesWithBaselinePrompt() async throws {
        let provider = RecordingCodeAnalysisProvider(responses: [
            .success(llmResponse(text: """
            {
              "findings": [
                {
                  "title": "Large Class",
                  "issueType": "codeSmell",
                  "filePath": "App.swift",
                  "explanation": "The type owns substantial state and behavior.",
                  "severity": "warning",
                  "startLine": 1,
                  "endLine": 3,
                  "evidence": [
                    {
                      "description": "The type owns state.",
                      "startLine": 2,
                      "endLine": 2,
                      "excerpt": "    let value = 1"
                    }
                  ]
                }
              ]
            }
            """))
        ])
        let analyzer = makeAnalyzer(
            provider: provider,
            promptVariant: .baseline,
            knowledgeProvider: nil
        )

        let result = try await analyzer.analyze(
            context: context(files: [source(path: "/project/App.swift")])
        )
        let candidate = try #require(result.candidates.first)
        let requests = await provider.requests

        #expect(result.analyzerID == "llm-code-analysis")
        #expect(candidate.ruleID == nil)
        #expect(candidate.title == "Large Class")
        #expect(candidate.proposedCategory == .general)
        #expect(candidate.analyzerMetadata["issueType"] == .string("codeSmell"))
        #expect(candidate.analyzerMetadata["promptVariant"] == .string("baseline"))
        #expect(requests.count == 1)
        #expect(requests[0].prompt.contains("Variant: baseline"))
        #expect(!requests[0].prompt.contains("ARCA-GOD-001"))
    }

    @Test("analyzes every selected file and records provenance and usage")
    func analyzesEveryFile() async throws {
        let provider = RecordingCodeAnalysisProvider(responses: [
            .success(response(path: "First.swift")),
            .success(response(path: "Second.swift"))
        ])
        let analyzer = makeAnalyzer(provider: provider)

        let result = try await analyzer.analyze(context: context(files: [
            source(path: "/project/First.swift"),
            source(path: "/project/Second.swift")
        ]))

        #expect(result.analyzerID == "llm-code-analysis")
        #expect(result.candidates.map(\.filePath) == [
            "First.swift", "Second.swift"
        ])
        #expect(result.diagnostics.isEmpty)
        #expect(await provider.requests.count == 2)
        #expect(
            result.candidates.allSatisfy {
                $0.sourceIdentifiers == [
                    "llm-code-analysis",
                    "llm-provider:mock-provider",
                    "llm-model:mock-model"
                ]
            }
        )
        #expect(
            result.llmExecutionMetadata
                == LLMExecutionMetadata(
                    providerID: "mock-provider",
                    modelID: "mock-model",
                    requestCount: 2,
                    usage: LLMTokenUsageMetadata(
                        inputTokens: 20,
                        outputTokens: 10,
                        totalTokens: 30
                    ),
                    providerDurationMilliseconds: 14
                )
        )
        let requests = await provider.requests
        #expect(requests.allSatisfy { $0.modelID == "mock-model" })
        #expect(requests.allSatisfy { $0.prompt.contains("ARCA-GOD-001") })
        #expect(requests.allSatisfy {
            !$0.prompt.contains("ARCA-LONG-METHOD-001")
        })
    }

    @Test("empty findings are a clean completed analysis")
    func acceptsNoFindings() async throws {
        let provider = RecordingCodeAnalysisProvider(responses: [
            .success(llmResponse(text: #"{"findings":[]}"#))
        ])

        let result = try await makeAnalyzer(provider: provider).analyze(
            context: context(files: [source(path: "/project/App.swift")])
        )

        #expect(result.candidates.isEmpty)
        #expect(result.diagnostics.isEmpty)
        #expect(result.executionStatus == .completed)
        #expect(result.llmExecutionMetadata?.requestCount == 1)
    }

    @Test("malformed model output becomes a parser diagnostic")
    func reportsMalformedResponse() async throws {
        let provider = RecordingCodeAnalysisProvider(responses: [
            .success(llmResponse(text: "not JSON"))
        ])

        let result = try await makeAnalyzer(provider: provider).analyze(
            context: context(files: [source(path: "/project/App.swift")])
        )

        #expect(result.candidates.isEmpty)
        #expect(
            result.diagnostics.map(\.code)
                == ["ARCA-LLM-ANALYSIS-INVALID-JSON"]
        )
    }

    @Test("review retains a candidate when its evidence lines mismatch")
    func retainsCandidateForCategorization() async throws {
        let mismatchedResponse = response(path: "App.swift").text
            .replacingOccurrences(
                of: "    let value = 1",
                with: "    let value = 2"
            )
        let provider = RecordingCodeAnalysisProvider(responses: [
            .success(llmResponse(text: mismatchedResponse))
        ])

        let result = try await makeAnalyzer(provider: provider).analyze(
            context: context(files: [source(path: "/project/App.swift")])
        )

        #expect(result.candidates.count == 1)
        #expect(result.diagnostics.map(\.code) == [
            "ARCA-LLM-ANALYSIS-EVIDENCE-EXCERPT-MISMATCH"
        ])
    }

    @Test("provider failure becomes a diagnostic and later files continue")
    func reportsProviderFailureAndContinues() async throws {
        let provider = RecordingCodeAnalysisProvider(responses: [
            .failure(MockProviderError.failed),
            .success(response(path: "Second.swift"))
        ])

        let result = try await makeAnalyzer(provider: provider).analyze(
            context: context(files: [
                source(path: "/project/First.swift"),
                source(path: "/project/Second.swift")
            ])
        )

        #expect(result.candidates.map(\.filePath) == ["Second.swift"])
        #expect(
            result.diagnostics.map(\.code)
                == ["ARCA-LLM-ANALYSIS-PROVIDER-FAILED"]
        )
        #expect(await provider.requests.count == 2)
        #expect(result.llmExecutionMetadata?.requestCount == 2)
        #expect(
            result.llmExecutionMetadata?.providerDurationMilliseconds == 7
        )
    }

    private func makeAnalyzer(
        provider: RecordingCodeAnalysisProvider,
        promptVariant: CodeAnalysisPromptVariant = .guided,
        knowledgeProvider: (any RuleKnowledgeProviding)? =
            AnalyzerKnowledgeProvider()
    ) -> LLMCodeAnalyzer {
        LLMCodeAnalyzer(
            provider: provider,
            knowledgeProvider: knowledgeProvider,
            promptVariant: promptVariant,
            modelID: "mock-model",
            timeout: .seconds(30),
            seed: 7,
            temperature: 0.1
        )
    }

    private func context(files: [SourceFile]) -> AnalysisContext {
        AnalysisContext(
            request: ReviewRequest(
                id: UUID(),
                selectedFiles: files.map(\.path),
                selectedReviewTypes: [.godObject]
            ),
            sourceFiles: files
        )
    }

    private func source(path: String) -> SourceFile {
        SourceFile(
            path: path,
            content: "struct App {\n    let value = 1\n}",
            lineCount: 3
        )
    }

    private func response(path: String) -> LLMResponse {
        llmResponse(text: """
        {
          "findings": [
            {
              "ruleID": "ARCA-GOD-001",
              "filePath": "\(path)",
              "explanation": "The type owns unrelated responsibilities.",
              "severity": "warning",
              "startLine": 1,
              "endLine": 3,
              "evidence": [
                {
                  "description": "The type owns state.",
                  "startLine": 2,
                  "endLine": 2,
                  "excerpt": "    let value = 1"
                }
              ]
            }
          ]
        }
        """)
    }

    private func llmResponse(text: String) -> LLMResponse {
        LLMResponse(
            text: text,
            usage: LLMTokenUsageMetadata(
                inputTokens: 10,
                outputTokens: 5,
                totalTokens: 15
            ),
            durationMilliseconds: 7
        )
    }
}

private actor RecordingCodeAnalysisProvider: LLMProvider {
    let id = "mock-provider"
    private var responses: [Result<LLMResponse, MockProviderError>]
    private(set) var requests: [LLMRequest] = []

    init(responses: [Result<LLMResponse, MockProviderError>]) {
        self.responses = responses
    }

    func submit(_ request: LLMRequest) async throws -> LLMResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw MockProviderError.failed }
        return try responses.removeFirst().get()
    }
}

private enum MockProviderError: Error, Sendable {
    case failed
}

private struct AnalyzerKnowledgeProvider: RuleKnowledgeProviding {
    let allKnowledge: [RuleKnowledge] = [
        RuleKnowledge(
            ruleID: "ARCA-GOD-001",
            title: "God Object candidate",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern,
            defaultSeverity: .warning,
            definition: "A type owns unrelated responsibilities.",
            evidenceCriteria: ["Several responsibilities are visible."],
            classificationGuidance: ["Require visible evidence."],
            severityGuidance: ["Use warning."],
            refactoringGuardrails: ["Preserve behavior."]
        ),
        RuleKnowledge(
            ruleID: "ARCA-LONG-METHOD-001",
            title: "Long Method candidate",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern,
            defaultSeverity: .warning,
            definition: "A method is too complex.",
            evidenceCriteria: ["Several operations are visible."],
            classificationGuidance: ["Require visible evidence."],
            severityGuidance: ["Use warning."],
            refactoringGuardrails: ["Preserve behavior."]
        )
    ]

    func knowledge(for ruleID: String) -> RuleKnowledge? {
        allKnowledge.first { $0.ruleID == ruleID }
    }

    func knowledge(in group: RuleKnowledgeGroup) -> [RuleKnowledge] {
        allKnowledge.filter { $0.group == group }
    }
}
