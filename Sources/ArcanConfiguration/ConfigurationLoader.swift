import ArcanDomain
import Foundation

public struct ConfigurationLoader {
    public static let fileName = ".arcan.json"

    public init() {}

    public func load(from directory: URL) throws -> ArcanConfiguration {
        let file = directory
            .standardizedFileURL
            .appendingPathComponent(Self.fileName)
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: file.path,
            isDirectory: &isDirectory
        ) else {
            return .defaults
        }

        guard !isDirectory.boolValue,
              fileManager.isReadableFile(atPath: file.path) else {
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

        guard document.schemaVersion == ArcanConfiguration.currentSchemaVersion
        else {
            throw ConfigurationLoadingError.unsupportedSchemaVersion(
                document.schemaVersion
            )
        }

        let thresholds = try document.godObject?
            .resolvedThresholds() ?? GodObjectThresholds()

        return ArcanConfiguration(
            schemaVersion: document.schemaVersion,
            godObjectThresholds: thresholds,
            swiftLint: SwiftLintConfiguration(
                availability: document.swiftLint?.availability ?? .optional
            ),
            llm: try document.llm?.resolvedConfiguration()
        )
    }
}
