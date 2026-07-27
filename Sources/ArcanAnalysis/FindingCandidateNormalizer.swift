import ArcanDomain
import Foundation

public struct FindingCandidateNormalizer: Sendable {
    public init() {}

    public func normalize(
        _ candidate: FindingCandidate,
        repositoryRoot: String?,
        sourceIdentifier: String? = nil
    ) throws -> FindingCandidate {
        try FindingCandidate(
            candidateID: candidate.candidateID,
            ruleID: candidate.ruleID,
            title: candidate.title,
            explanation: candidate.explanation,
            filePath: normalizedPath(
                candidate.filePath,
                repositoryRoot: repositoryRoot
            ),
            range: candidate.range,
            proposedSeverity: candidate.proposedSeverity,
            proposedCategory: candidate.proposedCategory,
            evidence: candidate.evidence,
            sourceIdentifiers: normalizedSources(
                candidate.sourceIdentifiers,
                adding: sourceIdentifier
            ),
            analyzerMetadata: candidate.analyzerMetadata
        )
    }

    private func normalizedSources(
        _ sources: [String],
        adding sourceIdentifier: String?
    ) -> [String] {
        var seen: Set<String> = []
        var values = sources
        if let sourceIdentifier { values.append(sourceIdentifier) }
        return values.filter { seen.insert($0).inserted }
    }

    private func normalizedPath(
        _ path: String,
        repositoryRoot: String?
    ) -> String {
        let rootURL = repositoryRoot.map {
            canonicalURL(for: $0, isDirectory: true)
        }
        let fileURL: URL
        if path.hasPrefix("/") {
            fileURL = canonicalURL(for: path)
        } else if let rootURL {
            fileURL = rootURL.appendingPathComponent(path)
                .standardizedFileURL.resolvingSymlinksInPath()
        } else {
            fileURL = URL(fileURLWithPath: path)
                .standardizedFileURL.resolvingSymlinksInPath()
        }

        guard let rootURL,
              fileURL.pathComponents.starts(with: rootURL.pathComponents)
        else { return fileURL.path }

        return fileURL.pathComponents
            .dropFirst(rootURL.pathComponents.count)
            .joined(separator: "/")
    }

    private func canonicalURL(
        for path: String,
        isDirectory: Bool = false
    ) -> URL {
        URL(fileURLWithPath: path, isDirectory: isDirectory)
            .standardizedFileURL.resolvingSymlinksInPath()
    }
}
