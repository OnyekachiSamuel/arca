# Improper Isolation of Shared Mutable State

### Actor Isolation

**Check for:**
- [ ] Mutable state properly isolated with actors
- [ ] No shared mutable state without synchronization
- [ ] Proper actor isolation boundaries

**Examples:**

❌ **Bad: No actor isolation**
```swift
class UserViewModel {
    var users: [User] = []  // ❌ Mutable state without isolation

    func loadUsers() {
        // Can be called from any thread - data race!
    }
}
```

✅ **Good: Proper MainActor isolation**
```swift
@MainActor
class UserViewModel: ObservableObject {
    @Published var users: [User] = []  // ✅ MainActor-isolated

    func loadUsers() async {
        // Always runs on main actor
    }
}
```

✅ **Good: Custom actor for background work**
```swift
actor DatabaseManager {
    private var cache: [String: Data] = [:]  // ✅ Actor-isolated

    func save(_ data: Data, forKey key: String) {
        cache[key] = data
    }

    func fetch(forKey key: String) -> Data? {
        return cache[key]
    }
}
```

✅ **Good: Actor-isolated state**
```swift
@MainActor
final class UserManager {
    static let shared = UserManager()
    private(set) var currentUser: User?  // ✅ MainActor-isolated

    func updateUser(_ user: User) {
        currentUser = user  // ✅ Always on main actor
    }
}
```