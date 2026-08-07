import ArcaAnalysis
import ArcaDomain
import ArcaSource
import ArcaSwiftSyntax
import Foundation
import Testing

@Suite("SwiftSyntax structure provider")
struct SwiftSyntaxStructureProviderTests {
    @Test("extracts class metrics without including nested type members")
    func extractsClassMetrics() throws {
        let metrics = try extractMetrics()
        let service = try #require(
            metrics.first { $0.name == "Service" && $0.kind == .class }
        )

        #expect(service.range == SourceRange(
            startLine: 1,
            startColumn: 1,
            endLine: 13,
            endColumn: 2
        ))
        #expect(service.lineCount == 13)
        #expect(service.methodCount == 2)
        #expect(service.propertyCount == 2)
    }

    @Test("extracts top-level and nested struct metrics independently")
    func extractsStructAndNestedTypeMetrics() throws {
        let metrics = try extractMetrics()
        let feature = try #require(
            metrics.first { $0.name == "Feature" && $0.kind == .struct }
        )
        let state = try #require(
            metrics.first { $0.name == "State" && $0.kind == .struct }
        )

        #expect(feature.range.startLine == 15)
        #expect(feature.range.endLine == 21)
        #expect(feature.lineCount == 7)
        #expect(feature.methodCount == 1)
        #expect(feature.propertyCount == 2)
        #expect(state.range.startLine == 8)
        #expect(state.range.endLine == 12)
        #expect(state.lineCount == 5)
        #expect(state.methodCount == 1)
        #expect(state.propertyCount == 1)
    }

    @Test("extracts actor metrics")
    func extractsActorMetrics() throws {
        let metrics = try extractMetrics()
        let actor = try #require(
            metrics.first { $0.name == "Store" && $0.kind == .actor }
        )

        #expect(actor.range.startLine == 23)
        #expect(actor.range.endLine == 27)
        #expect(actor.lineCount == 5)
        #expect(actor.methodCount == 1)
        #expect(actor.propertyCount == 1)
    }

    @Test("extracts extensions separately and excludes computed properties")
    func extractsExtensionMetrics() throws {
        let metrics = try extractMetrics()
        let feature = try #require(
            metrics.first { $0.name == "Feature" && $0.kind == .extension }
        )

        #expect(feature.range.startLine == 29)
        #expect(feature.range.endLine == 33)
        #expect(feature.lineCount == 5)
        #expect(feature.methodCount == 1)
        #expect(feature.propertyCount == 0)
    }

    @Test("calculates method cohesion and respects shadowing")
    func calculatesCohesion() throws {
        let source = SourceFile(
            path: "/project/Cohesion.swift",
            content: """
            final class Cohesion {
                var session = 0
                var invoices = 0

                func login() { self.session += 1 }
                func logout() { session = 0 }
                func export(invoices: Int) { print(invoices) }
            }
            """,
            lineCount: 8
        )

        let metrics = try #require(
            SwiftSyntaxStructureProvider().extractMetrics(from: [source]).first
        )

        #expect(metrics.cohesionEligibleMethodCount == 3)
        #expect(metrics.cohesionConnectedPairCount == 1)
        #expect(metrics.cohesionPossiblePairCount == 3)
        #expect(
            abs((metrics.tightClassCohesion ?? 0) - (1.0 / 3.0))
                < 0.000_001
        )
    }

    @Test("aggregates cohesion across selected source files")
    func aggregatesAcrossFiles() throws {
        let declaration = SourceFile(
            path: "/project/Account.swift",
            content: """
            final class Account {
                var session = 0
                var invoices = 0
                func login() { session += 1 }
            }
            """,
            lineCount: 5
        )
        let extensionFile = SourceFile(
            path: "/project/Account+Invoices.swift",
            content: """
            extension Account {
                func export() { print(invoices) }
            }
            """,
            lineCount: 3
        )

        let provider: any SwiftStructureProvider = SwiftSyntaxStructureProvider()
        let metrics = try #require(
            provider.extractMetrics(from: [declaration, extensionFile]).first
        )

        #expect(metrics.methodCount == 2)
        #expect(metrics.propertyCount == 2)
        #expect(metrics.tightClassCohesion == 0)
    }

    private func extractMetrics() throws -> [TypeStructuralMetrics] {
        let fixtureURL = try #require(
            Bundle.module.url(
                forResource: "StructuralTypes",
                withExtension: "swift",
                subdirectory: "Fixtures"
            )
        )
        let source = try SourceFileLoader().load(path: fixtureURL.path)
        let provider: any SwiftStructureProvider = SwiftSyntaxStructureProvider()
        return try provider.extractMetrics(from: source)
    }
}
