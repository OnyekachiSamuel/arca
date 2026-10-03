import ArcaAnalyzers
import ArcaDomain
import ArcaKnowledge
import ArcaLLM
import Foundation
import Testing

@Suite("LLM code analyzer")
struct LLMCodeAnalyzerTests {
  @Test("baseline analysis returns a rule-free candidate")
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
      promptVariant: .baseline
    )

    let result = await analyzer.analyze(
      context: context(file: source(path: "/project/App.swift"))
    )
    let candidate = try #require(result.candidates.first)
    let requests = await provider.requests

    #expect(candidate.ruleID == nil)
    #expect(candidate.title == "Large Class")
    #expect(requests.count == 1)
    #expect(requests[0].prompt.contains("your existing knowledge"))
    #expect(!requests[0].prompt.contains("RULES_AND_KNOWLEDGE"))
    #expect(!requests[0].prompt.contains("ARCA-GOD-001"))
  }

  @Test("analyzes the selected file and records usage")
  func analyzesSelectedFile() async throws {
    let provider = RecordingCodeAnalysisProvider(responses: [
      .success(response())
    ])
    let analyzer = makeAnalyzer(provider: provider)

    let result = await analyzer.analyze(
      context: context(file: source(path: "/project/App.swift")),
      rules: godObjectRules
    )

    #expect(result.candidates.map(\.filePath) == ["App.swift"])
    #expect(result.diagnostics.isEmpty)
    #expect(await provider.requests.count == 1)
    #expect(
      result.executionMetadata
        == LLMExecutionMetadata(
          providerID: "mock-provider",
          modelID: "mock-model",
          requestCount: 1,
          usage: LLMTokenUsageMetadata(
            inputTokens: 10,
            outputTokens: 5,
            totalTokens: 15
          ),
          providerDurationMilliseconds: 7
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

    let result = await makeAnalyzer(provider: provider).analyze(
      context: context(file: source(path: "/project/App.swift")),
      rules: godObjectRules
    )

    #expect(result.candidates.isEmpty)
    #expect(result.diagnostics.isEmpty)
    #expect(result.executionMetadata.requestCount == 1)
  }

  @Test("malformed model output becomes a parser diagnostic")
  func reportsMalformedResponse() async throws {
    let provider = RecordingCodeAnalysisProvider(responses: [
      .success(llmResponse(text: "not JSON"))
    ])

    let result = await makeAnalyzer(provider: provider).analyze(
      context: context(file: source(path: "/project/App.swift")),
      rules: godObjectRules
    )

    #expect(result.candidates.isEmpty)
    #expect(
      result.diagnostics.map(\.code)
        == ["ARCA-LLM-ANALYSIS-INVALID-JSON"]
    )
  }

  @Test("provider failure becomes a diagnostic")
  func reportsProviderFailure() async throws {
    let provider = RecordingCodeAnalysisProvider(responses: [
      .failure(MockProviderError.failed)
    ])

    let result = await makeAnalyzer(provider: provider).analyze(
      context: context(file: source(path: "/project/App.swift")),
      rules: godObjectRules
    )

    #expect(result.candidates.isEmpty)
    #expect(
      result.diagnostics.map(\.code)
        == ["ARCA-LLM-ANALYSIS-PROVIDER-FAILED"]
    )
    #expect(await provider.requests.count == 1)
    #expect(result.executionMetadata.requestCount == 1)
    #expect(result.executionMetadata.providerDurationMilliseconds == 0)
  }

  private func makeAnalyzer(
    provider: RecordingCodeAnalysisProvider,
    promptVariant: CodeAnalysisPromptVariant = .guided
  ) -> LLMCodeAnalyzer {
    LLMCodeAnalyzer(
      provider: provider,
      promptVariant: promptVariant,
      modelID: "mock-model",
      timeout: .seconds(30),
      seed: 7,
      temperature: 0.1
    )
  }

  private func context(file: SourceFile) -> SourceFileAnalysisContext {
    SourceFileAnalysisContext(
      filePath: URL(fileURLWithPath: file.path).lastPathComponent,
      sourceContent: file.content,
      lineCount: file.lineCount
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

private let godObjectRules: [RuleKnowledge] = [
  RuleKnowledge(
    ruleID: "ARCA-GOD-001",
    reviewType: .godObject,
    category: "architecture",
    title: "God Object candidate",
    problemContext: "A type owns unrelated responsibilities.",
    expectedBehavior: "Keep types focused.",
    violationCriteria: "Several responsibilities are visible.",
    knowledgeFile: "references/ARCA-GOD-001.md",
    supportingKnowledge: "# God Object"
  )
]
