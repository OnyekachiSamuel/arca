# Shared Mutable Instance State Without Isolation

### State Isolation

**Check for:**
- [ ] Mutable instance state
- [ ] Access through a visible global or static shared instance, or from multiple visible concurrency contexts
- [ ] No actor isolation or synchronization
- [ ] The state and access path are visible in the analysed file

**Do not flag:**
- [ ] Mutation of a global or static stored value itself
- [ ] Actor-isolated or synchronized state
- [ ] Instance state with no visible shared access path or concurrent access

**Examples:**

❌ **Bad: Shared class state without isolation**
```swift
final class Counter {
    static let shared = Counter()
    private var value = 0

    func increment() {
        value += 1
    }
}

func recordEvent() {
    Counter.shared.increment()
}
```

✅ **Good: Actor-isolated state**
```swift
actor Counter {
    var value = 0

    func increment() {
        value += 1
    }
}
```
