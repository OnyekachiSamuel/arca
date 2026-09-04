# Mutable Global or Static State

### Data Race Prevention

**Check for:**
- [ ] No mutable global state
- [ ] No mutable static properties (use actors or @MainActor)
- [ ] No unsynchronized shared state between actors
- [ ] Proper use of Task-local values

**Examples:**

❌ **Bad: Mutable global state**
```swift
var currentUser: User?  // ❌ Mutable global - data race!

func updateUser(_ user: User) {
    currentUser = user  // ❌ Can be called from multiple threads
}
```