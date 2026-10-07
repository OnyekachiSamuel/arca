# Long-Running Task Ignores Cancellation

### Cooperative Cancellation

**Check for:**
- [ ] A long-running or repeating task
- [ ] Cancellation errors are swallowed or no cancellation check exists
- [ ] The operation can continue after cancellation

**Do not flag:**
- [ ] Finite short-lived work
- [ ] Loops that check `Task.isCancelled`
- [ ] Cancellation-throwing operations whose errors exit the task

**Examples:**

❌ **Bad: Cancellation is ignored**
```swift
let task = Task {
    while true {
        try? await Task.sleep(for: .seconds(1))
        await poll()
    }
}
```

✅ **Good: Loop observes cancellation**
```swift
actor Timer {
    private var task: Task<Void, Never>?
    
    func start(interval: Duration, action: @Sendable () async -> Void) {
        task = Task {
            while !Task.isCancelled {
                await action()
                try? await Task.sleep(for: interval)
            }
        }
    }
    
    func stop() {
        task?.cancel()
    }
}
```
