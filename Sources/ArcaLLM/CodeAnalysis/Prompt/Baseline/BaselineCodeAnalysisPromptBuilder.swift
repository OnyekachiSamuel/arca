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
        
        let sourceInput = CodeAnalysisSourceInputRenderer().render(
            context: context,
            sourceLines: sourceLines
        )
        let promptText = BaselineCodeAnalysisPromptTemplateV1.render(
            sourceInput: sourceInput
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
    
}
