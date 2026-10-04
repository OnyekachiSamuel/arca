import ArcaDomain
import ArcaKnowledge
import ArcaLLM
import Testing

@Suite("Separate code-analysis prompt builders")
struct CodeAnalysisPromptBuilderTests {
  @Test("baseline and guided prompts disable Qwen thinking")
  func appendsNoThinkControl() throws {
    let baselinePrompt = try BaselineCodeAnalysisPromptBuilder().build(
      context: validContext
    )
    let guidedPrompt = try GuidedCodeAnalysisPromptBuilder().build(
      context: validContext,
      rules: [godObjectKnowledge]
    )

    #expect(baselinePrompt.hasSuffix("/no_think"))
    #expect(guidedPrompt.hasSuffix("/no_think"))
  }

  @Test("baseline prompt requests broad detection without task or rule knowledge")
  func buildsBaselinePromptWithoutKnowledge() throws {
    let prompt = try BaselineCodeAnalysisPromptBuilder().build(
      context: validContext
    )

    #expect(prompt.contains("code smells and anti-patterns"))
    #expect(!prompt.contains("ARCA-GOD-001"))
    #expect(!prompt.contains("God Object"))
    #expect(!prompt.contains("selected analysis task"))
    #expect(!prompt.contains(#""ruleID""#))
    #expect(prompt.contains(#""title""#))
    #expect(!prompt.contains(#""severity""#))
    #expect(!prompt.contains(#""filePath""#))
    #expect(!prompt.contains(#""excerpt""#))
    #expect(!prompt.contains(#""additionalProperties""#))
    #expect(!prompt.contains(godObjectKnowledge.problemContext))
    #expect(!prompt.contains(godObjectKnowledge.expectedBehavior))
    #expect(!prompt.contains(godObjectKnowledge.violationCriteria))
    #expect(!prompt.contains("multiple unrelated responsibilities"))
    #expect(!prompt.contains(#""rules""#))
    #expect(prompt.contains("Return at most five distinct findings"))
    #expect(prompt.contains("1 | struct Example {}"))
    #expect(!prompt.contains(#""lineNumber""#))
    #expect(!prompt.contains(#""text""#))
  }

  @Test("guided prompt includes the selected rule knowledge")
  func buildsGuidedPromptWithKnowledge() throws {
    let prompt = try GuidedCodeAnalysisPromptBuilder().build(
      context: validContext,
      rules: [godObjectKnowledge]
    )

    #expect(prompt.contains(godObjectKnowledge.problemContext))
    #expect(prompt.contains(#""rules""#))
    #expect(prompt.contains(godObjectKnowledge.expectedBehavior))
    #expect(prompt.contains(godObjectKnowledge.violationCriteria))
  }

