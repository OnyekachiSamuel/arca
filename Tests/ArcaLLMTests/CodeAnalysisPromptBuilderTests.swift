import ArcaDomain
import ArcaKnowledge
import ArcaLLM
import Testing

@Suite("Separate code-analysis prompt builders")
struct CodeAnalysisPromptBuilderTests {
    @Test("baseline prompt requests broad detection without task or rule knowledge")
    func buildsBaselinePromptWithoutKnowledge() throws {
        let prompt = try BaselineCodeAnalysisPromptBuilder().build(
            context: validContext
        )

        #expect(prompt.templateID == "arca.code-analysis.baseline")
        #expect(prompt.text.contains("code smells and anti-patterns"))
        #expect(!prompt.text.contains("ARCA-GOD-001"))
        #expect(!prompt.text.contains("God Object"))
        #expect(!prompt.text.contains("selected analysis task"))
        #expect(!prompt.text.contains(#""ruleID""#))
        #expect(prompt.text.contains(#""title""#))
        #expect(prompt.text.contains(#""issueType""#))
        #expect(!prompt.text.contains(godObjectKnowledge.definition))
        for value in godObjectKnowledge.evidenceCriteria
            + godObjectKnowledge.classificationGuidance
            + godObjectKnowledge.severityGuidance {
            #expect(!prompt.text.contains(value))
        }
        #expect(!prompt.text.contains("multiple unrelated responsibilities"))
        #expect(!prompt.text.contains(#""rules""#))
    }

    @Test("guided prompt includes the selected rule knowledge")
    func buildsGuidedPromptWithKnowledge() throws {
        let prompt = try GuidedCodeAnalysisPromptBuilder().build(
            context: validContext,
            rules: [godObjectKnowledge]
        )

        #expect(prompt.templateID == "arca.code-analysis.guided")
        #expect(prompt.text.contains(godObjectKnowledge.definition))
        #expect(prompt.text.contains(#""rules""#))
        for value in godObjectKnowledge.evidenceCriteria
            + godObjectKnowledge.classificationGuidance
            + godObjectKnowledge.severityGuidance {
            #expect(prompt.text.contains(value))
        }
    }

