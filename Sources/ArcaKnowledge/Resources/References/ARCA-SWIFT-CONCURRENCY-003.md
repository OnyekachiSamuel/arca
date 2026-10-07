# Unjustified Unsafe Concurrency Escape Hatch

### Unsafe Conformance

**Check for:**
- [ ] An explicit concurrency-safety opt-out
- [ ] Mutable state or access in the file relies on the opt-out
- [ ] No visible safety invariant or protection mechanism

**Do not flag:**
- [ ] The annotation by itself
- [ ] Consistently locked mutable state
- [ ] Actor-isolated state
- [ ] An ordinary non-Sendable transfer without an unsafe annotation
- [ ] Missing protection inferred only from declarations outside the file

**Examples:**

❌ **Bad: Unchecked conformance with unprotected access**
```swift
final class Cache: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]

    // ⚠️ Forgot lock - data race!
    var count: Int {
        items.count
    }
}
```

✅ **Good: Actor-isolated cache**
```swift
actor Cache {
    private var items: [String: Data] = [:]

    var count: Int { items.count }

    func get(_ key: String) -> Data? {
        items[key]
    }

    func set(_ key: String, value: Data) {
        items[key] = value
    }
}
```
