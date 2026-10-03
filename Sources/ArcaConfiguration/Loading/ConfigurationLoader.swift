import ArcaDomain
import Foundation

public struct ConfigurationLoader {
    public static let fileName = ".arca.json"
    
    public init() {}
    
    public func load(from directory: URL) throws -> ArcaConfiguration {
        let file = directory
            .standardizedFileURL
            .appendingPathComponent(Self.fileName)
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        guard
            fileManager.fileExists(
                atPath: file.path,
                isDirectory: &isDirectory
            )
        else {
            return .defaults
        }
        
        guard !isDirectory.boolValue,
              fileManager.isReadableFile(atPath: file.path)
        else {
            throw ConfigurationLoadingError.unreadableFile(file.path)
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            throw ConfigurationLoadingError.unreadableFile(file.path)
        }
        
        let document: ConfigurationDocument
        do {
            document = try JSONDecoder().decode(
                ConfigurationDocument.self,
                from: data
            )
        } catch let issue as ConfigurationDecodingIssue {
            throw issue.loadingError
        } catch {
            throw ConfigurationLoadingError.invalidJSON(file.path)
        }
        
        guard document.schemaVersion == ArcaConfiguration.currentSchemaVersion
        else {
            throw ConfigurationLoadingError.unsupportedSchemaVersion(
                document.schemaVersion
            )
        }
        
        return ArcaConfiguration(
            schemaVersion: document.schemaVersion,
            llm: try document.llm?.resolvedConfiguration()
        )
    }
}
