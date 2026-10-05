# Unsafe Sendable Conformance

### Sendable Conformance

**Check for:**
- [ ] A visible `Sendable` or `@unchecked Sendable` conformance
- [ ] Mutable state inside the conforming type
- [ ] No visible isolation or synchronization protecting that state

**Examples:**

❌ **Bad: Non-Sendable type crossing actors**
```swift
class UserData {  // ❌ Class without Sendable
    var name: String
}

actor DataStore {
    func save(_ data: UserData) {  // ⚠️ Warning: non-Sendable type
        // ...
    }
}
```

✅ **Good: Sendable struct**
```swift
struct UserData: Sendable {  // ✅ Value type is Sendable
    let name: String
}

actor DataStore {
    func save(_ data: UserData) {  // ✅ OK
        // ...
    }
}
```

✅ **Good: Sendable reference type**
```swift
final class UserData: @unchecked Sendable {  // ✅ Explicitly Sendable
    private let lock = NSLock()
    private var _name: String

    var name: String {
        lock.lock()
        defer { lock.unlock() }
        return _name
    }
    // Thread-safe implementation
}
```