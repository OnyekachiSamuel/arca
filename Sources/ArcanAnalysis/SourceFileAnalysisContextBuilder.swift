import ArcanDomain
import Foundation

public struct SourceFileAnalysisContextBuilder: Sendable {
    private let limits: SourceFileAnalysisContextLimits

    public init(limits: SourceFileAnalysisContextLimits = .default) {
        self.limits = limits
    }

    public func build(
        from analysisContext: AnalysisContext
    ) -> SourceFileAnalysisContextBuildResult {
        var contexts: [SourceFileAnalysisContext] = []
        var diagnostics: [AnalyzerDiagnostic] = []

        for sourceFile in analysisContext.sourceFiles {
            let filePath = contextPath(
                for: sourceFile.path,
                repositoryRoot: analysisContext.request.repositoryRoot
            )
            let sourceByteCount = sourceFile.content.utf8.count

            guard sourceByteCount <= limits.maximumSourceUTF8Bytes else {
                diagnostics.append(oversizedFileDiagnostic(
                    filePath: filePath,
                    actualBytes: sourceByteCount
                ))
                continue
            }

            let change = analysisContext.changes.first {
                canonicalPath($0.filePath) == canonicalPath(sourceFile.path)
            }.map {
                makeChangeContext(
                    from: $0,
                    repositoryRoot: analysisContext.request.repositoryRoot
                )
            }
            contexts.append(SourceFileAnalysisContext(
                filePath: filePath,
                sourceContent: sourceFile.content,
                lineCount: sourceFile.lineCount,
                change: change
            ))
        }

        return SourceFileAnalysisContextBuildResult(
            contexts: contexts,
            diagnostics: diagnostics
        )
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

    private func oversizedFileDiagnostic(
        filePath: String,
        actualBytes: Int
    ) -> AnalyzerDiagnostic {
        AnalyzerDiagnostic(
            code: "ARCAN-LLM-SOURCE-FILE-TOO-LARGE",
            severity: .warning,
            message: """
            LLM analysis was skipped for '\(filePath)': the source is \(actualBytes) UTF-8 bytes; the limit is \(limits.maximumSourceUTF8Bytes). Static analysis can still run.
            """
        )
    }

    private func contextPath(
        for path: String,
        repositoryRoot: String?
    ) -> String {
        let fileURL = canonicalURL(for: path)
        guard let repositoryRoot else {
            return fileURL.lastPathComponent
        }

        let rootURL = canonicalURL(for: repositoryRoot, isDirectory: true)
        guard fileURL.pathComponents.starts(with: rootURL.pathComponents)
        else {
            return fileURL.lastPathComponent
        }

        return fileURL.pathComponents
            .dropFirst(rootURL.pathComponents.count)
            .joined(separator: "/")
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
