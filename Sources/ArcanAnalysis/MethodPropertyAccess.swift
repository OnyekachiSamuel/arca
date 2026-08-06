import ArcanDomain

public struct MethodPropertyAccess: Equatable, Sendable {
    public let methodName: String
    public let range: SourceRange
    public let accessedStoredProperties: Set<String>

    public init(
        methodName: String,
        range: SourceRange,
        accessedStoredProperties: Set<String>
    ) {
        self.methodName = methodName
        self.range = range
        self.accessedStoredProperties = accessedStoredProperties
    }
}
