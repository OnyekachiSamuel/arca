import ArcanDomain

enum ReviewSelection: Equatable, Sendable {
    case all
    case types(Set<ReviewType>)
}
