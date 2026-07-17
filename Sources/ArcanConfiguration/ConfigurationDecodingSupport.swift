import Foundation

enum ConfigurationDecodingSupport {
    static func rejectUnknownFields(
        in container: KeyedDecodingContainer<ConfigurationCodingKey>,
        allowing allowedFields: Set<String>,
        pathPrefix: String? = nil
    ) throws {
        let unknownField = container.allKeys
            .map(\.stringValue)
            .filter { !allowedFields.contains($0) }
            .sorted()
            .first

        guard let unknownField else {
            return
        }

        let fieldPath =
            pathPrefix.map { "\($0).\(unknownField)" } ?? unknownField
        throw ConfigurationDecodingIssue.unknownField(fieldPath)
    }

    static func decodeOptionalInteger(
        from container: KeyedDecodingContainer<ConfigurationCodingKey>,
        key: String,
        pathPrefix: String
    ) throws -> Int? {
        let codingKey = ConfigurationCodingKey(key)
        guard container.contains(codingKey) else {
            return nil
        }

        return try decodeInteger(
            from: container,
            forKey: codingKey,
            field: "\(pathPrefix).\(key)"
        )
    }

    static func decodeInteger(
        from container: KeyedDecodingContainer<ConfigurationCodingKey>,
        forKey key: ConfigurationCodingKey,
        field: String
    ) throws -> Int {
        guard try !container.decodeNil(forKey: key) else {
            throw ConfigurationDecodingIssue.invalidValue(
                field: field,
                reason: "expected an integer."
            )
        }

        do {
            return try container.decode(Int.self, forKey: key)
        } catch {
            throw ConfigurationDecodingIssue.invalidValue(
                field: field,
                reason: "expected an integer."
            )
        }
    }
}
