import ArcanDomain
import Foundation
import Testing

@Suite("Domain model JSON encoding and decoding")
struct DomainModelCodableTests {
    @Test("review request encoding and decoding of values")
    func reviewRequest() throws {
        let request = ReviewRequest(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            repositoryRoot: "/Users/developer/Project",
            selectedFiles: ["Sources/App.swift", "Sources/Feature.swift"],
            changes: [
                CodeChange(
                    filePath: "Sources/App.swift",
                    addedLineRanges: [
                        ChangedLineRange(startLine: 8, endLine: 10)
                    ],
                    modifiedLineRanges: [
                        ChangedLineRange(startLine: 20, endLine: 21)
                    ],
                    deletedLineRanges: [
                        DeletedLineRange(
                            originalStartLine: 15,
                            originalEndLine: 16
                        )
                    ]
                )
            ],
            selectedReviewTypes: [.godObject, .style],
            configuration: ArcanConfiguration(
                schemaVersion: 1,
                godObjectThresholds: GodObjectThresholds(
                    maximumLines: 300,
                    maximumMethods: 15,
                    maximumStoredProperties: 12,
                    minimumTriggeredSignals: 3
                )
            )
        )

        let data = try encodeToJSON(request)
        let decoded = try decodeFromJSON(ReviewRequest.self, from: data)

        #expect(decoded == request)
    }

    @Test("review report encoding and decoding of values")
    func reviewReport() throws {
        let suggestion = Suggestion(
            summary: "Split networking from presentation logic.",
            steps: ["Extract an API client", "Move view state into a view model"],
            codeExample: """
            struct APIClient {
                func load() async throws {}
            }
            """
        )
        let finding = Finding(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            ruleID: "ARCAN-GOD-001",
            externalRuleID: "type_body_length",
            title: "God Object candidate",
            category: .antiPattern,
            severity: .warning,
            filePath: "Sources/LargeCoordinator.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 30,
                endColumn: 2
            ),
            explanation: "The type has too many responsibilities.",
            evidence: [
                Evidence(
                    metric: "methods",
                    observedValue: 30,
                    thresholdValue: 25
                )
            ],
            suggestion: suggestion,
            sources: ["god-object", "llm.general"],
            metadata: [
                "typeName": .string("LargeCoordinator"),
                "lineCount": .integer(30),
                "isExtension": .boolean(false),
                "score": .decimal(0.75)
            ]
        )
        let analyzerResult = AnalyzerResult(
            analyzerID: "god-object",
            candidates: [],
            tool: ToolMetadata(name: "SwiftLint", version: "0.63.2"),
            durationMilliseconds: 17
        )
        let report = ReviewReport(
            schemaVersion: ReviewReport.currentSchemaVersion,
            requestID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            findings: [finding],
            analyzerResults: [analyzerResult]
        )

        let data = try encodeToJSON(report)
        
        let decoded = try decodeFromJSON(ReviewReport.self, from: data)

