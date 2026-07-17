import Foundation

struct ConfigurationDocument: Decodable {
    let schemaVersion: Int
    let godObject: GodObjectThresholdConfiguration?

    init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<ConfigurationCodingKey>
        do {
            container = try decoder.container(
                keyedBy: ConfigurationCodingKey.self
            )
        } catch {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "configuration",
                reason: "expected a JSON object."
            )
        }

        try ConfigurationDecodingSupport.rejectUnknownFields(
            in: container,
            allowing: ["schemaVersion", "godObject"]
        )

        let schemaVersionKey = ConfigurationCodingKey("schemaVersion")
        guard container.contains(schemaVersionKey) else {
            throw ConfigurationDecodingIssue.missingSchemaVersion
        }
        schemaVersion = try ConfigurationDecodingSupport.decodeInteger(
            from: container,
            forKey: schemaVersionKey,
            field: "schemaVersion"
        )

        let godObjectKey = ConfigurationCodingKey("godObject")
        guard container.contains(godObjectKey) else {
            godObject = nil
            return
        }
        guard try !container.decodeNil(forKey: godObjectKey) else {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "godObject",
                reason: "expected a JSON object."
            )
        }
        do {
            godObject = try container.decode(
                GodObjectThresholdConfiguration.self,
                forKey: godObjectKey
            )
        } catch let issue as ConfigurationDecodingIssue {
            throw issue
        } catch {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "godObject",
                reason: "expected a JSON object."
            )
        }
    }
}
