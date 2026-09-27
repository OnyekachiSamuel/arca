import Foundation

public struct LLMIssueDetectionReport: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 1

  public let schemaVersion: Int
  public let requestID: UUID
  public let filePath: String
  public let reviewType: ReviewType?
  public let promptVariant: CodeAnalysisPromptVariant
  public let analysis: LLMIssueDetectionResult
  public let seed: Int?
  public let temperature: Double?

  public init(
    schemaVersion: Int = LLMIssueDetectionReport.currentSchemaVersion,
    requestID: UUID,
    filePath: String,
    reviewType: ReviewType?,
    promptVariant: CodeAnalysisPromptVariant,
    analysis: LLMIssueDetectionResult,
    seed: Int?,
    temperature: Double?
  ) {
    self.schemaVersion = schemaVersion
    self.requestID = requestID
    self.filePath = filePath
    self.reviewType = reviewType
    self.promptVariant = promptVariant
    self.analysis = analysis
    self.seed = seed
    self.temperature = temperature
  }
}
