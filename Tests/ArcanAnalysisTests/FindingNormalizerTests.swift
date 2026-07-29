import ArcanDomain
import Foundation
import Testing
@testable import ArcanAnalysis

@Suite("Finding normalizer")
struct FindingNormalizerTests {
    @Test("uses a repository-relative path for a file inside the repository")
    func makesRepositoryPathRelative() throws {
        let finding = makeFinding(
            path: "/project/Sources/Feature/../App.swift"
        )

        let normalized = try FindingNormalizer().normalize(
            finding,
            repositoryRoot: "/project"
        )

        #expect(normalized.filePath == "Sources/App.swift")
        #expect(normalized.id == finding.id)
        #expect(normalized.category == .style)
        #expect(normalized.sources == ["llm.general"])
        #expect(normalized.metadata == finding.metadata)
    }

    @Test("adds the analyzer source once while preserving stable order")
    func addsAndDeduplicatesSource() throws {
        let finding = makeFinding(
            path: "/project/Sources/App.swift",
            sources: ["llm.general", "god-object"]
        )

        let normalized = try FindingNormalizer().normalize(
            finding,
            repositoryRoot: "/project",
            sourceIdentifier: "god-object"
        )

        #expect(normalized.sources == ["llm.general", "god-object"])
    }

    @Test("resolves an analyzer-relative path from the repository root")
    func resolvesRelativePath() throws {
        let normalized = try FindingNormalizer().normalize(
            makeFinding(path: "Sources/App.swift"),
            repositoryRoot: "/project"
        )

        #expect(normalized.filePath == "Sources/App.swift")
    }

    @Test("does not treat a similar path prefix as repository containment")
    func preservesPathOutsideRepository() throws {
        let normalized = try FindingNormalizer().normalize(
            makeFinding(path: "/project-copy/Sources/App.swift"),
            repositoryRoot: "/project"
        )

        #expect(normalized.filePath == "/project-copy/Sources/App.swift")
    }

    @Test("preserves a canonical absolute path when no repository is known")
    func preservesAbsolutePathWithoutRepository() throws {
        let normalized = try FindingNormalizer().normalize(
            makeFinding(path: "/tmp/Feature/../App.swift"),
            repositoryRoot: nil
        )

        #expect(normalized.filePath == "/tmp/App.swift")
    }

    @Test("rejects a range that is not one-based")
    func rejectsZeroBasedRange() {
        let finding = makeFinding(
            path: "/project/App.swift",
            range: SourceRange(
                startLine: 0,
                startColumn: 1,
                endLine: 1,
                endColumn: 1
            )
        )

        #expect(throws: FindingNormalizationError.self) {
            try FindingNormalizer().normalize(
                finding,
                repositoryRoot: "/project"
            )
        }
    }

    @Test("rejects a range whose end precedes its start")
    func rejectsReversedRange() {
        let finding = makeFinding(
            path: "/project/App.swift",
            range: SourceRange(
                startLine: 4,
                startColumn: 8,
                endLine: 4,
                endColumn: 3
            )
        )

        #expect(throws: FindingNormalizationError.self) {
            try FindingNormalizer().normalize(
                finding,
                repositoryRoot: "/project"
            )
        }
    }

    private func makeFinding(
        path: String,
        range: SourceRange? = SourceRange(
            startLine: 2,
            startColumn: 3,
            endLine: 2,
            endColumn: 8
        ),
        sources: [String] = ["llm.general"]
    ) -> SuggestionFinding {
        SuggestionFinding(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            ruleID: "swiftlint.example",
            externalRuleID: "example",
            title: "Example",
            category: .style,
            severity: .warning,
            filePath: path,
            range: range,
            explanation: "Example finding.",
            sources: sources,
            metadata: ["file": .string(path)]
        )
    }
}
