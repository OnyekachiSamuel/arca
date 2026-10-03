import ArcaDomain
import Foundation

public struct BaselineCodeAnalysisPromptBuilder: Sendable {
    private let limits: CodeAnalysisPromptLimits
    
    public init(limits: CodeAnalysisPromptLimits = .default) {
        self.limits = limits
    }
    
    public func build(
        context: SourceFileAnalysisContext
    ) throws -> String {
        guard limits.maximumPromptUTF8Bytes > 0 else {
            throw CodeAnalysisPromptBuildingError.invalidLimits
        }
        let sourceLines = SourceTextLineExtractor.lines(
            in: context.sourceContent
        )
        guard sourceLines.count == context.lineCount else {
            throw CodeAnalysisPromptBuildingError.sourceLineCountMismatch(
                expected: context.lineCount,
                actual: sourceLines.count
            )
        }
        
        let payload = BaselineCodeAnalysisPromptInput(
            file: BaselineCodeAnalysisFileInput(
                path: context.filePath,
                lineCount: context.lineCount,
                lines: sourceLines.enumerated().map { index, text in
                    BaselineCodeAnalysisSourceLineInput(
                        lineNumber: index + 1,
                        text: text
                    )
                }
            ),
            change: context.change
        )
        let inputJSON = try encode(payload)
        let promptText = BaselineCodeAnalysisPromptTemplateV1.render(
            inputJSON: inputJSON
        )
        let promptByteCount = promptText.utf8.count
        guard promptByteCount <= limits.maximumPromptUTF8Bytes else {
            throw CodeAnalysisPromptBuildingError.promptTooLarge(
                actualBytes: promptByteCount,
                maximumBytes: limits.maximumPromptUTF8Bytes
            )
        }
        
        return promptText
    }
    
    private func encode(
        _ input: BaselineCodeAnalysisPromptInput
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes,
        ]
        do {
            let data = try encoder.encode(input)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw CodeAnalysisPromptBuildingError.inputEncodingFailed
        }
    }
}

private struct BaselineCodeAnalysisPromptInput: Encodable {
    let file: BaselineCodeAnalysisFileInput
    let change: SourceFileChangeContext?
}

private struct BaselineCodeAnalysisFileInput: Encodable {
    let path: String
    let lineCount: Int
    let lines: [BaselineCodeAnalysisSourceLineInput]
}

private struct BaselineCodeAnalysisSourceLineInput: Encodable {
    let lineNumber: Int
    let text: String
}
