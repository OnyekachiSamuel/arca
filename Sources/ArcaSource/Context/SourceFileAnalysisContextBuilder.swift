import ArcaDomain
import Foundation

public struct SourceFileAnalysisContextBuilder: Sendable {
    public init() {}
    
    public func build(
        sourceFile: SourceFile,
        repositoryRoot: String?,
        changes: [CodeChange] = []
    ) -> SourceFileAnalysisContext {
        let change = changes.first {
            canonicalPath($0.filePath) == canonicalPath(sourceFile.path)
        }.map {
            makeChangeContext(from: $0, repositoryRoot: repositoryRoot)
        }
        return SourceFileAnalysisContext(
            filePath: contextPath(
                for: sourceFile.path,
                repositoryRoot: repositoryRoot
            ),
            sourceContent: sourceFile.content,
            lineCount: sourceFile.lineCount,
            change: change
        )
    }
    
    public func contextPath(
        for path: String,
        repositoryRoot: String?
    ) -> String {
        let fileURL = canonicalURL(for: path)
        guard let repositoryRoot else {
            return fileURL.lastPathComponent
        }
        
        let rootURL = canonicalURL(for: repositoryRoot, isDirectory: true)
        guard fileURL.pathComponents.starts(with: rootURL.pathComponents) else {
            return fileURL.lastPathComponent
        }
        
        return fileURL.pathComponents
            .dropFirst(rootURL.pathComponents.count)
            .joined(separator: "/")
    }
    
    private func makeChangeContext(
        from change: CodeChange,
        repositoryRoot: String?
    ) -> SourceFileChangeContext {
        SourceFileChangeContext(
            previousFilePath: change.previousFilePath.map {
                contextPath(for: $0, repositoryRoot: repositoryRoot)
            },
            addedLineRanges: change.addedLineRanges,
            modifiedLineRanges: change.modifiedLineRanges,
            deletedLineRanges: change.deletedLineRanges
        )
    }
    
    private func canonicalPath(_ path: String) -> String {
        canonicalURL(for: path).path
    }
    
    private func canonicalURL(
        for path: String,
        isDirectory: Bool = false
    ) -> URL {
        URL(fileURLWithPath: path, isDirectory: isDirectory)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }
}
