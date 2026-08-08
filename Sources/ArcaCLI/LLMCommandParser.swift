import ArcaDomain

struct LLMCommandParser {
    func parse(arguments: [String]) throws -> LLMCommandOptions {
        var filePath: String?
        var reviewType: ReviewType?
        var promptVariant: CodeAnalysisPromptVariant?
        var outputFormat = ReviewOutputFormat.terminal
        var outputFormatWasSpecified = false
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
                guard let parsed = CodeAnalysisPromptVariant(
                    rawValue: rawValue
                ) else {
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
            default:
                throw LLMCommandParsingError.unknownOption(arguments[index])
            }
        }

        guard let filePath else {
            throw LLMCommandParsingError.missingOption("--file")
        }
        guard let reviewType else {
            throw LLMCommandParsingError.missingOption("--review")
        }
        guard let promptVariant else {
            throw LLMCommandParsingError.missingOption("--prompt")
        }

        return LLMCommandOptions(
            filePath: filePath,
            reviewType: reviewType,
            promptVariant: promptVariant,
            outputFormat: outputFormat
        )
    }

    private func value(
        after option: String,
        at index: Int,
        in arguments: [String]
    ) throws -> String {
        let valueIndex = index + 1
        guard arguments.indices.contains(valueIndex),
              !arguments[valueIndex].hasPrefix("--") else {
            throw LLMCommandParsingError.missingValue(option)
        }
        return arguments[valueIndex]
    }
}