  @Test("guided prompt omits rules that do not apply to the source")
  func requiresRuleApplicabilityBeforeViolationDetection() throws {
    let prompt = try GuidedCodeAnalysisPromptBuilder().build(
      context: validContext,
      rules: [godObjectKnowledge]
    )

    #expect(prompt.contains("RULE APPLICABILITY"))
    #expect(
      prompt.contains(
        "Evaluate each supplied rule independently"
      )
    )
    #expect(
      prompt.contains(
        "First determine whether the rule applies to the provided source code"
      )
    )
    #expect(
      prompt.contains(
        "Report a finding only when the rule's violation criteria is met"
      )
    )
    #expect(
      prompt.contains(
        "If a rule does not apply or there is insufficient evidence, do not report it"
      )
    )
    #expect(
      prompt.contains(
        #"Return {"findings":[]} when evidence is insufficient"#
      )
    )
  }

  @Test("guided prompt preserves the rule definition and Markdown knowledge")
  func preservesStructuredRuleAndMarkdownKnowledge() throws {
    let markdown = """
      # Unsafe storage

      ## Detection guidance

      Confirm that sensitive data is persisted.

      ```swift
      UserDefaults.standard.set(token, forKey: "token")
      ```
      """
    let rule = RuleKnowledge(
      ruleID: "ARCA-OWASP-MASWE-0001",
      reviewType: .security,
      category: "data-storage",
      title: "Sensitive data stored without protection",
      problemContext: "Sensitive information can be exposed.",
      expectedBehavior: "Use storage appropriate to the data.",
      violationCriteria: "Sensitive data is stored without protection.",
      knowledgeFile: "references/ARCA-OWASP-MASWE-0001.md",
      supportingKnowledge: markdown
    )

    let prompt = try GuidedCodeAnalysisPromptBuilder().build(
      context: validContext,
      rules: [rule]
    )

    #expect(prompt.contains("ARCA-OWASP-MASWE-0001"))
    #expect(!prompt.contains("Review type: security"))
    #expect(!prompt.contains("Category: data-storage"))
    #expect(prompt.contains(rule.problemContext))
    #expect(prompt.contains(rule.expectedBehavior))
    #expect(prompt.contains(rule.violationCriteria))
    #expect(prompt.contains(markdown))
  }

  @Test("guided prompt does not include framework deprecation versions")
  func omitsDeprecationVersion() throws {
    let rule = RuleKnowledge(
      ruleID: "ARCA-TCA-DEPRECATED-001",
      reviewType: .tca,
      category: "framework-usage",
      title: "Legacy reducer API usage",
      problemContext: "A legacy TCA reducer API is used.",
      expectedBehavior: "Use the current reducer composition API.",
      violationCriteria: "Legacy reducer syntax is visible.",
      knowledgeFile: "references/ARCA-TCA-DEPRECATED-001.md",
      supportingKnowledge: "# Legacy reducer API",
      deprecatedFromVersion: "1.25.0"
    )

    let prompt = try GuidedCodeAnalysisPromptBuilder().build(
      context: validContext,
      rules: [rule]
    )

    #expect(!prompt.contains("Deprecated from TCA version"))
    #expect(!prompt.contains("1.25.0"))
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

    #expect(prompt.contains("Sources/Checkout.swift"))
    #expect(!prompt.contains(#""previousFilePath""#))
    #expect(prompt.contains("Hello 👋"))
    #expect(prompt.contains("1 | import Foundation"))
    #expect(prompt.contains("2 |"))
    #expect(prompt.contains("4 |     let greeting = \"Hello 👋\""))
    #expect(!prompt.contains(#""lineNumber""#))
    #expect(!prompt.contains(#""text""#))
    #expect(prompt.contains("Added: 4"))
    #expect(prompt.contains("Modified: 5"))
    #expect(prompt.contains("Deleted from previous version: 7-8"))
    #expect(prompt.contains("ARCA-GOD-001"))
    #expect(prompt.contains("ARCA-LONG-METHOD-001"))
    #expect(prompt.contains(godObjectKnowledge.problemContext))
    #expect(
      prompt.contains(
        godObjectKnowledge.violationCriteria
      )
    )
    #expect(
      prompt.contains(
        godObjectKnowledge.expectedBehavior
      )
    )
    #expect(prompt.contains(#""findings""#))
    #expect(prompt.contains(#""ruleID""#))
    #expect(!prompt.contains(#""filePath""#))
    #expect(prompt.contains(#""evidence""#))
    #expect(!prompt.contains("Repeat the supplied file path exactly"))
    #expect(prompt.contains("Return only JSON in exactly this shape"))
    #expect(prompt.contains("violation criteria is met"))
    #expect(prompt.contains("one-based, inclusive line numbers"))
    #expect(prompt.contains("Do not invent numeric thresholds"))
    #expect(prompt.contains("multiple unrelated responsibilities"))
    #expect(!prompt.contains(#""excerpt""#))
    #expect(!prompt.contains(#""severity""#))
    #expect(!prompt.contains(#""additionalProperties""#))
    #expect(prompt.contains("Do not provide refactoring"))
    #expect(prompt.contains("Return at most five distinct findings"))
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
      first.range(of: "ARCA-GOD-001")
    )
    let longMethodPosition = try #require(
      first.range(of: "ARCA-LONG-METHOD-001")
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

    #expect(!prompt.contains("CHANGED_LINE_RANGES"))
    #expect(!prompt.contains(#""previousFilePath""#))
  }

  @Test("baseline and guided prompts preserve the complete source text")
  func preservesCompleteSourceText() throws {
    let source = #"let apiToken = "sk-live-super-secret-value""#
    let context = SourceFileAnalysisContext(
      filePath: "Secrets.swift",
      sourceContent: source,
      lineCount: 1
    )
    let baselinePrompt = try BaselineCodeAnalysisPromptBuilder().build(
      context: context
    )
    let guidedPrompt = try GuidedCodeAnalysisPromptBuilder().build(
      context: context,
      rules: [godObjectKnowledge]
    )

    #expect(baselinePrompt.contains("sk-live-super-secret-value"))
    #expect(guidedPrompt.contains("sk-live-super-secret-value"))
    #expect(!baselinePrompt.contains("[REDACTED]"))
    #expect(!guidedPrompt.contains("[REDACTED]"))
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
      guard case .promptTooLarge(let actualBytes, let maximumBytes) = error
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
      reviewType: .godObject,
      category: "architecture",
      title: "God Object candidate",
      problemContext: "A type owns multiple unrelated responsibilities.",
      expectedBehavior: "Do not classify a type using line count alone.",
      violationCriteria: "Several unrelated responsibilities are visible.",
      knowledgeFile: "references/ARCA-GOD-001.md",
      supportingKnowledge: "# God Object"
    )
  }

  private var longMethodKnowledge: RuleKnowledge {
    RuleKnowledge(
      ruleID: "ARCA-LONG-METHOD-001",
      reviewType: .swift,
      category: "complexity",
      title: "Long Method candidate",
      problemContext: "A method is difficult to understand or change safely.",
      expectedBehavior: "Do not classify a method using line count alone.",
      violationCriteria: "Several distinct phases are visible in one method.",
      knowledgeFile: "references/ARCA-LONG-METHOD-001.md",
      supportingKnowledge: "# Long Method"
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
