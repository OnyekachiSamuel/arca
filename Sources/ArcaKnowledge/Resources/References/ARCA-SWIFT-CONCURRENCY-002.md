# Unstructured Concurrency Without Appropriate Lifecycle Management

### Async/Await Patterns

**Check for:**
- [ ] Async/await used instead of completion handlers
- [ ] Structured concurrency (Task, TaskGroup) over unstructured
- [ ] Proper error propagation with async throws
- [ ] No blocking the main thread

**Examples:**

❌ **Bad: Completion handler**
```swift
func fetchUser(id: UUID, completion: @escaping (Result<User, Error>) -> Void) {
    // Old pattern
}
```

✅ **Good: Async/await**
```swift
func fetchUser(id: UUID) async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}
```

❌ **Bad: Unstructured concurrency**
```swift
func loadData() {
    Task {  // ❌ Unstructured, no cancellation handling
        await fetchUsers()
    }
    Task {
        await fetchPosts()
    }
}
```

✅ **Good: Structured concurrency**
```swift
func loadData() async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask { await self.fetchUsers() }
        group.addTask { await self.fetchPosts() }
        // All tasks complete before function returns
    }
}
```