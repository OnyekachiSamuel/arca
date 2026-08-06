import ArcanDomain
import ArcanKnowledge
import ArcanLLM
import Foundation
import Testing

@Suite("Issue-categorization prompt builder")
struct IssueCategorizationPromptBuilderTests {
    @Test("static candidate includes normalized details, knowledge, and response contract")
    func buildsStaticOnlyPrompt() throws {
        let candidate = try staticCandidate()

        let prompt = try IssueCategorizationPromptBuilder().build(
            candidates: [candidate],
            ruleKnowledge: [godObjectKnowledge]
        )

        #expect(prompt.templateID == "arcan.issue-categorization")
        #expect(prompt.templateVersion == 1)
        #expect(prompt.text.contains(candidate.candidateID.uuidString))
        #expect(prompt.text.contains("god-object"))
        #expect(prompt.text.contains("ARCAN-GOD-001"))
        #expect(prompt.text.contains("Sources/Checkout.swift"))
        #expect(prompt.text.contains(#""startLine" : 10"#))
        #expect(prompt.text.contains(#""endLine" : 90"#))
        #expect(prompt.text.contains(#""severity" : "warning""#))
        #expect(prompt.text.contains("methodCount"))
        #expect(prompt.text.contains(#""observedValue" : 42"#))
        #expect(prompt.text.contains(#""thresholdValue" : 30"#))
        #expect(prompt.text.contains("The type owns unrelated responsibilities."))
        #expect(prompt.text.contains(godObjectKnowledge.definition))
        #expect(prompt.text.contains(godObjectKnowledge.evidenceCriteria[0]))
        #expect(prompt.text.contains(godObjectKnowledge.classificationGuidance[0]))
        #expect(prompt.text.contains(godObjectKnowledge.severityGuidance[0]))
        #expect(prompt.text.contains(#""allowedAssessments""#))
        #expect(prompt.text.contains(#""assessment""#))
        #expect(!prompt.text.contains(#""disposition""#))
        #expect(prompt.text.contains(#""confirmed""#))
        #expect(prompt.text.contains(#""rejected""#))
        #expect(prompt.text.contains(#""uncertain""#))
        #expect(prompt.text.contains(#""antiPattern""#))
        #expect(prompt.text.contains(#""architecture""#))
        #expect(prompt.text.contains(#""style""#))
        #expect(prompt.text.contains(#""teamConvention""#))
        #expect(prompt.text.contains(#""general""#))
        #expect(!prompt.text.contains(#""uncategorized""#))
        #expect(prompt.text.contains(#""summary""#))
        #expect(prompt.text.contains(#""decisions""#))
        #expect(prompt.text.contains(#""candidateIDs""#))
        #expect(prompt.text.contains(
            "summary must not contain candidate IDs"
        ))
        #expect(prompt.text.contains(#""rationale""#))
    }

    @Test("LLM candidate preserves source evidence without adding source files")
    func buildsLLMOnlyPrompt() throws {
        let candidate = try llmCandidate()

        let prompt = try IssueCategorizationPromptBuilder().build(
            candidates: [candidate],
            ruleKnowledge: [godObjectKnowledge]
        )

        #expect(prompt.text.contains("llm-code-analysis"))
        #expect(prompt.text.contains("ollama:qwen2.5-coder:7b"))
        #expect(prompt.text.contains("The coordinator performs persistence directly."))
        #expect(prompt.text.contains("repository.save(order)"))
        #expect(prompt.text.contains(#""startLine" : 44"#))
        #expect(prompt.text.contains(#""endLine" : 44"#))
        #expect(prompt.text.contains("do not perform another source-code analysis"))
        #expect(!prompt.text.contains("complete source file"))
    }

    @Test("shared candidates remain distinct and may be grouped by the model")
    func buildsSharedCandidatePrompt() throws {
        let staticValue = try staticCandidate()
        let llmValue = try llmCandidate()

        let prompt = try IssueCategorizationPromptBuilder().build(
            candidates: [staticValue, llmValue],
            ruleKnowledge: [godObjectKnowledge]
        )

        let staticPosition = try #require(
            prompt.text.range(of: staticValue.candidateID.uuidString)
        )
        let llmPosition = try #require(
            prompt.text.range(of: llmValue.candidateID.uuidString)
        )
        #expect(staticPosition.lowerBound < llmPosition.lowerBound)
        #expect(prompt.text.contains("god-object"))
        #expect(prompt.text.contains("llm-code-analysis"))
        #expect(prompt.text.contains("ollama:qwen2.5-coder:7b"))
        #expect(prompt.text.contains("one decision for every candidate"))
        #expect(prompt.text.contains("same underlying issue"))
        #expect(prompt.text.contains("uniqueItems"))
        #expect(prompt.text.contains(
            #""enum": ["\#(staticValue.candidateID.uuidString)", "\#(llmValue.candidateID.uuidString)"]"#
        ))
    }

    @Test("rule knowledge is canonicalized without reordering candidates")
    func producesStableOutput() throws {
        let firstCandidate = try staticCandidate()
        let secondCandidate = try llmCandidate()
        let style = styleKnowledge
        let builder = IssueCategorizationPromptBuilder()

        let first = try builder.build(
            candidates: [firstCandidate, secondCandidate],
            ruleKnowledge: [style, godObjectKnowledge]
        )
        let second = try builder.build(
            candidates: [firstCandidate, secondCandidate],
            ruleKnowledge: [godObjectKnowledge, style]
        )

        #expect(first == second)
    }

    @Test("candidate explanations and excerpts redact common secrets")
    func redactsSecrets() throws {
        let candidate = try FindingCandidate(
            candidateID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            ruleID: "ARCAN-GOD-001",
            title: "Secret candidate",
            explanation: #"let apiToken = "sk-live-super-secret-value""#,
            filePath: "Sources/Secret.swift",
            range: SourceRange(
                startLine: 1,
                startColumn: 1,
                endLine: 1,
                endColumn: 20
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [.sourceCode(SourceCodeEvidence(
                description: "Credential evidence",
                range: SourceRange(
                    startLine: 1,
                    startColumn: 1,
                    endLine: 1,
                    endColumn: 20
                ),
                excerpt: #"let apiToken = "sk-live-super-secret-value""#
            ))],
            sourceIdentifiers: ["llm-code-analysis"]
        )

        let prompt = try IssueCategorizationPromptBuilder().build(
            candidates: [candidate],
            ruleKnowledge: [godObjectKnowledge]
        )

        #expect(!prompt.text.contains("sk-live-super-secret-value"))
        #expect(prompt.text.contains("[REDACTED]"))
    }

    @Test("empty candidates and knowledge are rejected")
    func rejectsMissingInputs() throws {
        expectError(.noCandidates) {
            _ = try IssueCategorizationPromptBuilder().build(
                candidates: [],
                ruleKnowledge: [godObjectKnowledge]
            )
        }
        expectError(.noRuleKnowledge) {
            _ = try IssueCategorizationPromptBuilder().build(
                candidates: [try staticCandidate()],
                ruleKnowledge: []
            )
        }
    }

    @Test("duplicate candidate and rule IDs are rejected")
    func rejectsDuplicateIdentifiers() throws {
        let candidate = try staticCandidate()
        expectError(.duplicateCandidateID(candidate.candidateID.uuidString)) {
            _ = try IssueCategorizationPromptBuilder().build(
                candidates: [candidate, candidate],
                ruleKnowledge: [godObjectKnowledge]
            )
        }
        expectError(.duplicateRuleID(godObjectKnowledge.ruleID)) {
            _ = try IssueCategorizationPromptBuilder().build(
                candidates: [candidate],
                ruleKnowledge: [godObjectKnowledge, godObjectKnowledge]
            )
        }
    }

    @Test("invalid and exceeded prompt limits are rejected")
    func enforcesPromptLimits() throws {
        expectError(.invalidLimits) {
            _ = try IssueCategorizationPromptBuilder(
                limits: IssueCategorizationPromptLimits(
                    maximumPromptUTF8Bytes: 0
                )
            ).build(
                candidates: [try staticCandidate()],
                ruleKnowledge: [godObjectKnowledge]
            )
        }

        do {
            _ = try IssueCategorizationPromptBuilder(
                limits: IssueCategorizationPromptLimits(
                    maximumPromptUTF8Bytes: 100
                )
            ).build(
                candidates: [try staticCandidate()],
                ruleKnowledge: [godObjectKnowledge]
            )
            Issue.record("Expected an oversized prompt error.")
        } catch let error as IssueCategorizationPromptBuildingError {
            guard case let .promptTooLarge(actual, maximum) = error else {
                Issue.record("Unexpected prompt error: \(error)")
                return
            }
            #expect(actual > maximum)
            #expect(maximum == 100)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func staticCandidate() throws -> FindingCandidate {
        try FindingCandidate(
            candidateID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            ruleID: "ARCAN-GOD-001",
            title: "God Object candidate",
            explanation: "The type owns unrelated responsibilities.",
            filePath: "Sources/Checkout.swift",
            range: SourceRange(
                startLine: 10,
                startColumn: 1,
                endLine: 90,
                endColumn: 2
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [.metric(MetricEvidence(
                metricName: "methodCount",
                observedValue: 42,
                thresholdValue: 30
            ))],
            sourceIdentifiers: ["god-object"]
        )
    }

    private func llmCandidate() throws -> FindingCandidate {
        try FindingCandidate(
            candidateID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            ruleID: "ARCAN-GOD-001",
            title: "Mixed responsibilities",
            explanation: "The coordinator mixes orchestration and persistence.",
            filePath: "Sources/Checkout.swift",
            range: SourceRange(
                startLine: 44,
                startColumn: 5,
                endLine: 44,
                endColumn: 27
            ),
            proposedSeverity: .warning,
            proposedCategory: .antiPattern,
            evidence: [.sourceCode(SourceCodeEvidence(
                description: "The coordinator performs persistence directly.",
                range: SourceRange(
                    startLine: 44,
                    startColumn: 5,
                    endLine: 44,
                    endColumn: 27
                ),
                excerpt: "repository.save(order)"
            ))],
            sourceIdentifiers: [
                "llm-code-analysis",
                "ollama:qwen2.5-coder:7b"
            ]
        )
    }

    private var godObjectKnowledge: RuleKnowledge {
        RuleKnowledge(
            ruleID: "ARCAN-GOD-001",
            title: "God Object",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern,
            defaultSeverity: .warning,
            definition: "A type owns multiple unrelated responsibilities.",
            evidenceCriteria: ["Multiple responsibility signals are present."],
            classificationGuidance: ["Do not rely on size alone."],
            severityGuidance: ["Escalate when responsibilities are strongly coupled."],
            refactoringGuardrails: ["Preserve behavior."]
        )
    }

    private var styleKnowledge: RuleKnowledge {
        RuleKnowledge(
            ruleID: "ARCAN-STYLE-001",
            title: "Style",
            group: .style,
            category: .style,
            defaultSeverity: .info,
            definition: "A style rule is violated.",
            evidenceCriteria: ["A configured analyzer reports a violation."],
            classificationGuidance: ["Use the configured convention."],
            severityGuidance: ["Prefer informational severity."],
            refactoringGuardrails: []
        )
    }

    private func expectError(
        _ expected: IssueCategorizationPromptBuildingError,
        operation: () throws -> Void
    ) {
        do {
            try operation()
            Issue.record("Expected prompt construction to fail with \(expected).")
        } catch let error as IssueCategorizationPromptBuildingError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
