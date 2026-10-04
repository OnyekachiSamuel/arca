import ArcaDomain

struct CodeAnalysisSourceInputRenderer: Sendable {
    func render(
        context: SourceFileAnalysisContext,
        sourceLines: [String]
    ) -> String {
        var sections = [
            """
            FILE_PATH
            \(context.filePath)
            """,
            """
            LINE_COUNT
            \(context.lineCount)
            """,
        ]

        if let changeSection = renderChanges(context.change) {
            sections.append(changeSection)
        }

        let numberedSource = sourceLines.enumerated().map { index, line in
            "\(index + 1) | \(line)"
        }.joined(separator: "\n")
        sections.append(
            """
            SOURCE_CODE
            \(numberedSource)
            """
        )
        return sections.joined(separator: "\n\n")
    }

    private func renderChanges(
        _ change: SourceFileChangeContext?
    ) -> String? {
        guard let change else { return nil }

        var ranges: [String] = []
        if !change.addedLineRanges.isEmpty {
            ranges.append(
                "Added: \(render(change.addedLineRanges))"
            )
        }
        if !change.modifiedLineRanges.isEmpty {
            ranges.append(
                "Modified: \(render(change.modifiedLineRanges))"
            )
        }
        if !change.deletedLineRanges.isEmpty {
            let deleted = change.deletedLineRanges.map {
                render(start: $0.originalStartLine, end: $0.originalEndLine)
            }.joined(separator: ", ")
            ranges.append("Deleted from previous version: \(deleted)")
        }
        guard !ranges.isEmpty else { return nil }

        return """
        CHANGED_LINE_RANGES
        \(ranges.joined(separator: "\n"))
        """
    }

    private func render(_ ranges: [ChangedLineRange]) -> String {
        ranges.map { render(start: $0.startLine, end: $0.endLine) }
            .joined(separator: ", ")
    }

    private func render(start: Int, end: Int) -> String {
        start == end ? String(start) : "\(start)-\(end)"
    }
}
