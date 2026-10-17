final class SharedCounter {
    static var shared = SharedCounter()
    private var value = 0

    static func reset() {
        SharedCounter.shared.value = 0
    }
}
