# Unstructured Concurrency Without Appropriate Lifecycle Management

### Task Lifecycle

**Check for:**
- [ ] An unstructured `Task` or `Task.detached` is created
- [ ] The task can be replaced, restarted, stopped, or outlive its owner
- [ ] Unfinished work can update state after replacement or owner termination
- [ ] No task handle or cancellation mechanism manages its lifetime

**Do not flag:**
- [ ] Tasks whose handles are retained and cancelled when required
- [ ] Task groups or `async let`
- [ ] A task used only to send work to an actor when no cancellation requirement is visible

**Examples:**

❌ **Bad: Replaceable work without cancellation**
```swift
final class SearchController {
    func search(_ query: String) {
        Task {
            results = await service.search(query)
        }
    }
}
```

✅ **Good: Owned and cancelled task**
```swift
final class SearchController {
    private var searchTask: Task<Void, Never>?

    func search(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            results = await service.search(query)
        }
    }
}
```

✅ **Good: Structured concurrency**
```swift
func loadData() async {
    async let users = fetchUsers()
    async let posts = fetchPosts()

    await update(users: users, posts: posts)
}
```
