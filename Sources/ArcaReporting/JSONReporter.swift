import ArcaDomain
import Foundation

public struct JSONReporter: Reporter {
  public init() {}

  public func render(
    detectionReport: LLMIssueDetectionReport
  ) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(
      decoding: try encoder.encode(detectionReport),
      as: UTF8.self
    )
  }
}
