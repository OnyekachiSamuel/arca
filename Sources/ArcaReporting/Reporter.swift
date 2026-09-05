import ArcaDomain

public protocol Reporter: Sendable {
  func render(detectionReport: LLMIssueDetectionReport) throws -> String
}
