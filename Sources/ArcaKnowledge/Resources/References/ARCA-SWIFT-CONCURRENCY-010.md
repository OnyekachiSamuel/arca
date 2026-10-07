# Blocking Operation in Async Context

### Cooperative Execution

**Check for:**
- [ ] Code is inside an async function or `Task`
- [ ] It waits by blocking the executing thread

**Do not flag:**
- [ ] `Task.sleep`
- [ ] Short synchronous computation
- [ ] Locking used only for a brief synchronous critical section

**Examples:**

❌ **Bad: Thread is blocked**
```swift
func retryLater() async {
    Thread.sleep(forTimeInterval: 5)
    await retry()
}
```

✅ **Good: Task is suspended**
```swift
try await Task.sleep(for: .seconds(5))
```
