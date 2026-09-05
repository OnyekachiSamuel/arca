public struct ArcaConfiguration: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 1
  public static let defaults = ArcaConfiguration(
    schemaVersion: currentSchemaVersion
  )

  public let schemaVersion: Int
  public let llm: LLMConfiguration?

  public init(
    schemaVersion: Int,
    llm: LLMConfiguration? = nil
  ) {
    self.schemaVersion = schemaVersion
    self.llm = llm
  }
}
