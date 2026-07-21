import ArcanAnalysis
import ArcanAnalyzers
import ArcanDomain
import ArcanProcess
import Foundation

struct AnalyzerRegistryFactory: Sendable {
    private let swiftLintExecutableURL: URL?
    private let processRunner: (any ProcessRunning)?

    init(
        swiftLintExecutableURL: URL?,
        processRunner: (any ProcessRunning)? = nil
    ) {
        self.swiftLintExecutableURL = swiftLintExecutableURL
        self.processRunner = processRunner
    }

    func make(
        configuration: ArcanConfiguration,
        structureProvider: any SwiftStructureProvider,
        workingDirectoryURL: URL
    ) -> AnalyzerRegistry {
        var analyzers: [any Analyzer] = [
            GodObjectAnalyzer(
                thresholds: configuration.godObjectThresholds,
                structureProvider: structureProvider
            )
        ]

        if let swiftLintExecutableURL {
            let runner: any ProcessRunning
            if let processRunner {
                runner = processRunner
            } else {
                runner = ProcessRunner(
                    approvedExecutableURLs: [swiftLintExecutableURL]
                )
            }
            analyzers.append(SwiftLintAnalyzer(
                executableURL: swiftLintExecutableURL,
                workingDirectoryURL: workingDirectoryURL,
                processRunner: runner
            ))
        }

        return AnalyzerRegistry(analyzers: analyzers)
    }
}
