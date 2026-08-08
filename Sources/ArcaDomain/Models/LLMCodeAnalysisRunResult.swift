import Foundation

public struct LLMCodeAnalysisRunResult: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let runID: UUID
    public let filePath: String
    public let reviewType: ReviewType
    public let promptVariant: CodeAnalysisPromptVariant
    public let promptTemplateID: String
    public let promptTemplateVersion: Int
    public let findings: [LLMCodeAnalysisFinding]
    public let diagnostics: [AnalyzerDiagnostic]
    public let executionMetadata: LLMExecutionMetadata
    public let seed: Int?
    public let temperature: Double?

    public init(
        schemaVersion: Int,
        runID: UUID,
        filePath: String,
        reviewType: ReviewType,
        promptVariant: CodeAnalysisPromptVariant,
        promptTemplateID: String,
        promptTemplateVersion: Int,
        findings: [LLMCodeAnalysisFinding],
        diagnostics: [AnalyzerDiagnostic],
        executionMetadata: LLMExecutionMetadata,
        seed: Int?,
        temperature: Double?
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.filePath = filePath
        self.reviewType = reviewType
        self.promptVariant = promptVariant
        self.promptTemplateID = promptTemplateID
        self.promptTemplateVersion = promptTemplateVersion
        self.findings = findings
        self.diagnostics = diagnostics
        self.executionMetadata = executionMetadata
        self.seed = seed
        self.temperature = temperature
    }
}
