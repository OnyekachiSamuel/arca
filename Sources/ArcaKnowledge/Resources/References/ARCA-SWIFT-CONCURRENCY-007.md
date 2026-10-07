# Inappropriate Detached Task

### Detached Work

**Check for:**
- [ ] `Task.detached` is used
- [ ] Work depends on inherited cancellation, priority, task-local values, or actor state
- [ ] Independent lifetime is not justified

**Do not flag:**
- [ ] Work intentionally independent of the parent
- [ ] Work allowed to finish after parent cancellation
- [ ] Structured child tasks

**Examples:**

❌ **Bad: Detached work expects a task-local value**
```swift
enum RequestContext {
    @TaskLocal static var requestID: String?
}

func recordRequest() {
    Task.detached {
        print(RequestContext.requestID as Any)
    }
}
```

✅ **Good: Independent cleanup**
```swift
Task.detached(priority: .background) {
    await DirectoryCleaner.cleanup()
}
```
