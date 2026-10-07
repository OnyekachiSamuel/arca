# Replaceable Task Without Lifecycle Management

### Task Lifecycle

**Check for:**
- [ ] The file shows replaceable unstructured work
- [ ] Newer work can start before older work completes
- [ ] Both tasks can update the same result target
- [ ] No cancellation or stale-result guard is visible

**Do not flag:**
- [ ] Independent work with no replacement relationship
- [ ] Structured child tasks
- [ ] Owned tasks that cancel or reject stale work
- [ ] Repeated invocation inferred only from external callers

**Examples:**

❌ **Bad: Older search can overwrite newer results**
```swift
final class SearchController {
    private(set) var results: [Result] = []

    func search(_ query: String) {
        Task {
            results = await service.search(query)
        }
    }

    func replaceSearch() {
        search("swift")
        search("concurrency")
    }
}
```

✅ **Good: Replaceable task is cancelled**
```swift
final class SearchController {
    private var searchTask: Task<Void, Never>?
    private(set) var results: [Result] = []

    func search(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            let newResults = await service.search(query)
            guard !Task.isCancelled else { return }
            results = newResults
        }
    }
}
```
