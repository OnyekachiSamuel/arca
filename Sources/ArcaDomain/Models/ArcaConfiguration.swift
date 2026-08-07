public struct ArcaConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public static let defaults = ArcaConfiguration(
        schemaVersion: currentSchemaVersion,
        godObjectThresholds: GodObjectThresholds(),
        swiftLint: SwiftLintConfiguration(),
        llm: nil
    )

    public let schemaVersion: Int
    public let godObjectThresholds: GodObjectThresholds
    public let swiftLint: SwiftLintConfiguration
    public let llm: LLMConfiguration?

    public init(
        schemaVersion: Int,
        godObjectThresholds: GodObjectThresholds,
        swiftLint: SwiftLintConfiguration = SwiftLintConfiguration(),
        llm: LLMConfiguration? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.godObjectThresholds = godObjectThresholds
        self.swiftLint = swiftLint
        self.llm = llm
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case godObjectThresholds
        case swiftLint
        case llm
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        godObjectThresholds = try container.decode(
            GodObjectThresholds.self,
            forKey: .godObjectThresholds
        )
        swiftLint = try container.decodeIfPresent(
            SwiftLintConfiguration.self,
            forKey: .swiftLint
        ) ?? SwiftLintConfiguration()
        llm = try container.decodeIfPresent(
            LLMConfiguration.self,
            forKey: .llm
        )
    }
}
