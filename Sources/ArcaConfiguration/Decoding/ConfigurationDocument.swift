import Foundation

struct ConfigurationDocument: Decodable {
    let schemaVersion: Int
    let llm: LLMConfigurationDocument?
    
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
            allowing: ["schemaVersion", "llm"]
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
        
        let llmKey = ConfigurationCodingKey("llm")
        guard container.contains(llmKey) else {
            llm = nil
            return
        }
        guard try !container.decodeNil(forKey: llmKey) else {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "llm",
                reason: "expected a JSON object."
            )
        }
        do {
            llm = try container.decode(
                LLMConfigurationDocument.self,
                forKey: llmKey
            )
        } catch let issue as ConfigurationDecodingIssue {
            throw issue
        } catch {
            throw ConfigurationDecodingIssue.invalidValue(
                field: "llm",
                reason: "expected a JSON object."
            )
        }
    }
}
