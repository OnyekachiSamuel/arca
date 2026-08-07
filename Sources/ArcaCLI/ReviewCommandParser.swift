import ArcaDomain

struct ReviewCommandParser {
    func parse(arguments: [String]) throws -> ReviewCommandOptions {
        var source: ReviewCommandOptions.Source?
        var reviewValues: [String] = []
        var outputFormat = ReviewOutputFormat.terminal
        var outputFormatWasSpecified = false
        var debug = false
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--file":
                let path = try value(
                    after: "--file",
                    at: index,
                    in: arguments
                )
                try setSource(.file(path), currentSource: &source)
                index += 2
            case "--changed":
                try setSource(.changed, currentSource: &source)
                index += 1
            case "--review":
                reviewValues.append(
                    try value(
                        after: "--review",
                        at: index,
                        in: arguments
                    )
                )
                index += 2
            case "--format":
                guard !outputFormatWasSpecified else {
                    throw ReviewCommandParsingError.duplicateOption(
                        "--format"
                    )
                }
                let rawFormat = try value(
                    after: "--format",
                    at: index,
                    in: arguments
                )
                guard let parsedFormat = ReviewOutputFormat(
                    rawValue: rawFormat
                ) else {
                    throw ReviewCommandParsingError.unsupportedOutputFormat(
                        rawFormat,
                        availableValues: ReviewOutputFormat.allCases.map(
                            \.rawValue
                        )
                    )
                }
                outputFormat = parsedFormat
                outputFormatWasSpecified = true
                index += 2
            case "--debug":
                debug = true
                index += 1
            default:
                throw ReviewCommandParsingError.unknownOption(
                    arguments[index]
                )
            }
        }

        if debug {
            guard case .file = source else {
                throw ReviewCommandParsingError.debugRequiresFile
            }
            guard outputFormat != .json else {
                throw ReviewCommandParsingError
                    .jsonFormatDoesNotSupportDebug
            }
        }

        return ReviewCommandOptions(
            source: source,
            reviewSelection: try makeReviewSelection(from: reviewValues),
            outputFormat: outputFormat,
            debug: debug
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
            throw ReviewCommandParsingError.missingValue(option: option)
        }
        return arguments[valueIndex]
    }

    private func setSource(
        _ newSource: ReviewCommandOptions.Source,
        currentSource: inout ReviewCommandOptions.Source?
    ) throws {
        guard currentSource == nil else {
            throw ReviewCommandParsingError.multipleSourceSelections
        }
        currentSource = newSource
    }

    private func makeReviewSelection(
        from values: [String]
    ) throws -> ReviewSelection {
        var selectsAll = values.isEmpty
        var reviewTypes: Set<ReviewType> = []

        for value in values {
            if value == "all" {
                selectsAll = true
                continue
            }
            guard let reviewType = ReviewType(commandLineName: value) else {
                throw ReviewCommandParsingError.unsupportedReviewType(value)
            }
            reviewTypes.insert(reviewType)
        }

        return selectsAll ? .all : .types(reviewTypes)
    }
}
