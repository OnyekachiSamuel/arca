import ArcaDomain
import Foundation

struct SwiftLintConfigurationDocument: Decodable {
    let availability: AnalyzerAvailabilityPolicy?
    let configurationPath: String?

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
            allowing: ["availability", "configurationPath"],
            pathPrefix: "swiftLint"
        )

        let availabilityKey = ConfigurationCodingKey("availability")
        if container.contains(availabilityKey) {
            guard try !container.decodeNil(forKey: availabilityKey),
                  let value = try? container.decode(
                      String.self,
                      forKey: availabilityKey
                  ),
                  let policy = AnalyzerAvailabilityPolicy(rawValue: value)
            else {
                throw ConfigurationDecodingIssue.invalidValue(
                    field: "swiftLint.availability",
                    reason: "expected one of: optional, required."
                )
            }
            availability = policy
        } else {
            availability = nil
        }

        let configurationPathKey = ConfigurationCodingKey(
            "configurationPath"
        )
        configurationPath = try container.decodeIfPresent(
            String.self,
            forKey: configurationPathKey
        )
        if let configurationPath,
           configurationPath.trimmingCharacters(
               in: .whitespacesAndNewlines
           ).isEmpty {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "swiftLint.configurationPath",
                reason: "must not be empty."
            )
        }
    }
}
