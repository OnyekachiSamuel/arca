import ArcanDomain
import Foundation

public struct SourceFileLoader: Sendable {
    public init() {}

    public func load(path: String) throws -> SourceFile {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path

        guard FileManager.default.isReadableFile(atPath: normalizedPath) else {
            throw SourceLoadingError.unreadable(path: normalizedPath)
        }

        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: normalizedPath))
        } catch {
            throw SourceLoadingError.unreadable(path: normalizedPath)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw SourceLoadingError.invalidUTF8(path: normalizedPath)
        }

        return SourceFile(
            path: normalizedPath,
            content: content,
            lineCount: lineCount(in: content)
        )
    }

    private func lineCount(in content: String) -> Int {
        guard !content.isEmpty else { return 0 }

        let newlineCount = content.reduce(into: 0) { count, character in
            if character.isNewline {
                count += 1
            }
        }
        return content.last?.isNewline == true
            ? newlineCount
            : newlineCount + 1
    }
}
