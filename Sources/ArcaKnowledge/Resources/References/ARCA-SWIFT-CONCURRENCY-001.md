# Improper Isolation of Shared Mutable State

### Actor Isolation

**Check for:**
- [ ] Mutable state properly isolated with actors
- [ ] No shared mutable state without synchronization
- [ ] Proper actor isolation boundaries

**Do not flag:**
- [ ] Actor-isolated properties
- [ ] Global or static declarations covered by the dedicated global-state rule
- [ ] Computed properties that do not access unprotected shared mutable state

**Examples:**

❌ **Bad: Concurrent access without isolation**
```swift
final class UserStore {
    var users: [User] = []

    func refresh() {
        Task.detached {
            self.users = await fetchUsers()
        }
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
    private(set) var currentUser: User?

    func updateUser(_ user: User) {
        currentUser = user
    }
}
```
