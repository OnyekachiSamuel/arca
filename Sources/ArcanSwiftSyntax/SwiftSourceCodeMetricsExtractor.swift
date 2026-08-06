import ArcanAnalysis
import ArcanDomain
import SwiftSyntax

struct TypeStructuralFragment: Sendable {
    let identity: String
    let name: String
    let kind: TypeKind
    let sourcePath: String
    let range: ArcanDomain.SourceRange
    let lineCount: Int
    let methodCount: Int
    let storedPropertyNames: Set<String>
    let cohesionMethods: [MethodPropertyAccess]
}

final class SwiftSourceCodeMetricsExtractor: SyntaxVisitor {
    private let converter: SourceLocationConverter
    private let sourcePath: String
    private(set) var fragments: [TypeStructuralFragment] = []

    init(converter: SourceLocationConverter, sourcePath: String) {
        self.converter = converter
        self.sourcePath = sourcePath
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        appendFragment(
            identity: qualifiedName(node.name.text, parent: node.parent),
            name: node.name.text,
            kind: .class,
            node: Syntax(node),
            members: node.memberBlock.members
        )
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        appendFragment(
            identity: qualifiedName(node.name.text, parent: node.parent),
            name: node.name.text,
            kind: .struct,
            node: Syntax(node),
            members: node.memberBlock.members
        )
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        appendFragment(
            identity: qualifiedName(node.name.text, parent: node.parent),
            name: node.name.text,
            kind: .actor,
            node: Syntax(node),
            members: node.memberBlock.members
        )
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.extendedType.trimmedDescription
        appendFragment(
            identity: name,
            name: name.split(separator: ".").last.map(String.init) ?? name,
            kind: .extension,
            node: Syntax(node),
            members: node.memberBlock.members
        )
        return .visitChildren
    }

    private func appendFragment(
        identity: String,
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
        let storedProperties = storedPropertyNames(in: members)

        fragments.append(TypeStructuralFragment(
            identity: identity,
            name: name,
            kind: kind,
            sourcePath: sourcePath,
            range: range,
            lineCount: end.line - start.line + 1,
            methodCount: methodCount(in: members),
            storedPropertyNames: storedProperties,
            cohesionMethods: cohesionMethods(
                in: members
            )
        ))
    }

    private func methodCount(in members: MemberBlockItemListSyntax) -> Int {
        members.reduce(into: 0) { count, member in
            if member.decl.is(FunctionDeclSyntax.self) { count += 1 }
        }
    }

    private func storedPropertyNames(
        in members: MemberBlockItemListSyntax
    ) -> Set<String> {
        members.reduce(into: Set<String>()) { names, member in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  !hasTypeModifier(variable.modifiers) else { return }
            for binding in variable.bindings where isStoredProperty(binding) {
                names.formUnion(identifierNames(in: binding.pattern))
            }
        }
    }

    private func cohesionMethods(
        in members: MemberBlockItemListSyntax
    ) -> [MethodPropertyAccess] {
        members.compactMap { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self),
                  !hasTypeModifier(function.modifiers),
                  let body = function.body else { return nil }

            let shadowedNames = Set(function.signature.parameterClause.parameters
                .map { ($0.secondName ?? $0.firstName).text })
                .union(LocalDeclarationCollector.collect(in: body))
            let accesses = StoredPropertyAccessCollector.collect(
                in: body,
                shadowedNames: shadowedNames
            )
            let start = converter.location(
                for: function.positionAfterSkippingLeadingTrivia
            )
            let end = converter.location(
                for: function.endPositionBeforeTrailingTrivia
            )
            return MethodPropertyAccess(
                methodName: function.name.text,
                range: ArcanDomain.SourceRange(
                    startLine: start.line,
                    startColumn: start.column,
                    endLine: end.line,
                    endColumn: end.column
                ),
                accessedStoredProperties: accesses
            )
        }
    }

    private func hasTypeModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains {
            $0.name.tokenKind == .keyword(.static)
                || $0.name.tokenKind == .keyword(.class)
        }
    }

    private func isStoredProperty(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessorBlock = binding.accessorBlock else { return true }
        switch accessorBlock.accessors {
        case .getter:
            return false
        case .accessors(let accessors):
            return accessors.allSatisfy {
                $0.accessorSpecifier.tokenKind == .keyword(.willSet)
                    || $0.accessorSpecifier.tokenKind == .keyword(.didSet)
            }
        }
    }

    private func identifierNames(in pattern: PatternSyntax) -> Set<String> {
        Set(pattern.tokens(viewMode: .sourceAccurate).compactMap {
            if case .identifier(let name) = $0.tokenKind { name } else { nil }
        })
    }

    private func qualifiedName(_ name: String, parent: Syntax?) -> String {
        var names = [name]
        var current = parent
        while let node = current {
            if let declaration = node.as(ClassDeclSyntax.self) {
                names.insert(declaration.name.text, at: 0)
            } else if let declaration = node.as(StructDeclSyntax.self) {
                names.insert(declaration.name.text, at: 0)
            } else if let declaration = node.as(ActorDeclSyntax.self) {
                names.insert(declaration.name.text, at: 0)
            } else if let declaration = node.as(EnumDeclSyntax.self) {
                names.insert(declaration.name.text, at: 0)
            }
            current = node.parent
        }
        return names.joined(separator: ".")
    }
}

private final class LocalDeclarationCollector: SyntaxVisitor {
    private(set) var names: Set<String> = []

    static func collect(in body: CodeBlockSyntax) -> Set<String> {
        let collector = LocalDeclarationCollector(viewMode: .sourceAccurate)
        collector.walk(body)
        return collector.names
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            for token in binding.pattern.tokens(viewMode: .sourceAccurate) {
                if case .identifier(let name) = token.tokenKind {
                    names.insert(name)
                }
            }
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }
}

private final class StoredPropertyAccessCollector: SyntaxVisitor {
    private let shadowedNames: Set<String>
    private(set) var accesses: Set<String> = []

    init(shadowedNames: Set<String>) {
        self.shadowedNames = shadowedNames
        super.init(viewMode: .sourceAccurate)
    }

    static func collect(
        in body: CodeBlockSyntax,
        shadowedNames: Set<String>
    ) -> Set<String> {
        let collector = StoredPropertyAccessCollector(
            shadowedNames: shadowedNames
        )
        collector.walk(body)
        return collector.accesses
    }

    override func visit(
        _ node: MemberAccessExprSyntax
    ) -> SyntaxVisitorContinueKind {
        if node.base?.trimmedDescription == "self" {
            let name = node.declName.baseName.text
            accesses.insert(name)
        }
        return .visitChildren
    }

    override func visit(
        _ node: DeclReferenceExprSyntax
    ) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if !shadowedNames.contains(name) {
            accesses.insert(name)
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }
}
