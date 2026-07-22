import ArcanDomain
import Foundation

public struct FindingNormalizer: Sendable {
    public init() {}

    public func normalize(
        _ finding: Finding,
        repositoryRoot: String?,
        sourceIdentifier: String? = nil
    ) throws -> Finding {
        try validate(finding.range, filePath: finding.filePath)

        return Finding(
            id: finding.id,
            ruleID: finding.ruleID,
            externalRuleID: finding.externalRuleID,
            title: finding.title,
            category: finding.category,
            severity: finding.severity,
            filePath: normalizedPath(
                finding.filePath,
                repositoryRoot: repositoryRoot
            ),
            range: finding.range,
            explanation: finding.explanation,
            evidence: finding.evidence,
            suggestion: finding.suggestion,
            sources: normalizedSources(
                finding.sources,
                adding: sourceIdentifier
            ),
            metadata: finding.metadata
        )
    }

    private func normalizedSources(
        _ sources: [String],
        adding sourceIdentifier: String?
    ) -> [String] {
        var seen: Set<String> = []
        var candidates = sources
        if let sourceIdentifier {
            candidates.append(sourceIdentifier)
        }
        return candidates.filter { seen.insert($0).inserted }
    }

    private func normalizedPath(
        _ path: String,
        repositoryRoot: String?
    ) -> String {
        let rootURL = repositoryRoot.map {
            canonicalURL(forAbsolutePath: $0, isDirectory: true)
        }
        let fileURL: URL
        if path.hasPrefix("/") {
            fileURL = canonicalURL(forAbsolutePath: path)
        } else if let rootURL {
            fileURL = rootURL
                .appendingPathComponent(path)
                .standardizedFileURL
                .resolvingSymlinksInPath()
        } else {
            fileURL = URL(fileURLWithPath: path)
                .standardizedFileURL
                .resolvingSymlinksInPath()
        }

        guard let rootURL,
              fileURL.pathComponents.starts(with: rootURL.pathComponents)
        else {
            return fileURL.path
        }

        return fileURL.pathComponents
            .dropFirst(rootURL.pathComponents.count)
            .joined(separator: "/")
    }

    private func canonicalURL(
        forAbsolutePath path: String,
        isDirectory: Bool = false
    ) -> URL {
        URL(fileURLWithPath: path, isDirectory: isDirectory)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    private func validate(
        _ range: SourceRange?,
        filePath: String
    ) throws {
        guard let range else { return }

        let positionsAreOneBased = range.startLine > 0
            && range.startColumn > 0
            && range.endLine > 0
            && range.endColumn > 0
        let endFollowsStart = range.endLine > range.startLine
            || (
                range.endLine == range.startLine
                    && range.endColumn >= range.startColumn
            )
        guard positionsAreOneBased, endFollowsStart else {
            throw FindingNormalizationError.invalidRange(filePath: filePath)
        }
    }
}
