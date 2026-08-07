import ArcaDomain

enum ReviewSelection: Equatable, Sendable {
    case all
    case types(Set<ReviewType>)
}