        #expect(decoded == report)
        #expect(decoded.findings.first?.externalRuleID == "type_body_length")
        #expect(decoded.findings.first?.suggestion == suggestion)
        #expect(
            decoded.findings.first?.suggestion?.codeExample
                == suggestion.codeExample
        )
        #expect(decoded.findings.first?.category == .antiPattern)
        #expect(
            decoded.findings.first?.sources
                == ["god-object", "llm.general"]
        )
        #expect(
            decoded.findings.first?.metadata["lineCount"] == .integer(30)
        )
        #expect(
            decoded.analyzerResults.first?.tool
                == ToolMetadata(name: "SwiftLint", version: "0.63.2")
        )
        #expect(decoded.analyzerResults.first == analyzerResult)
    }

    @Test("suggestions without a code example remain decodable")
    func suggestionWithoutCodeExample() throws {
        let data = Data(
            """
            {
              "summary": "Extract a service.",
              "steps": ["Move related methods."]
            }
            """.utf8
        )

        let suggestion = try decodeFromJSON(Suggestion.self, from: data)

        #expect(suggestion.codeExample == nil)
    }

    @Test("copying a finding with a suggestion preserves detection data")
    func findingWithSuggestionPreservesDetectionData() {
        let original = Finding(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            ruleID: "ARCAN-GOD-001",
            externalRuleID: "external-rule",
            title: "God Object candidate",
            category: .antiPattern,
            severity: .warning,
            filePath: "Sources/App.swift",
            range: SourceRange(
                startLine: 2,
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
                summary: "Generic guidance.",
                steps: ["Split the type."]
            ),
            sources: ["god-object"],
            metadata: ["typeName": .string("App")]
        )
        let targetedSuggestion = Suggestion(
            summary: "Extract persistence from App.",
            steps: ["Create an AppRepository."],
            codeExample: "struct AppRepository {}"
        )

        let findingWithTargetedSuggestion = original.withSuggestion(
            targetedSuggestion
        )

        #expect(findingWithTargetedSuggestion.suggestion == targetedSuggestion)
        #expect(findingWithTargetedSuggestion.id == original.id)
        #expect(findingWithTargetedSuggestion.ruleID == original.ruleID)
        #expect(
            findingWithTargetedSuggestion.externalRuleID
                == original.externalRuleID
        )
        #expect(findingWithTargetedSuggestion.title == original.title)
        #expect(findingWithTargetedSuggestion.category == original.category)
        #expect(findingWithTargetedSuggestion.severity == original.severity)
        #expect(findingWithTargetedSuggestion.filePath == original.filePath)
        #expect(findingWithTargetedSuggestion.range == original.range)
        #expect(
            findingWithTargetedSuggestion.explanation == original.explanation
        )
        #expect(findingWithTargetedSuggestion.evidence == original.evidence)
        #expect(findingWithTargetedSuggestion.sources == original.sources)
        #expect(findingWithTargetedSuggestion.metadata == original.metadata)
        #expect(
            original.suggestion?.summary == "Generic guidance."
        )
    }

    @Test("finding metadata values encode as JSON scalar values")
    func findingMetadataScalars() throws {
        let values: [String: FindingMetadataValue] = [
            "string": .string("value"),
            "integer": .integer(8),
            "decimal": .decimal(1.5),
            "boolean": .boolean(true)
        ]

        let data = try encodeToJSON(values)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let decoded = try decodeFromJSON(
            [String: FindingMetadataValue].self,
            from: data
        )

        #expect(object["string"] as? String == "value")
        #expect(object["integer"] as? Int == 8)
        #expect(object["decimal"] as? Double == 1.5)
        #expect(object["boolean"] as? Bool == true)
        #expect(decoded == values)
    }

    @Test("legacy finding defaults category and metadata")
    func legacyFindingDefaults() throws {
        let data = Data(
            """
            {
              "id": "11111111-2222-3333-4444-555555555555",
              "ruleID": "legacy-rule",
              "title": "Legacy finding",
              "severity": "warning",
              "filePath": "Sources/App.swift",
              "explanation": "Created before normalized finding fields.",
              "evidence": []
            }
            """.utf8
        )

        let finding = try decodeFromJSON(Finding.self, from: data)

        #expect(finding.category == .uncategorized)
        #expect(finding.sources.isEmpty)
        #expect(finding.metadata.isEmpty)
    }

    @Test("analyzer result requires the candidate contract")
    func analyzerResultRequiresCandidates() throws {
        let data = Data(
            """
            {
              "analyzerID": "invalid",
              "tool": null,
              "executionStatus": "completed",
              "diagnostics": [],
              "durationMilliseconds": 0,
              "llmExecutionMetadata": null
            }
            """.utf8
        )

        #expect(throws: DecodingError.self) {
            try decodeFromJSON(AnalyzerResult.self, from: data)
        }
    }

    @Test("LLM analyzer candidates and execution metadata round trip")
    func llmAnalyzerResultRoundTrip() throws {
        let candidate = try FindingCandidate(
            candidateID: UUID(
                uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
            )!,
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            explanation: "The type has unrelated responsibilities.",
            filePath: "Sources/App.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 3,
                endColumn: 2
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [
                .sourceCode(SourceCodeEvidence(
                    description: "Several responsibilities are present.",
                    range: SourceRange(
                        startLine: 1,
                        startColumn: 1,
                        endLine: 3,
                        endColumn: 2
                    ),
                    excerpt: "struct App {}"
                ))
            ],
            sourceIdentifiers: [
                "llm-code-analysis",
                "llm-provider:ollama",
                "llm-model:qwen"
            ]
        )
        let result = AnalyzerResult(
            analyzerID: "llm-code-analysis",
            candidates: [candidate],
            llmExecutionMetadata: LLMAnalyzerExecutionMetadata(
                providerID: "ollama",
                modelID: "qwen",
                requestCount: 2,
                usage: LLMTokenUsageMetadata(
                    inputTokens: 100,
                    outputTokens: 20,
                    totalTokens: 120
                ),
                providerDurationMilliseconds: 45
            )
        )

        let decoded = try decodeFromJSON(
            AnalyzerResult.self,
            from: encodeToJSON(result)
        )

        #expect(decoded == result)
    }

    @Test("review analysis requires candidates in its serialized contract")
    func reviewAnalysisRequiresCandidates() {
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "requestID": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
              "analyzerResults": [],
              "diagnostics": []
            }
            """.utf8
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ReviewAnalysisResult.self, from: data)
        }
    }

    @Test("skipped analyzer result preserves its diagnostic")
    func skippedAnalyzerResult() throws {
        let result = AnalyzerResult(
            analyzerID: "swiftlint",
            candidates: [],
            tool: ToolMetadata(name: "SwiftLint"),
            executionStatus: .skipped,
            diagnostics: [
                AnalyzerDiagnostic(
                    code: "ARCAN-SWIFTLINT-UNAVAILABLE",
                    severity: .warning,
                    message: "SwiftLint was not found."
                )
            ]
        )

        let decoded = try decodeFromJSON(
            AnalyzerResult.self,
            from: encodeToJSON(result)
        )

        #expect(decoded == result)
        #expect(decoded.executionStatus == .skipped)
        #expect(
            decoded.diagnostics.first?.code
                == "ARCAN-SWIFTLINT-UNAVAILABLE"
        )
    }

    @Test("source context window encoding and decoding of values")
    func sourceContextWindow() throws {
        let context = SourceContextWindow(
            filePath: "Sources/App.swift",
            changedLineRange: ChangedLineRange(startLine: 10, endLine: 11),
            includedLineRange: SourceLineRange(startLine: 7, endLine: 14),
            sourceText: "func update() {}",
            containingType: TypeStructuralMetrics(
                name: "App",
                kind: .class,
                range: SourceRange(
                    startLine: 1,
                    startColumn: 1,
                    endLine: 30,
                    endColumn: 2
                ),
                lineCount: 30,
                methodCount: 4,
                propertyCount: 3
            )
        )

        let data = try encodeToJSON(context)
        let decoded = try decodeFromJSON(SourceContextWindow.self, from: data)

        #expect(decoded == context)
    }

    @Test(
        "severity values encoding and decoding",
        arguments: Severity.allCases
    )
    func severity(severity: Severity) throws {
        let data = try encodeToJSON(severity)
        #expect(try decodeFromJSON(Severity.self, from: data) == severity)
    }
    
    private func encodeToJSON<Value: Encodable>(_ value: Value) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func decodeFromJSON<Value: Decodable>(
        _ type: Value.Type,
        from data: Data
    ) throws -> Value {
        try JSONDecoder().decode(type, from: data)
    }
}
