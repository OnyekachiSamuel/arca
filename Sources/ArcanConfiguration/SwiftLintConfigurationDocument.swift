import ArcanDomain
import Foundation

struct SwiftLintConfigurationDocument: Decodable {
    let availability: AnalyzerAvailabilityPolicy?

    init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<ConfigurationCodingKey>
        do {
            container = try decoder.container(
                keyedBy: ConfigurationCodingKey.self
            )
        } catch {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "swiftLint",
                reason: "expected a JSON object."
            )
        }

        try ConfigurationDecodingSupport.rejectUnknownFields(
            in: container,
            allowing: ["availability"],
            pathPrefix: "swiftLint"
        )

        let key = ConfigurationCodingKey("availability")
        guard container.contains(key) else {
            availability = nil
            return
        }
        guard try !container.decodeNil(forKey: key),
              let value = try? container.decode(String.self, forKey: key),
              let policy = AnalyzerAvailabilityPolicy(rawValue: value) else {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "swiftLint.availability",
                reason: "expected one of: optional, required."
            )
        }
        availability = policy
    }
}
