import ArcanAnalysis
import ArcanDomain
import Foundation

public struct SwiftSyntaxSourceContextProvider: SourceContextProvider {
    private let structureProvider: any SwiftStructureProvider

    public init(
        structureProvider: any SwiftStructureProvider = SwiftSyntaxStructureProvider()
    ) {
        self.structureProvider = structureProvider
    }

    public func contexts(
        for change: CodeChange,
        in sourceFile: SourceFile,
        surroundingLineCount: Int
    ) throws -> [SourceContextWindow] {
        guard surroundingLineCount >= 0 else {
            throw SourceContextProviderError.invalidSurroundingLineCount(
                surroundingLineCount
            )
        }
        guard change.filePath == sourceFile.path else {
            throw SourceContextProviderError.sourcePathMismatch(
                changePath: change.filePath,
                sourcePath: sourceFile.path
            )
        }

        let changedRanges = uniqueCurrentRanges(in: change)
        guard !changedRanges.isEmpty else { return [] }

        let sourceLines = lines(in: sourceFile.content)
        let metrics = try structureProvider.extractMetrics(from: sourceFile)

        return try changedRanges.map { changedRange in
            try makeContext(
                for: changedRange,
                in: sourceFile,
                sourceLines: sourceLines,
                metrics: metrics,
                surroundingLineCount: surroundingLineCount
            )
        }
    }

    private func uniqueCurrentRanges(
        in change: CodeChange
    ) -> [ChangedLineRange] {
        let sortedRanges = (
            change.addedLineRanges + change.modifiedLineRanges
        ).sorted { left, right in
            if left.startLine == right.startLine {
                return left.endLine < right.endLine
            }
            return left.startLine < right.startLine
        }

        return sortedRanges.reduce(into: []) { ranges, range in
            if ranges.last != range {
                ranges.append(range)
            }
        }
    }

    private func makeContext(
        for changedRange: ChangedLineRange,
        in sourceFile: SourceFile,
        sourceLines: [String],
        metrics: [TypeStructuralMetrics],
        surroundingLineCount: Int
    ) throws -> SourceContextWindow {
        let fileLineCount = sourceLines.count
        guard changedRange.startLine >= 1,
              changedRange.endLine >= changedRange.startLine,
              changedRange.endLine <= fileLineCount else {
            throw SourceContextProviderError.invalidChangedLineRange(
                filePath: sourceFile.path,
                startLine: changedRange.startLine,
                endLine: changedRange.endLine,
                fileLineCount: fileLineCount
            )
        }

        let linesBefore = min(
            surroundingLineCount,
            changedRange.startLine - 1
        )
        let linesAfter = min(
            surroundingLineCount,
            fileLineCount - changedRange.endLine
        )
        let includedLineRange = SourceLineRange(
            startLine: changedRange.startLine - linesBefore,
            endLine: changedRange.endLine + linesAfter
        )
        let sourceText = sourceLines[
            (includedLineRange.startLine - 1)..<includedLineRange.endLine
        ].joined(separator: "\n")

        return SourceContextWindow(
            filePath: sourceFile.path,
            changedLineRange: changedRange,
            includedLineRange: includedLineRange,
            sourceText: sourceText,
            containingType: innermostContainingType(
                for: changedRange,
                in: metrics
            )
        )
    }

    private func innermostContainingType(
        for changedRange: ChangedLineRange,
        in metrics: [TypeStructuralMetrics]
    ) -> TypeStructuralMetrics? {
        metrics
            .filter { metric in
                metric.range.startLine <= changedRange.startLine
                    && metric.range.endLine >= changedRange.endLine
            }
            .min { left, right in
                if left.lineCount == right.lineCount {
                    return left.range.startLine > right.range.startLine
                }
                return left.lineCount < right.lineCount
            }
    }

    private func lines(in content: String) -> [String] {
        guard !content.isEmpty else { return [] }

        var lines = content.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).map(String.init)

        if content.last?.isNewline == true, lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return lines
    }
}
