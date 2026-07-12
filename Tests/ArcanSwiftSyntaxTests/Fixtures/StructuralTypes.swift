class Service {
    let client: Client
    var cache: [String: String] = [:]

    func fetch() {}
    static func reset() {}

    struct State {
        let value: Int

        func reduce() {}
    }
}

struct Feature {
    var count = 0
    var doubled: Int { count * 2 }
    var observed = 0 { didSet {} }

    func increment() {}
}

actor Store {
    let identifier: String

    func load() {}
}

extension Feature {
    var title: String { "Feature" }

    func decrement() {}
}
