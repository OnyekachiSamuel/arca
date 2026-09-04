

# Inappropriate Value or Reference Semantics

### Struct vs Class

**Check for:**
- [ ] Structs for value semantics (data models)
- [ ] Classes for identity and reference semantics
- [ ] Actors for concurrent mutable state
- [ ] Protocols for abstraction

**Examples:**

✅ **Good: Struct for data**
```swift
struct User {  // ✅ Value type for data
    let id: UUID
    let name: String
    let email: String
}
```

✅ **Good: Class for identity**
```swift
@MainActor
final class UserViewModel: ObservableObject {  // ✅ Reference type for state
    @Published var users: [User] = []
}
```

✅ **Good: Actor for concurrent state**
```swift
actor DatabaseManager {  // ✅ Actor for thread-safe mutable state
    private var cache: [UUID: User] = [:]
}
```