struct ReviewCommandOptions: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case file(String)
        case changed
    }

    let source: Source?
    let reviewSelection: ReviewSelection
    let debug: Bool
}
