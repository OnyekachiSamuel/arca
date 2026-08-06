import ArcanDomain
import Foundation

struct GodObjectThresholdConfiguration: Decodable {
    let maximumLines: Int?
    let maximumMethods: Int?
    let maximumStoredProperties: Int?
    let minimumTriggeredSignals: Int?
    let minimumTightClassCohesion: Double?

    init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<ConfigurationCodingKey>
        do {
            container = try decoder.container(
                keyedBy: ConfigurationCodingKey.self
            )
        } catch {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "godObject",
                reason: "expected a JSON object."
            )
        }

        try ConfigurationDecodingSupport.rejectUnknownFields(
            in: container,
            allowing: [
                "maximumLines",
                "maximumMethods",
                "maximumStoredProperties",
                "minimumTriggeredSignals",
                "minimumTightClassCohesion"
            ],
            pathPrefix: "godObject"
        )

        maximumLines = try ConfigurationDecodingSupport.decodeOptionalInteger(
            from: container,
            key: "maximumLines",
            pathPrefix: "godObject"
        )
        maximumMethods = try ConfigurationDecodingSupport.decodeOptionalInteger(
            from: container,
            key: "maximumMethods",
            pathPrefix: "godObject"
        )
        maximumStoredProperties =
            try ConfigurationDecodingSupport.decodeOptionalInteger(
                from: container,
                key: "maximumStoredProperties",
                pathPrefix: "godObject"
            )
        minimumTriggeredSignals =
            try ConfigurationDecodingSupport.decodeOptionalInteger(
                from: container,
                key: "minimumTriggeredSignals",
                pathPrefix: "godObject"
            )
        minimumTightClassCohesion = try Self.decodeOptionalDouble(
            from: container,
            key: "minimumTightClassCohesion"
        )
    }

    func resolvedThresholds() throws -> GodObjectThresholds {
        let defaults = GodObjectThresholds()
        let resolved = GodObjectThresholds(
            maximumLines: maximumLines ?? defaults.maximumLines,
            maximumMethods: maximumMethods ?? defaults.maximumMethods,
            maximumStoredProperties:
                maximumStoredProperties ?? defaults.maximumStoredProperties,
            minimumTriggeredSignals:
                minimumTriggeredSignals ?? defaults.minimumTriggeredSignals,
            minimumTightClassCohesion:
                minimumTightClassCohesion
                    ?? defaults.minimumTightClassCohesion
        )

        guard resolved.maximumLines >= 1 else {
            throw ConfigurationLoadingError.invalidValue(
                field: "godObject.maximumLines",
                reason: "must be at least 1."
            )
        }
        guard resolved.maximumMethods >= 0 else {
            throw ConfigurationLoadingError.invalidValue(
                field: "godObject.maximumMethods",
                reason: "must be at least 0."
            )
        }
        guard resolved.maximumStoredProperties >= 0 else {
            throw ConfigurationLoadingError.invalidValue(
                field: "godObject.maximumStoredProperties",
                reason: "must be at least 0."
            )
        }
        guard (1...3).contains(resolved.minimumTriggeredSignals) else {
            throw ConfigurationLoadingError.invalidValue(
                field: "godObject.minimumTriggeredSignals",
                reason: "must be between 1 and 3."
            )
        }
        guard resolved.minimumTightClassCohesion.isFinite,
              (0...1).contains(resolved.minimumTightClassCohesion) else {
            throw ConfigurationLoadingError.invalidValue(
                field: "godObject.minimumTightClassCohesion",
                reason: "must be between 0 and 1."
            )
        }

        return resolved
    }

    private static func decodeOptionalDouble(
        from container: KeyedDecodingContainer<ConfigurationCodingKey>,
        key: String
    ) throws -> Double? {
        let codingKey = ConfigurationCodingKey(key)
        guard container.contains(codingKey) else { return nil }
        guard try !container.decodeNil(forKey: codingKey) else {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "godObject.\(key)",
                reason: "expected a number."
            )
        }
        do {
            return try container.decode(Double.self, forKey: codingKey)
        } catch {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "godObject.\(key)",
                reason: "expected a number."
            )
        }
    }
}
