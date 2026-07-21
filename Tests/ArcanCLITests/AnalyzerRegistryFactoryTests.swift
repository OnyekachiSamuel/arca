import ArcanAnalysis
import ArcanDomain
import ArcanProcess
import Foundation
import Testing
@testable import ArcanCLI

@Suite("Analyzer registry factory")
struct AnalyzerRegistryFactoryTests {
    @Test("registers SwiftLint when its executable is available")
    func registersSwiftLint() {
        let executable = URL(fileURLWithPath: "/tools/swiftlint")
        let factory = AnalyzerRegistryFactory(
            swiftLintAvailability: .available(executable),
            processRunner: RegistryFactoryProcessRunner()
        )

        let registry = factory.make(
            configuration: .defaults,
            structureProvider: RegistryFactoryStructureProvider(),
            workingDirectoryURL: URL(
                fileURLWithPath: "/project",
                isDirectory: true
            )
        )

        #expect(
            registry.supportedReviewTypes == [.godObject, .style]
        )
        #expect(
            registry.analyzers(matching: [.style]).map(\.id)
                == ["swiftlint"]
        )
    }

    @Test("keeps style registered when SwiftLint is unavailable")
    func registersUnavailableSwiftLint() {
        let factory = AnalyzerRegistryFactory(
            swiftLintAvailability: .unavailable(.executableNotFound)
        )

        let registry = factory.make(
            configuration: .defaults,
            structureProvider: RegistryFactoryStructureProvider(),
            workingDirectoryURL: URL(
                fileURLWithPath: "/project",
                isDirectory: true
            )
        )

        #expect(registry.supportedReviewTypes == [.godObject, .style])
        #expect(
            registry.analyzers(matching: [.style]).map(\.id)
                == ["swiftlint"]
        )
    }
}

private struct RegistryFactoryProcessRunner: ProcessRunning {
    func run(_ request: ProcessRequest) async throws -> ProcessResult {
        ProcessResult(
            standardOutput: Data("[]".utf8),
            standardError: Data(),
            status: .exited(code: 0),
            durationMilliseconds: 0
        )
    }
}

private struct RegistryFactoryStructureProvider: SwiftStructureProvider {
    func extractMetrics(
        from sourceFile: SourceFile
    ) throws -> [TypeStructuralMetrics] {
        []
    }
}
