public struct ArcanConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public static let defaults = ArcanConfiguration(
        schemaVersion: currentSchemaVersion,
        godObjectThresholds: GodObjectThresholds()
    )

    public let schemaVersion: Int
    public let godObjectThresholds: GodObjectThresholds

    public init(
        schemaVersion: Int,
        godObjectThresholds: GodObjectThresholds
    ) {
        self.schemaVersion = schemaVersion
        self.godObjectThresholds = godObjectThresholds
    }
}
