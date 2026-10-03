import ArcaDomain

struct LLMCommandParser {
  func parse(arguments: [String]) throws -> LLMCommandOptions {
    var filePath: String?
    var reviewType: ReviewType?
    var promptVariant: CodeAnalysisPromptVariant?
    var providerID: String?
    var outputFormat = ReviewOutputFormat.terminal
    var outputFormatWasSpecified = false
    var showPrompt = false
    var index = 0

    while index < arguments.count {
      switch arguments[index] {
      case "--file":
        guard filePath == nil else {
          throw LLMCommandParsingError.duplicateOption("--file")
        }
        filePath = try value(
          after: "--file",
          at: index,
          in: arguments
        )
        index += 2
      case "--review":
        guard reviewType == nil else {
          throw LLMCommandParsingError.duplicateOption("--review")
        }
        let rawValue = try value(
          after: "--review",
          at: index,
          in: arguments
        )
        guard let parsed = ReviewType(commandLineName: rawValue) else {
          throw LLMCommandParsingError.unsupportedReviewType(
            rawValue
          )
        }
        reviewType = parsed
        index += 2
      case "--prompt":
        guard promptVariant == nil else {
          throw LLMCommandParsingError.duplicateOption("--prompt")
        }
        let rawValue = try value(
          after: "--prompt",
          at: index,
          in: arguments
        )
        guard
          let parsed = CodeAnalysisPromptVariant(
            rawValue: rawValue
          )
        else {
          throw LLMCommandParsingError.unsupportedPromptVariant(
            rawValue
          )
        }
        promptVariant = parsed
        index += 2
      case "--format":
        guard !outputFormatWasSpecified else {
          throw LLMCommandParsingError.duplicateOption("--format")
        }
        let rawValue = try value(
          after: "--format",
          at: index,
          in: arguments
        )
        guard let parsed = ReviewOutputFormat(rawValue: rawValue) else {
          throw LLMCommandParsingError.unsupportedOutputFormat(
            rawValue
          )
        }
        outputFormat = parsed
        outputFormatWasSpecified = true
        index += 2
      case "--provider":
        guard providerID == nil else {
          throw LLMCommandParsingError.duplicateOption("--provider")
        }
        providerID = try value(
          after: "--provider",
          at: index,
          in: arguments
        )
        index += 2
      case "--show-prompt":
        guard !showPrompt else {
          throw LLMCommandParsingError.duplicateOption("--show-prompt")
        }
        showPrompt = true
        index += 1
      default:
        throw LLMCommandParsingError.unknownOption(arguments[index])
      }
    }

    guard let filePath else {
      throw LLMCommandParsingError.missingOption("--file")
    }
    guard let promptVariant else {
      throw LLMCommandParsingError.missingOption("--prompt")
    }

    switch promptVariant {
    case .baseline where reviewType != nil:
      throw LLMCommandParsingError.baselineDoesNotAcceptReview
    case .guided where reviewType == nil:
      throw LLMCommandParsingError.missingReviewForGuidedPrompt
    case .baseline, .guided:
      break
    }

    return LLMCommandOptions(
      filePath: filePath,
      reviewType: reviewType,
      promptVariant: promptVariant,
      providerID: providerID,
      outputFormat: outputFormat,
      showPrompt: showPrompt
    )
  }

  private func value(
    after option: String,
    at index: Int,
    in arguments: [String]
  ) throws -> String {
    let valueIndex = index + 1
    guard arguments.indices.contains(valueIndex),
      !arguments[valueIndex].hasPrefix("--")
    else {
      throw LLMCommandParsingError.missingValue(option)
    }
    return arguments[valueIndex]
  }
}
