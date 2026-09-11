import ArcaDomain

struct LLMCommandOptions: Equatable, Sendable {
  let filePath: String
  let reviewType: ReviewType?
  let promptVariant: CodeAnalysisPromptVariant
  let providerID: String?
  let outputFormat: ReviewOutputFormat
}
