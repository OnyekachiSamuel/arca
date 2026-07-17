import ArcanAnalysis
import ArcanDomain
import ArcanSource
import ArcanSwiftSyntax
import Foundation
import Testing

@Suite("SwiftSyntax source context provider")
struct SwiftSyntaxSourceContextProviderTests {
    @Test("returns the containing class and nearby lines for a method change")
    func returnsContextForMethodChange() throws {
        let source = try loadFixture()
        let change = CodeChange(
            filePath: source.path,
            modifiedLineRanges: [
                ChangedLineRange(startLine: 5, endLine: 5)
            ]
        )

        let contexts = try sourceContextProvider().contexts(
            for: change,
            in: source,
            surroundingLineCount: 1
        )
        let context = try #require(contexts.first)

        #expect(contexts.count == 1)
        #expect(context.changedLineRange == ChangedLineRange(
            startLine: 5,
            endLine: 5
        ))
        #expect(context.includedLineRange == SourceLineRange(
            startLine: 4,
            endLine: 6
        ))
        #expect(context.containingType?.name == "Service")
        #expect(context.containingType?.kind == .class)
        #expect(
            context.sourceText
                == [
                    "",
                    "    func fetch() {}",
                    "    static func reset() {}"
                ].joined(separator: "\n")
        )
    }

    @Test("returns the containing struct for a property change")
    func returnsContextForPropertyChange() throws {
        let source = try loadFixture()
        let change = CodeChange(
            filePath: source.path,
            modifiedLineRanges: [
                ChangedLineRange(startLine: 16, endLine: 16)
            ]
        )

        let contexts = try sourceContextProvider().contexts(
            for: change,
            in: source,
            surroundingLineCount: 1
        )
        let context = try #require(contexts.first)

        #expect(context.containingType?.name == "Feature")
        #expect(context.containingType?.kind == .struct)
        #expect(context.includedLineRange == SourceLineRange(
            startLine: 15,
            endLine: 17
        ))
        #expect(
            context.sourceText
                == [
                    "struct Feature {",
                    "    var count = 0",
                    "    var doubled: Int { count * 2 }"
                ].joined(separator: "\n")
        )
    }

    @Test("returns the extension rather than the original type")
    func returnsContextForExtensionChange() throws {
        let source = try loadFixture()
        let change = CodeChange(
            filePath: source.path,
            modifiedLineRanges: [
                ChangedLineRange(startLine: 32, endLine: 32)
            ]
        )

        let contexts = try sourceContextProvider().contexts(
            for: change,
            in: source,
            surroundingLineCount: 1
        )
        let context = try #require(contexts.first)

        #expect(context.containingType?.name == "Feature")
        #expect(context.containingType?.kind == .extension)
        #expect(context.includedLineRange == SourceLineRange(
            startLine: 31,
            endLine: 33
        ))
    }

    @Test("selects the innermost type for a nested method change")
    func returnsInnermostContainingType() throws {
        let source = try loadFixture()
        let change = CodeChange(
            filePath: source.path,
            modifiedLineRanges: [
                ChangedLineRange(startLine: 11, endLine: 11)
            ]
        )

        let contexts = try sourceContextProvider().contexts(
            for: change,
            in: source,
            surroundingLineCount: 0
        )
        let context = try #require(contexts.first)

        #expect(context.containingType?.name == "State")
        #expect(context.containingType?.kind == .struct)
        #expect(context.includedLineRange == SourceLineRange(
            startLine: 11,
            endLine: 11
        ))
        #expect(context.sourceText == "        func reduce() {}")
    }

    @Test("clamps surrounding lines to the source file boundaries")
    func clampsContextToFileBoundaries() throws {
        let source = try loadFixture()
        let change = CodeChange(
            filePath: source.path,
            addedLineRanges: [
                ChangedLineRange(startLine: 1, endLine: 1)
            ]
        )

        let contexts = try sourceContextProvider().contexts(
            for: change,
            in: source,
            surroundingLineCount: 5
        )
        let context = try #require(contexts.first)

        #expect(context.includedLineRange == SourceLineRange(
            startLine: 1,
            endLine: 6
        ))
    }

    @Test("does not interpret deleted ranges against current source")
    func ignoresDeletedRanges() throws {
        let source = try loadFixture()
        let change = CodeChange(
            filePath: source.path,
            deletedLineRanges: [
                DeletedLineRange(
                    originalStartLine: 5,
                    originalEndLine: 6
                )
            ]
        )

        let contexts = try sourceContextProvider().contexts(
            for: change,
            in: source,
            surroundingLineCount: 2
        )

        #expect(contexts.isEmpty)
    }

    @Test("rejects a changed range outside the current source")
    func rejectsInvalidChangedRange() throws {
        let source = try loadFixture()
        let invalidRange = ChangedLineRange(startLine: 0, endLine: 2)
        let change = CodeChange(
            filePath: source.path,
            modifiedLineRanges: [invalidRange]
        )

        expectError(.invalidChangedLineRange(
            filePath: source.path,
            startLine: 0,
            endLine: 2,
            fileLineCount: source.lineCount
        )) {
            _ = try sourceContextProvider().contexts(
                for: change,
                in: source,
                surroundingLineCount: 2
            )
        }
    }

    private func sourceContextProvider() -> any SourceContextProvider {
        SwiftSyntaxSourceContextProvider()
    }

    private func loadFixture() throws -> SourceFile {
        let fixtureURL = try #require(
            Bundle.module.url(
                forResource: "StructuralTypes",
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )
        return try SourceFileLoader().load(path: fixtureURL.path)
    }

    private func expectError(
        _ expected: SourceContextProviderError,
        performing operation: () throws -> Void
    ) {
        do {
            try operation()
            Issue.record("Expected source context creation to fail")
        } catch let error as SourceContextProviderError {
            #expect(error == expected)
            #expect(error.errorDescription?.isEmpty == false)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
