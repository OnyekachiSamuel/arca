import Foundation

enum LLMCommandParsingError: Error, Equatable, LocalizedError {
  case duplicateOption(String)
  case missingOption(String)
  case missingValue(String)
  case unknownOption(String)
  case unsupportedPromptVariant(String)
  case unsupportedReviewType(String)
  case unsupportedOutputFormat(String)
  case baselineDoesNotAcceptReview
  case missingReviewForGuidedPrompt

  var errorDescription: String? {
    switch self {
    case .duplicateOption(let option):
      "Option '\(option)' may only be provided once."
    case .missingOption(let option):
      "Required option '\(option)' was not provided."
    case .missingValue(let option):
      "Option '\(option)' requires a value."
    case .unknownOption(let option):
      "Unknown llm option '\(option)'."
    case .unsupportedPromptVariant(let value):
      "Unsupported prompt variant '\(value)'. Use baseline or guided."
    case .unsupportedReviewType(let value):
      "Unsupported review type '\(value)'."
    case .unsupportedOutputFormat(let value):
      "Unsupported output format '\(value)'. Use terminal or json."
    case .baselineDoesNotAcceptReview:
      "Option '--review' must not be provided with the baseline prompt."
    case .missingReviewForGuidedPrompt:
      "The guided prompt requires option '--review'."
    }
  }
}
