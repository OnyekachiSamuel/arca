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
      .success(
        llmResponse(
          text: """
            {
              "findings": [
                {
                  "title": "Large Class",
                  "explanation": "The type owns substantial state and behavior.",
                  "evidence": [
                    {
                      "description": "The type owns state.",
                      "startLine": 2,
                      "endLine": 2
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
    #expect(candidate.issueType == nil)
    #expect(candidate.analyzerMetadata["promptVariant"] == .string("baseline"))
    #expect(requests.count == 1)
    #expect(requests[0].prompt.contains("Variant: baseline"))
    #expect(!requests[0].prompt.contains("ARCA-GOD-001"))
  }

  @Test("analyzes every selected file and records provenance and usage")
  func analyzesEveryFile() async throws {
    let provider = RecordingCodeAnalysisProvider(responses: [
      .success(response()),
      .success(response()),
    ])
    let analyzer = makeAnalyzer(provider: provider)

    let result = try await analyzer.analyze(
      context: context(files: [
        source(path: "/project/First.swift"),
        source(path: "/project/Second.swift"),
      ]))

    #expect(result.analyzerID == "llm-code-analysis")
    #expect(
      result.candidates.map(\.filePath) == [
        "First.swift", "Second.swift",
      ])
    #expect(result.diagnostics.isEmpty)
    #expect(await provider.requests.count == 2)
    #expect(
      result.candidates.allSatisfy {
        $0.sourceIdentifiers == [
          "llm-code-analysis",
          "llm-provider:mock-provider",
          "llm-model:mock-model",
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
    #expect(
      requests.allSatisfy {
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

  @Test("source excerpts are extracted by ARCA from the reported lines")
  func extractsSourceEvidence() async throws {
    let provider = RecordingCodeAnalysisProvider(responses: [
      .success(response())
    ])

    let result = try await makeAnalyzer(provider: provider).analyze(
      context: context(files: [source(path: "/project/App.swift")])
    )

    #expect(result.candidates.count == 1)
    #expect(result.diagnostics.isEmpty)
    #expect(result.candidates.first?.evidence.first?.excerpt == "    let value = 1")
  }

  @Test("provider failure becomes a diagnostic and later files continue")
  func reportsProviderFailureAndContinues() async throws {
    let provider = RecordingCodeAnalysisProvider(responses: [
      .failure(MockProviderError.failed),
      .success(response()),
    ])

    let result = try await makeAnalyzer(provider: provider).analyze(
      context: context(files: [
        source(path: "/project/First.swift"),
        source(path: "/project/Second.swift"),
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

  private func response() -> LLMResponse {
    llmResponse(
      text: """
        {
          "findings": [
            {
              "ruleID": "ARCA-GOD-001",
              "explanation": "The type owns unrelated responsibilities.",
              "evidence": [
                {
                  "description": "The type owns state.",
                  "startLine": 2,
                  "endLine": 2
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
      reviewType: .godObject,
      category: "architecture",
      issueType: .antiPattern,
      title: "God Object candidate",
      problemContext: "A type owns unrelated responsibilities.",
      expectedBehavior: "Keep types focused.",
      violationCriteria: "Several responsibilities are visible.",
      knowledgeFile: "references/ARCA-GOD-001.md",
      supportingKnowledge: "# God Object"
    ),
    RuleKnowledge(
      ruleID: "ARCA-LONG-METHOD-001",
      reviewType: .swift,
      category: "complexity",
      issueType: .codeSmell,
      title: "Long Method candidate",
      problemContext: "A method is too complex.",
      expectedBehavior: "Keep methods focused.",
      violationCriteria: "Several distinct operations are visible.",
      knowledgeFile: "references/ARCA-LONG-METHOD-001.md",
      supportingKnowledge: "# Long Method"
    ),
  ]

  func knowledge(for ruleID: String) -> RuleKnowledge? {
    allKnowledge.first { $0.ruleID == ruleID }
  }

}
