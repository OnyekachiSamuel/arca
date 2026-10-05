# Unprotected Mutable Global or Static State

### Data Race Prevention

**Check for:**
- [ ] The declaration is global or `static`
- [ ] The declaration is a `var`
- [ ] It is a stored property without a getter or setter body
- [ ] Concurrent reads or writes are visible
- [ ] No actor isolation or synchronization protects it

**Do not flag:**
- [ ] Computed properties
- [ ] Immutable `let` properties
- [ ] Actor-isolated instance properties

**Examples:**

❌ **Bad: Unprotected mutable global state**
```swift
var currentUser: User?

func updateUser(_ user: User) {
    currentUser = user
}
```

✅ **Good: Actor-isolated shared state**
```swift
actor SessionStore {
    static let shared = SessionStore()
    private var currentUser: User?
}
```