    @Test("prompt contains the complete file, changes, every rule, and response contract")
    func buildsGroundedMultiRulePrompt() throws {
        let context = SourceFileAnalysisContext(
            filePath: "Sources/Checkout.swift",
            sourceContent: """
            import Foundation

            final class Checkout {
                let greeting = "Hello 👋"
                func submit() {}
            }
            """,
            lineCount: 6,
            change: SourceFileChangeContext(
                previousFilePath: "Sources/OldCheckout.swift",
                addedLineRanges: [
                    ChangedLineRange(startLine: 4, endLine: 4)
                ],
                modifiedLineRanges: [
                    ChangedLineRange(startLine: 5, endLine: 5)
                ],
                deletedLineRanges: [
                    DeletedLineRange(
                        originalStartLine: 7,
                        originalEndLine: 8
                    )
                ]
            )
        )

        let prompt = try GuidedCodeAnalysisPromptBuilder().build(
            context: context,
            rules: [longMethodKnowledge, godObjectKnowledge]
        )

        #expect(prompt.templateID == "arca.code-analysis.guided")
        #expect(prompt.templateVersion == 1)
        #expect(prompt.text.contains("Sources/Checkout.swift"))
        #expect(prompt.text.contains("Sources/OldCheckout.swift"))
        #expect(prompt.text.contains("Hello 👋"))
        #expect(prompt.text.contains(#""lineNumber" : 2"#))
        #expect(prompt.text.contains(#""text" : ""#))
        #expect(prompt.text.contains(#""startLine" : 4"#))
        #expect(prompt.text.contains(#""originalStartLine" : 7"#))
        #expect(prompt.text.contains("ARCA-GOD-001"))
        #expect(prompt.text.contains("ARCA-LONG-METHOD-001"))
        #expect(prompt.text.contains(godObjectKnowledge.definition))
        #expect(
            prompt.text.contains(
                godObjectKnowledge.evidenceCriteria[0]
            )
        )
        #expect(
            prompt.text.contains(
                godObjectKnowledge.classificationGuidance[0]
            )
        )
        #expect(
            prompt.text.contains(
                godObjectKnowledge.severityGuidance[0]
            )
        )
        #expect(
            !prompt.text.contains(
                godObjectKnowledge.refactoringGuardrails[0]
            )
        )
        #expect(prompt.text.contains(#""findings""#))
        #expect(prompt.text.contains(#""ruleID""#))
        #expect(prompt.text.contains(#""filePath""#))
        #expect(prompt.text.contains(#""evidence""#))
        #expect(prompt.text.contains("Repeat the supplied file path exactly"))
        #expect(prompt.text.contains("Return only one JSON object"))
        #expect(prompt.text.contains("only evidence visible"))
        #expect(prompt.text.contains("one-based, inclusive line ranges"))
        #expect(prompt.text.contains("Do not invent numeric thresholds"))
        #expect(prompt.text.contains("multiple unrelated responsibilities"))
        #expect(
            prompt.text.contains(
                "size, method count, or property count alone is insufficient"
            )
        )
        #expect(prompt.text.contains("short, exact, contiguous copy"))
        #expect(prompt.text.contains("Do not provide refactoring"))
    }

    @Test("the same rule set produces stable output regardless of input order")
    func canonicalizesRuleOrder() throws {
        let builder = GuidedCodeAnalysisPromptBuilder()
        let context = SourceFileAnalysisContext(
            filePath: "Example.swift",
            sourceContent: "struct Example {}",
            lineCount: 1
        )

        let first = try builder.build(
            context: context,
            rules: [longMethodKnowledge, godObjectKnowledge]
        )
        let second = try builder.build(
            context: context,
            rules: [godObjectKnowledge, longMethodKnowledge]
        )

        #expect(first == second)
        let godObjectPosition = try #require(
            first.text.range(of: "ARCA-GOD-001")
        )
        let longMethodPosition = try #require(
            first.text.range(of: "ARCA-LONG-METHOD-001")
        )
        #expect(godObjectPosition.lowerBound < longMethodPosition.lowerBound)
    }

    @Test("an explicit-file prompt does not invent Git change data")
    func omitsUnavailableChangeData() throws {
        let prompt = try GuidedCodeAnalysisPromptBuilder().build(
            context: SourceFileAnalysisContext(
                filePath: "Example.swift",
                sourceContent: "let value = 1",
                lineCount: 1
            ),
            rules: [godObjectKnowledge]
        )

        #expect(!prompt.text.contains(#""change" :"#))
        #expect(!prompt.text.contains(#""previousFilePath""#))
    }

    @Test("common credential values are not included in the prompt")
    func redactsCommonCredentials() throws {
        let prompt = try GuidedCodeAnalysisPromptBuilder().build(
            context: SourceFileAnalysisContext(
                filePath: "Secrets.swift",
                sourceContent: #"let apiToken = "sk-live-super-secret-value""#,
                lineCount: 1
            ),
            rules: [godObjectKnowledge]
        )

        #expect(!prompt.text.contains("sk-live-super-secret-value"))
        #expect(prompt.text.contains("[REDACTED]"))
    }

    @Test("at least one applicable rule is required")
    func rejectsEmptyRuleSelection() {
        expectBuildingError(.noApplicableRules) {
            _ = try GuidedCodeAnalysisPromptBuilder().build(
                context: validContext,
                rules: []
            )
        }
    }

    @Test("duplicate rule IDs are rejected")
    func rejectsDuplicateRuleIDs() {
        expectBuildingError(.duplicateRuleID("ARCA-GOD-001")) {
            _ = try GuidedCodeAnalysisPromptBuilder().build(
                context: validContext,
                rules: [godObjectKnowledge, godObjectKnowledge]
            )
        }
    }

    @Test("source line metadata must agree with the complete source")
    func rejectsMismatchedLineCount() {
        expectBuildingError(
            .sourceLineCountMismatch(expected: 2, actual: 1)
        ) {
            _ = try GuidedCodeAnalysisPromptBuilder().build(
                context: SourceFileAnalysisContext(
                    filePath: "Example.swift",
                    sourceContent: "struct Example {}",
                    lineCount: 2
                ),
                rules: [godObjectKnowledge]
            )
        }
    }

    @Test("complete prompts exceeding their byte limit are rejected")
    func rejectsOversizedPrompt() {
        let builder = GuidedCodeAnalysisPromptBuilder(
            limits: CodeAnalysisPromptLimits(
                maximumPromptUTF8Bytes: 100
            )
        )

        do {
            _ = try builder.build(
                context: validContext,
                rules: [godObjectKnowledge]
            )
            Issue.record("Expected prompt construction to fail.")
        } catch let error as CodeAnalysisPromptBuildingError {
            guard case let .promptTooLarge(actualBytes, maximumBytes) = error
            else {
                Issue.record("Unexpected prompt error: \(error)")
                return
            }

            #expect(actualBytes > maximumBytes)
            #expect(maximumBytes == 100)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private var validContext: SourceFileAnalysisContext {
        SourceFileAnalysisContext(
            filePath: "Example.swift",
            sourceContent: "struct Example {}",
            lineCount: 1
        )
    }

    private var godObjectKnowledge: RuleKnowledge {
        RuleKnowledge(
            ruleID: "ARCA-GOD-001",
            title: "God Object candidate",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern,
            defaultSeverity: .warning,
            definition: "A type owns multiple unrelated responsibilities.",
            evidenceCriteria: [
                "Several unrelated responsibilities are visible."
            ],
            classificationGuidance: [
                "Do not classify a type using line count alone."
            ],
            severityGuidance: [
                "Use warning when multiple structural signals are visible."
            ],
            refactoringGuardrails: [
                "Extract unrelated responsibilities."
            ]
        )
    }

    private var longMethodKnowledge: RuleKnowledge {
        RuleKnowledge(
            ruleID: "ARCA-LONG-METHOD-001",
            title: "Long Method candidate",
            group: .codeSmellsAndAntiPatterns,
            category: .antiPattern,
            defaultSeverity: .warning,
            definition: "A method is difficult to understand or change safely.",
            evidenceCriteria: [
                "Several distinct phases are visible in one method."
            ],
            classificationGuidance: [
                "Do not classify a method using line count alone."
            ],
            severityGuidance: [
                "Use warning when size and multiple responsibilities occur together."
            ],
            refactoringGuardrails: [
                "Preserve execution order."
            ]
        )
    }

    private func expectBuildingError(
        _ expectedError: CodeAnalysisPromptBuildingError,
        operation: () throws -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        do {
            try operation()
            Issue.record(
                "Expected prompt construction to fail with \(expectedError).",
                sourceLocation: sourceLocation
            )
        } catch let error as CodeAnalysisPromptBuildingError {
            #expect(error == expectedError, sourceLocation: sourceLocation)
        } catch {
            Issue.record(
                "Unexpected error: \(error)",
                sourceLocation: sourceLocation
            )
        }
    }
}
