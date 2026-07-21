public enum FindingMetadataValue: Codable, Equatable, Sendable {
    case string(String)
    case integer(Int)
    case decimal(Double)
    case boolean(Bool)

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .decimal(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Finding metadata must be a JSON scalar value."
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .decimal(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        }
    }
}
