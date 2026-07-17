import ArcanAnalysis
import ArcanDomain
import SwiftParser
import SwiftSyntax

final class SwiftSourceCodeMetricsExtractor: SyntaxVisitor {
    private let converter: SourceLocationConverter
    private(set) var metrics: [TypeStructuralMetrics] = []

    init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        appendMetrics(
            name: node.name.text,
            kind: .class,
            node: Syntax(node),
            members: node.memberBlock.members
        )
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        appendMetrics(
            name: node.name.text,
            kind: .struct,
            node: Syntax(node),
            members: node.memberBlock.members
        )
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        appendMetrics(
            name: node.name.text,
            kind: .actor,
            node: Syntax(node),
            members: node.memberBlock.members
        )
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        appendMetrics(
            name: node.extendedType.trimmedDescription,
            kind: .extension,
            node: Syntax(node),
            members: node.memberBlock.members
        )
        return .visitChildren
    }

    private func appendMetrics(
        name: String,
        kind: TypeKind,
        node: Syntax,
        members: MemberBlockItemListSyntax
    ) {
        let start = converter.location(
            for: node.positionAfterSkippingLeadingTrivia
        )
        let end = converter.location(
            for: node.endPositionBeforeTrailingTrivia
        )
        let range = ArcanDomain.SourceRange(
            startLine: start.line,
            startColumn: start.column,
            endLine: end.line,
            endColumn: end.column
        )

        metrics.append(TypeStructuralMetrics(
            name: name,
            kind: kind,
            range: range,
            lineCount: end.line - start.line + 1,
            methodCount: methodCount(in: members),
            propertyCount: storedPropertyCount(in: members)
        ))
    }

    private func methodCount(in members: MemberBlockItemListSyntax) -> Int {
        members.reduce(into: 0) { count, member in
            if member.decl.is(FunctionDeclSyntax.self) {
                count += 1
            }
        }
    }

    private func storedPropertyCount(
        in members: MemberBlockItemListSyntax
    ) -> Int {
        members.reduce(into: 0) { count, member in
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                return
            }
            count += variable.bindings.filter(isStoredProperty).count
        }
    }

    private func isStoredProperty(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessorBlock = binding.accessorBlock else {
            return true
        }

        switch accessorBlock.accessors {
        case .getter:
            return false
        case .accessors(let accessors):
            return accessors.allSatisfy { accessor in
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.willSet), .keyword(.didSet):
                    return true
                default:
                    return false
                }
            }
        }
    }
}
