public struct ArcanConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public static let defaults = ArcanConfiguration(
        schemaVersion: currentSchemaVersion,
        godObjectThresholds: GodObjectThresholds(),
        swiftLint: SwiftLintConfiguration()
    )

    public let schemaVersion: Int
    public let godObjectThresholds: GodObjectThresholds
    public let swiftLint: SwiftLintConfiguration

    public init(
        schemaVersion: Int,
        godObjectThresholds: GodObjectThresholds,
        swiftLint: SwiftLintConfiguration = SwiftLintConfiguration()
    ) {
        self.schemaVersion = schemaVersion
        self.godObjectThresholds = godObjectThresholds
        self.swiftLint = swiftLint
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case godObjectThresholds
        case swiftLint
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
    }
}
