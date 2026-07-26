enum SourceTextLineExtractor {
    static func lines(in source: String) -> [String] {
        guard !source.isEmpty else { return [] }

        var lines: [String] = []
        var currentLine = ""

        for character in source {
            if character.isNewline {
                lines.append(currentLine)
                currentLine = ""
            } else {
                currentLine.append(character)
            }
        }

        if source.last?.isNewline != true {
            lines.append(currentLine)
        }

        return lines
    }
}
